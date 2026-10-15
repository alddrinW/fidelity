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
import { AppSetting } from '../../database/entities/app-setting.entity';
import { BankAccountConfig } from '../../config/configuration';
import { NotificationsService } from '../notifications/notifications.service';
import { ReportPaymentDto, UpdatePricesDto } from './dto/payments.dto';
import { PAYPHONE_APPROVED, PayphoneService } from './payphone.service';

/** Estados en los que un pago todavía espera resolverse. */
export const OPEN_PAYMENT_STATUSES = [PaymentStatus.PENDING, PaymentStatus.REPORTED];

const FEE_KEYS = { registration: 'registration_fee', branch: 'branch_fee' } as const;

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
    @InjectRepository(AppSetting)
    private readonly settingRepository: Repository<AppSetting>,
    private readonly configService: ConfigService,
    private readonly notificationsService: NotificationsService,
    private readonly payphone: PayphoneService,
  ) {}

  /**
   * Precio vigente de un concepto: el que fijó el administrador y, si no hay
   * ninguno, el de la configuración del servidor.
   */
  private async fees(): Promise<{ registrationFee: number; branchFee: number }> {
    const saved = await this.settingRepository.find({
      where: { key: In([FEE_KEYS.registration, FEE_KEYS.branch]) },
    });
    const value = (key: string, fallback: number) => {
      const n = Number(saved.find((s) => s.key === key)?.value);
      return Number.isFinite(n) && n > 0 ? n : fallback;
    };
    return {
      registrationFee: value(
        FEE_KEYS.registration,
        this.configService.get<number>('payments.registrationFee') ?? 20,
      ),
      branchFee: value(
        FEE_KEYS.branch,
        this.configService.get<number>('payments.branchFee') ?? 10,
      ),
    };
  }

  /** Precios y métodos de pago vigentes para el asistente "PAGA YA". */
  async getPlan() {
    const banks = this.configService.get<BankAccountConfig[]>('payments.bankAccounts') ?? [];

    return {
      currency: this.configService.get<string>('payments.currency') ?? 'USD',
      ...(await this.fees()),
      // Solo se ofrece un método de pago si está configurado.
      bankAccounts: banks.map((bank) => ({
        bank: bank.name || null,
        accountNumber: bank.accountNumber,
        accountType: bank.accountType || null,
        holder: bank.holder || null,
        taxId: bank.taxId || null,
      })),
      // El pago con tarjeta (PayPhone) solo se ofrece si está configurado.
      cardEnabled: this.payphone.isConfigured(),
    };
  }

  /**
   * El administrador fija los precios. Solo afecta a las órdenes que se creen
   * desde ahora: las ya creadas conservan el monto con el que se emitieron.
   */
  async updatePrices(dto: UpdatePricesDto) {
    const entries: AppSetting[] = [];
    if (dto.registrationFee != null) {
      entries.push(
        this.settingRepository.create({
          key: FEE_KEYS.registration,
          value: String(dto.registrationFee),
        }),
      );
    }
    if (dto.branchFee != null) {
      entries.push(
        this.settingRepository.create({ key: FEE_KEYS.branch, value: String(dto.branchFee) }),
      );
    }
    if (entries.length === 0) throw new BadRequestException('Indica al menos un precio');
    await this.settingRepository.save(entries);
    return this.getPlan();
  }

  private async feeFor(concept: PaymentConcept): Promise<number> {
    const fees = await this.fees();
    return concept === PaymentConcept.BRANCH ? fees.branchFee : fees.registrationFee;
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
      amount: await this.feeFor(concept),
      currency: this.configService.get<string>('payments.currency') ?? 'USD',
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

    // El pago con tarjeta lo confirma PayPhone al volver el cliente; si el dueño
    // pudiera "reportarlo", cualquiera daría por pagado un cobro que no existe.
    if (dto.method === PaymentMethod.CARD) {
      throw new BadRequestException(
        'El pago con tarjeta se confirma solo al pagar en PayPhone',
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
   * Inicia el pago con tarjeta: crea la página de pago en PayPhone y devuelve
   * su dirección. Cada intento usa un identificador nuevo (PayPhone no admite
   * repetirlo). El pago queda "reportado" cuando el cliente vuelve y el
   * servidor confirma el cobro (ver confirmCardPayment).
   */
  async startCardPayment(paymentId: string, ownerId: string) {
    if (!this.payphone.isConfigured()) {
      throw new BadRequestException('El pago con tarjeta no está disponible por ahora');
    }
    const payment = await this.paymentRepository.findOne({
      where: { id: paymentId },
      relations: ['owner'],
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

    const clientTransactionId = `${payment.reference}-${randomCode(4)}`;
    const checkout = await this.payphone.prepare({
      amountCents: Math.round(payment.amount * 100),
      clientTransactionId,
      reference: `Fidelity ${payment.reference}`,
      email: payment.owner?.email,
    });

    payment.gatewayClientTxId = clientTransactionId;
    payment.gatewayPayUrl = checkout.payWithCard;
    await this.paymentRepository.save(payment);
    return { payUrl: this.payphone.launchUrl(clientTransactionId) };
  }

  /**
   * Página de PayPhone a la que lleva la pasarela propia, o `null` si el
   * intento no existe, ya se pagó o la dirección guardada no es de PayPhone.
   */
  async getCardRedirect(clientTxId: string): Promise<string | null> {
    const payment = await this.paymentRepository.findOne({
      where: { gatewayClientTxId: clientTxId },
    });
    if (!payment || ![PaymentStatus.PENDING, PaymentStatus.REJECTED].includes(payment.status)) {
      return null;
    }
    return this.payphone.isPayphoneUrl(payment.gatewayPayUrl) ? payment.gatewayPayUrl : null;
  }

  /**
   * El cliente vuelve de PayPhone con `id` y `clientTransactionId`. Se confirma
   * el cobro directamente con PayPhone (no se cree en lo que llegue por la
   * dirección) y, si fue aprobado por el monto de la orden, el pago queda
   * validado y la cuenta se activa sola, con sus datos de PayPhone.
   */
  async confirmCardPayment(
    gatewayId: number,
    clientTxId: string,
  ): Promise<{ outcome: 'approved' | 'cancelled' | 'failed'; reference?: string }> {
    const payment = await this.paymentRepository.findOne({
      where: { gatewayClientTxId: clientTxId },
      relations: ['business'],
    });
    if (!payment) throw new NotFoundException('Pago no encontrado');

    // Si el cliente recarga la página de retorno, no se vuelve a confirmar.
    if (
      payment.gatewayTransactionId === String(gatewayId) &&
      [PaymentStatus.REPORTED, PaymentStatus.PAID].includes(payment.status)
    ) {
      return { outcome: 'approved', reference: payment.reference };
    }

    const result = await this.payphone.confirm(gatewayId, clientTxId);
    if (result.statusCode !== PAYPHONE_APPROVED) {
      return { outcome: 'cancelled', reference: payment.reference };
    }
    if (
      result.clientTransactionId !== clientTxId ||
      Number(result.amount) !== Math.round(payment.amount * 100)
    ) {
      this.logger.error(
        `PayPhone aprobó un cobro que no coincide con la orden ${payment.reference}: ` +
          `${result.clientTransactionId} / ${result.amount}`,
      );
      return { outcome: 'failed', reference: payment.reference };
    }

    payment.method = PaymentMethod.CARD;
    payment.gatewayTransactionId = String(result.transactionId ?? gatewayId);
    payment.gatewayAuthCode = result.authorizationCode ?? null;
    const card = [result.cardBrand, result.lastDigits && `•••• ${result.lastDigits}`]
      .filter(Boolean)
      .join(' ');
    payment.note = [
      'PayPhone',
      result.authorizationCode && `aut. ${result.authorizationCode}`,
      `trans. ${payment.gatewayTransactionId}`,
      card,
    ]
      .filter(Boolean)
      .join(' · ');
    payment.reportedAt = new Date();
    // PayPhone ya cobró y el servidor lo verificó: no hace falta que un
    // administrador lo valide (como sí ocurre con una transferencia).
    await this.activate(payment, null);

    await this.safely(() =>
      this.notificationsService.broadcastToAdmins(
        'Negocio activado con tarjeta',
        `${payment.business?.name ?? 'Un negocio'} pagó con tarjeta (${payment.reference}) y su cuenta se activó sola.`,
        '/admin_payments',
      ),
    );
    return { outcome: 'approved', reference: payment.reference };
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

    return this.activate(payment, adminId);
  }

  /**
   * Da el pago por validado: emite el comprobante, activa la cuenta y avisa al
   * dueño. Lo usa el administrador (`validatedById` = su id) y el pago con
   * tarjeta aprobado por PayPhone (sin administrador: `null`).
   */
  private async activate(payment: Payment, validatedById: string | null) {
    const saved = await this.paymentRepository.manager.transaction(async (manager) => {
      this.markPaid(payment, validatedById);
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

  private markPaid(payment: Payment, adminId: string | null) {
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
