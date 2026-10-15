import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { randomBytes } from 'crypto';
import { In, Repository } from 'typeorm';
import { Business } from '../../database/entities/business.entity';
import {
  Payment,
  PaymentConcept,
  PaymentMethod,
  PaymentStatus,
} from '../../database/entities/payment.entity';
import { BankAccountConfig } from '../../config/configuration';
import { NotificationsService } from '../notifications/notifications.service';
import { ReportPaymentDto } from './dto/payments.dto';

/** Estados en los que un pago todavía espera resolverse. */
export const OPEN_PAYMENT_STATUSES = [PaymentStatus.PENDING, PaymentStatus.REPORTED];

// Sin 0/O/1/I para que la referencia sea fácil de dictar.
const REFERENCE_ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

function randomCode(length: number): string {
  const bytes = randomBytes(length);
  let code = '';
  for (let i = 0; i < length; i++) {
    code += REFERENCE_ALPHABET[bytes[i] % REFERENCE_ALPHABET.length];
  }
  return code;
}

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    @InjectRepository(Payment)
    private readonly paymentRepository: Repository<Payment>,
    private readonly configService: ConfigService,
    private readonly notificationsService: NotificationsService,
  ) {}

  /** Precios vigentes para mostrar en el asistente "PAGA YA". */
  getPlan() {
    const banks = this.configService.get<BankAccountConfig[]>('payments.bankAccounts') ?? [];
    const cardPaymentUrl = this.configService.get<string>('payments.cardPaymentUrl');

    return {
      currency: this.configService.get<string>('payments.currency') ?? 'USD',
      registrationFee: this.configService.get<number>('payments.registrationFee') ?? 20,
      branchFee: this.configService.get<number>('payments.branchFee') ?? 10,
      // Solo se ofrece un método de pago si está configurado.
      bankAccounts: banks.map((bank) => ({
        bank: bank.name || null,
        accountNumber: bank.accountNumber,
        accountType: bank.accountType || null,
        holder: bank.holder || null,
        taxId: bank.taxId || null,
      })),
      cardPaymentUrl: cardPaymentUrl || null,
    };
  }

  private feeFor(concept: PaymentConcept): number {
    const plan = this.getPlan();
    return concept === PaymentConcept.BRANCH ? plan.branchFee : plan.registrationFee;
  }

  /** Crea la orden de pago de un negocio recién registrado. */
  async createOrder(
    business: Pick<Business, 'id' | 'ownerId'>,
    concept: PaymentConcept = PaymentConcept.REGISTRATION,
  ): Promise<Payment> {
    const order = this.paymentRepository.create({
      businessId: business.id,
      ownerId: business.ownerId,
      concept,
      amount: this.feeFor(concept),
      currency: this.getPlan().currency,
      status: PaymentStatus.PENDING,
      reference: `FID-${randomCode(6)}`,
    });
    return this.paymentRepository.save(order);
  }

  /**
   * Devuelve la orden de pago vigente de un negocio inactivo, o crea una si no
   * tiene (negocios creados antes de que existiera el pago).
   */
  async ensureOrder(businessId: string, ownerId: string): Promise<Payment> {
    const business = await this.paymentRepository.manager.findOne(Business, {
      where: { id: businessId },
    });
    if (!business) throw new NotFoundException('Negocio no encontrado');
    if (business.ownerId !== ownerId) {
      throw new ForbiddenException('Este negocio no te pertenece');
    }
    if (business.isActive) {
      throw new BadRequestException('Este negocio ya está activo');
    }

    const current = await this.paymentRepository.findOne({
      where: {
        businessId,
        status: In([...OPEN_PAYMENT_STATUSES, PaymentStatus.REJECTED]),
      },
      order: { createdAt: 'DESC' },
    });
    return (
      current ??
      this.createOrder(
        business,
        business.parentId ? PaymentConcept.BRANCH : PaymentConcept.REGISTRATION,
      )
    );
  }

  async listMine(ownerId: string) {
    return this.paymentRepository.find({
      where: { ownerId },
      relations: ['business'],
      order: { createdAt: 'DESC' },
    });
  }

  /** El dueño avisa que ya pagó: pasa a "reportado" y se avisa a los admins. */
  async report(paymentId: string, ownerId: string, dto: ReportPaymentDto) {
    const payment = await this.paymentRepository.findOne({
      where: { id: paymentId },
      relations: ['business'],
    });
    if (!payment) throw new NotFoundException('Pago no encontrado');
    if (payment.ownerId !== ownerId) {
      throw new ForbiddenException('Este pago no te pertenece');
    }
    if (![PaymentStatus.PENDING, PaymentStatus.REJECTED].includes(payment.status)) {
      throw new BadRequestException(
        payment.status === PaymentStatus.PAID
          ? 'Este pago ya fue validado'
          : 'Este pago ya fue reportado y está en revisión',
      );
    }

    // Una transferencia o un depósito se validan con la foto del comprobante.
    const needsProof = [PaymentMethod.TRANSFER, PaymentMethod.DEPOSIT].includes(dto.method);
    if (needsProof && !dto.proofUrl) {
      throw new BadRequestException('Adjunta la foto del comprobante de la transferencia');
    }

    payment.method = dto.method;
    payment.note = dto.note?.trim() || null;
    payment.proofUrl = dto.proofUrl || null;
    payment.status = PaymentStatus.REPORTED;
    payment.reportedAt = new Date();
    payment.adminNote = null;
    const saved = await this.paymentRepository.save(payment);

    await this.safely(() =>
      this.notificationsService.broadcastToAdmins(
        'Pago por validar',
        `${payment.business?.name ?? 'Un negocio'} reportó su pago (${saved.reference}).`,
        '/admin_payments',
      ),
    );
    return saved;
  }

  /**
   * Pagos para el listado del administrador. Las imágenes (comprobante, logo
   * y foto del dueño) pueden pesar hasta 1 MB cada una, así que no se envían
   * en el listado: solo se indica si hay comprobante (`hasProof`) y se piden
   * con [getOne] al abrir un pago.
   */
  async listAll(status?: PaymentStatus) {
    const payments = await this.paymentRepository.find({
      where: status ? { status } : {},
      relations: ['business', 'business.categoryRef', 'owner'],
      order: { createdAt: 'DESC' },
      take: 200,
    });

    return payments.map((p) => ({
      ...p,
      proofUrl: undefined,
      hasProof: !!p.proofUrl,
      business: p.business && { ...p.business, logoUrl: undefined },
      owner: p.owner && { ...p.owner, avatarUrl: undefined },
    }));
  }

  /** Un pago completo (con comprobante, negocio y dueño) para el administrador. */
  async getOne(paymentId: string) {
    const payment = await this.paymentRepository.findOne({
      where: { id: paymentId },
      relations: ['business', 'business.categoryRef', 'owner'],
    });
    if (!payment) throw new NotFoundException('Pago no encontrado');
    return { ...payment, hasProof: !!payment.proofUrl };
  }

  /** Cuántos pagos esperan resolución del administrador. */
  async countOpen(): Promise<number> {
    return this.paymentRepository.count({ where: { status: In(OPEN_PAYMENT_STATUSES) } });
  }

  /** El administrador valida el pago: emite el comprobante y activa la cuenta. */
  async validate(paymentId: string, adminId: string) {
    const payment = await this.paymentRepository.findOne({
      where: { id: paymentId },
      relations: ['business'],
    });
    if (!payment) throw new NotFoundException('Pago no encontrado');
    if (payment.status === PaymentStatus.PAID) {
      throw new BadRequestException('Este pago ya fue validado');
    }

    const saved = await this.paymentRepository.manager.transaction(async (manager) => {
      this.markPaid(payment, adminId);
      const result = await manager.save(Payment, payment);
      await manager.update(Business, { id: payment.businessId }, { isActive: true });
      return result;
    });

    await this.safely(() =>
      this.notificationsService.sendToBusinessOwner(
        payment.businessId,
        '¡Pago validado!',
        `Validamos tu pago (comprobante ${saved.receiptNumber}). ${payment.business?.name ?? 'Tu negocio'} ya está activo.`,
        { type: 'business_activated' },
      ),
    );
    return saved;
  }

  async reject(paymentId: string, reason: string) {
    const payment = await this.paymentRepository.findOne({
      where: { id: paymentId },
      relations: ['business'],
    });
    if (!payment) throw new NotFoundException('Pago no encontrado');
    if (payment.status === PaymentStatus.PAID) {
      throw new BadRequestException('Un pago validado no se puede rechazar');
    }

    payment.status = PaymentStatus.REJECTED;
    payment.adminNote = reason.trim();
    const saved = await this.paymentRepository.save(payment);

    await this.safely(() =>
      this.notificationsService.sendToBusinessOwner(
        payment.businessId,
        'No pudimos validar tu pago',
        `${saved.adminNote} Puedes reportarlo de nuevo desde la app.`,
        { type: 'payment_rejected' },
      ),
    );
    return saved;
  }

  /**
   * Cierra como pagadas las órdenes abiertas de un negocio. Lo usa la
   * activación manual del administrador: al confirmar que recibió el pago, el
   * dueño también recibe su comprobante.
   */
  async settleOpenForBusiness(businessId: string, adminId: string): Promise<number> {
    const open = await this.paymentRepository.find({
      where: { businessId, status: In(OPEN_PAYMENT_STATUSES) },
    });
    for (const payment of open) {
      this.markPaid(payment, adminId);
    }
    if (open.length > 0) await this.paymentRepository.save(open);
    return open.length;
  }

  private markPaid(payment: Payment, adminId: string) {
    payment.status = PaymentStatus.PAID;
    payment.paidAt = new Date();
    payment.validatedById = adminId;
    payment.adminNote = null;
    payment.receiptNumber ??= this.newReceiptNumber();
  }

  /** FID-R-AAAAMMDD-XXXXXX: la fecha ordena y el sufijo aleatorio evita choques. */
  private newReceiptNumber(): string {
    const d = new Date();
    const stamp =
      `${d.getUTCFullYear()}${String(d.getUTCMonth() + 1).padStart(2, '0')}` +
      `${String(d.getUTCDate()).padStart(2, '0')}`;
    return `FID-R-${stamp}-${randomCode(6)}`;
  }

  /** Una notificación fallida nunca debe deshacer la operación de pago. */
  private async safely(task: () => Promise<unknown>) {
    try {
      await task();
    } catch (error) {
      this.logger.warn(`Notificación de pago no enviada: ${error.message}`);
    }
  }
}
