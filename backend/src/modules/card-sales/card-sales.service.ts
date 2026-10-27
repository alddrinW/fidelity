import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomBytes } from 'crypto';
import { In, IsNull, LessThanOrEqual, MoreThan, Not, Repository } from 'typeorm';
import { Business } from '../../database/entities/business.entity';
import { Campaign, CampaignType, campaignPhase } from '../../database/entities/campaign.entity';
import {
  CampaignClaim,
  ClaimSource,
  ClaimStatus,
} from '../../database/entities/campaign-claim.entity';
import {
  CardPurchase,
  CardPurchaseMethod,
  CardPurchaseStatus,
} from '../../database/entities/card-purchase.entity';
import { UserRole } from '../../database/entities/profile.entity';
import { CampaignsService, randomCode } from '../campaigns/campaigns.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import { PAYPHONE_APPROVED, PayphoneService } from '../payments/payphone.service';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { SettingsService } from '../settings/settings.service';

/** Ruta (tras el prefijo de la API) a la que PayPhone devuelve al cliente de una compra. */
export const CARD_SALES_AREA = 'card-sales/payphone';

/** Cuánto guarda el cupo una compra mientras el cliente paga en PayPhone. */
const RESERVATION_MINUTES = 15;

/** Cuánto guarda el cupo una compra por transferencia, para que el cliente haga la transferencia y suba el comprobante. */
const TRANSFER_RESERVATION_HOURS = 12;

// Sin 0/O/1/I para que la referencia sea fácil de dictar.
const ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

function shortCode(length: number): string {
  const bytes = randomBytes(length);
  let code = '';
  for (let i = 0; i < length; i++) code += ALPHABET[bytes[i] % ALPHABET.length];
  return code;
}

function reference(): string {
  return `TJ-${shortCode(6)}`;
}

/** "$0.25" a partir de centavos. */
export function usd(cents: number): string {
  return `$${(cents / 100).toFixed(2)}`;
}

export type PurchaseOutcome = 'approved' | 'cancelled' | 'failed';

/** Cómo puede pagar el cliente. */
export type PurchaseMethodName = 'card' | 'transfer';

type Requester = { id: string; role: UserRole };

/**
 * Las tarjetas en venta: una gift card con precio que el cliente compra con
 * tarjeta (PayPhone, confirmado por el servidor) o por transferencia (con un
 * comprobante que revisa el administrador). Fidelity retiene una comisión
 * (que fija el administrador) y el resto se le paga al local cuando el cliente
 * canjea la tarjeta; el administrador registra ese pago.
 */
@Injectable()
export class CardSalesService {
  private readonly logger = new Logger(CardSalesService.name);

  constructor(
    @InjectRepository(CardPurchase)
    private readonly purchaseRepository: Repository<CardPurchase>,
    @InjectRepository(Campaign)
    private readonly campaignRepository: Repository<Campaign>,
    @InjectRepository(CampaignClaim)
    private readonly claimRepository: Repository<CampaignClaim>,
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    private readonly campaigns: CampaignsService,
    private readonly payphone: PayphoneService,
    private readonly payments: PaymentsService,
    private readonly settings: SettingsService,
    private readonly notifications: NotificationsService,
  ) {}

  // ------------------------------------------------------------------
  // Cliente
  // ------------------------------------------------------------------

  /** Las reglas que fijó el administrador: si se vende, la comisión y los precios permitidos. */
  async rules() {
    const [enabled, percent, min, max] = await Promise.all([
      this.settings.get(SETTING_KEYS.paidCardsEnabled),
      this.settings.get(SETTING_KEYS.paidCardsCommissionPercent),
      this.settings.get(SETTING_KEYS.paidCardsMinPrice),
      this.settings.get(SETTING_KEYS.paidCardsMaxPrice),
    ]);
    const methods = await this.methods();
    return {
      enabled: enabled === 1,
      commissionPercent: percent,
      minPriceCents: Math.round(min * 100),
      maxPriceCents: Math.round(max * 100),
      /** Con qué se puede pagar ahora: PayPhone (si está configurado) y/o transferencia. */
      cardEnabled: methods.card,
      transferEnabled: methods.transfer,
      /** Las cuentas donde transferir (vacío si la transferencia no está disponible). */
      bankAccounts: methods.transfer ? methods.accounts : [],
    };
  }

  /** La transferencia solo se ofrece si el administrador la dejó encendida y hay cuentas donde transferir. */
  private async methods(): Promise<{
    card: boolean;
    transfer: boolean;
    accounts: Awaited<ReturnType<PaymentsService['publicBankAccounts']>>;
  }> {
    const [transferOn, accounts] = await Promise.all([
      this.settings.get(SETTING_KEYS.paidCardsTransferEnabled),
      this.payments.publicBankAccounts(),
    ]);
    return {
      card: this.payphone.isConfigured(),
      transfer: transferOn === 1 && accounts.length > 0,
      accounts,
    };
  }

  /** Las tarjetas en venta que el cliente puede ver (de cualquier local) y si ya compró alguna. */
  async offersFor(userId: string) {
    if (!(await this.settings.get(SETTING_KEYS.paidCardsEnabled))) return [];

    const now = new Date();
    const base = { priceCents: Not(IsNull()), hidden: false, cancelledAt: IsNull(), startsAt: LessThanOrEqual(now) };
    const campaigns = await this.campaignRepository.find({
      where: [{ ...base, endsAt: IsNull() }, { ...base, endsAt: MoreThan(now) }],
      relations: ['participants', 'participants.business'],
      order: { startsAt: 'DESC' },
      take: 50,
    });
    const onSale = campaigns.filter(
      (c) => c.type === CampaignType.GIFT_CARD && c.participants?.[0]?.business?.isActive !== false,
    );
    if (onSale.length === 0) return [];

    const ids = onSale.map((c) => c.id);
    const [mine, taken, transfers] = await Promise.all([
      this.claimRepository.find({ where: { campaignId: In(ids), userId } }),
      this.takenByCampaign(ids),
      this.transfersInProgress(userId, ids),
    ]);

    return onSale
      .map((c) => {
        const claim = mine.find((x) => x.campaignId === c.id) ?? null;
        return {
          ...this.campaigns.toView(c),
          stockLeft: Math.max(0, (c.stock ?? 0) - (taken.get(c.id) ?? 0)),
          claim: claim && {
            id: claim.id,
            code: claim.code,
            status: claim.status,
            expiresAt: claim.expiresAt,
          },
          /** La compra por transferencia en curso (o la última que se rechazó), si hay; ya con la tarjeta, ninguna. */
          purchase: claim ? null : (transfers.get(c.id) ?? null),
        };
      })
      // Lo agotado ya no se ofrece, salvo a quien ya la compró o tiene un comprobante en revisión.
      .filter((o) => o.stockLeft > 0 || o.claim || o.purchase);
  }

  /**
   * La compra por transferencia que el cliente tiene en curso en cada oferta: esperando el
   * comprobante, en revisión, o la última que se rechazó (para mostrar el motivo).
   */
  private async transfersInProgress(userId: string, campaignIds: string[]) {
    const rows = await this.purchaseRepository.find({
      where: {
        userId,
        campaignId: In(campaignIds),
        method: CardPurchaseMethod.TRANSFER,
        status: In([CardPurchaseStatus.PENDING, CardPurchaseStatus.IN_REVIEW, CardPurchaseStatus.REJECTED]),
      },
      order: { createdAt: 'DESC' },
    });
    const now = new Date();
    const byCampaign = new Map<string, any>();
    for (const p of rows) {
      // La reserva vencida ya no cuenta: el cliente empieza de nuevo.
      if (p.status === CardPurchaseStatus.PENDING && new Date(p.reservedUntil) <= now) continue;
      if (byCampaign.has(p.campaignId)) continue;
      byCampaign.set(p.campaignId, {
        id: p.id,
        status: p.status,
        reference: p.reference,
        amountCents: p.amountCents,
        reservedUntil: p.status === CardPurchaseStatus.PENDING ? p.reservedUntil : null,
        reviewNote: p.status === CardPurchaseStatus.REJECTED ? p.reviewNote : null,
      });
    }
    return byCampaign;
  }

  /** Cuántas tarjetas de cada oferta están vendidas o reservadas ahora mismo. */
  private async takenByCampaign(campaignIds: string[]): Promise<Map<string, number>> {
    const rows = await this.purchaseRepository
      .createQueryBuilder('p')
      .select('p.campaign_id', 'campaignId')
      .addSelect('COUNT(*)', 'n')
      .where('p.campaign_id IN (:...ids)', { ids: campaignIds })
      .andWhere(
        "(p.status IN (:...sold) OR (p.status = :pending AND p.reserved_until > NOW()))",
        {
          // Una compra por transferencia con comprobante en revisión también guarda su cupo.
          sold: [CardPurchaseStatus.PAID, CardPurchaseStatus.REFUND_DUE, CardPurchaseStatus.IN_REVIEW],
          pending: CardPurchaseStatus.PENDING,
        },
      )
      .groupBy('p.campaign_id')
      .getRawMany<{ campaignId: string; n: string }>();
    return new Map(rows.map((r) => [r.campaignId, Number(r.n)]));
  }

  /**
   * El cliente va a pagar una tarjeta: se reserva el cupo y, con tarjeta, se devuelve la
   * página de PayPhone; con transferencia, las cuentas donde transferir (después sube el comprobante).
   */
  async startPurchase(
    userId: string,
    campaignId: string,
    email?: string | null,
    method: PurchaseMethodName = 'card',
  ) {
    const transfer = method === 'transfer';
    if (transfer) {
      if (!(await this.methods()).transfer) {
        throw new BadRequestException('El pago por transferencia no está disponible por ahora');
      }
    } else if (!this.payphone.isConfigured()) {
      throw new BadRequestException('El pago con tarjeta no está disponible por ahora');
    }
    if (!(await this.settings.get(SETTING_KEYS.paidCardsEnabled))) {
      throw new BadRequestException('La venta de tarjetas no está disponible por ahora');
    }

    const purchase = await this.purchaseRepository.manager.transaction(async (manager) => {
      // Se bloquea la oferta mientras se cuenta el cupo, para que dos compras a la vez no lo pasen.
      const campaign = await manager.findOne(Campaign, {
        where: { id: campaignId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!campaign || campaign.priceCents == null || campaign.type !== CampaignType.GIFT_CARD) {
        throw new NotFoundException('Esta tarjeta no está en venta');
      }
      if (campaignPhase(campaign) !== 'active') {
        throw new BadRequestException('Esta oferta ya no está vigente');
      }
      const business = await manager.findOne(Business, { where: { id: campaign.businessId } });
      if (!business?.isActive) {
        throw new BadRequestException('Este local no está disponible por ahora');
      }

      if (await manager.exists(CampaignClaim, { where: { campaignId, userId } })) {
        throw new ConflictException('Ya tienes esta tarjeta');
      }
      if (await manager.exists(CardPurchase, { where: { campaignId, userId, status: CardPurchaseStatus.IN_REVIEW } })) {
        throw new ConflictException('Ya enviaste el comprobante de esta tarjeta. Lo estamos revisando.');
      }

      const taken = (await this.takenByCampaign([campaignId])).get(campaignId) ?? 0;
      // Si la persona ya tenía una compra pendiente, esa reserva se reemplaza.
      const mineOpen = await manager.find(CardPurchase, {
        where: { campaignId, userId, status: CardPurchaseStatus.PENDING },
      });
      const mineReserved = mineOpen.filter((p) => new Date(p.reservedUntil) > new Date()).length;
      if ((campaign.stock ?? 0) - (taken - mineReserved) <= 0) {
        throw new ConflictException('Se agotaron las tarjetas de esta oferta');
      }
      for (const old of mineOpen) {
        old.status = CardPurchaseStatus.FAILED;
        await manager.save(old);
      }

      const percent = await this.settings.get(SETTING_KEYS.paidCardsCommissionPercent);
      const ref = reference();
      return manager.save(
        manager.create(CardPurchase, {
          campaignId,
          userId,
          businessId: campaign.businessId,
          amountCents: campaign.priceCents,
          commissionCents: Math.round((campaign.priceCents * percent) / 100),
          status: CardPurchaseStatus.PENDING,
          method: transfer ? CardPurchaseMethod.TRANSFER : CardPurchaseMethod.PAYPHONE,
          reference: ref,
          gatewayClientTxId: `${ref}-${shortCode(4)}`,
          reservedUntil: new Date(
            Date.now() + (transfer ? TRANSFER_RESERVATION_HOURS * 60 : RESERVATION_MINUTES) * 60 * 1000,
          ),
        }),
      );
    });

    if (transfer) {
      return {
        method: 'transfer' as const,
        purchaseId: purchase.id,
        reference: purchase.reference,
        amountCents: purchase.amountCents,
        reservedUntil: purchase.reservedUntil,
        bankAccounts: await this.payments.publicBankAccounts(),
      };
    }

    const checkout = await this.payphone.prepare({
      amountCents: purchase.amountCents,
      clientTransactionId: purchase.gatewayClientTxId,
      reference: `Fidelity ${purchase.reference}`,
      email,
      area: CARD_SALES_AREA,
    });
    purchase.gatewayPayUrl = checkout.payWithCard;
    await this.purchaseRepository.save(purchase);

    return {
      method: 'card' as const,
      payUrl: this.payphone.launchUrl(purchase.gatewayClientTxId, CARD_SALES_AREA),
      reference: purchase.reference,
    };
  }

  /**
   * El cliente subió el comprobante de su transferencia: la compra pasa a "en revisión"
   * (sigue guardando su cupo) y se avisa a los administradores.
   */
  async submitProof(userId: string, purchaseId: string, dto: { proofUrl: string; note?: string }) {
    const purchase = await this.purchaseRepository.findOne({
      where: { id: purchaseId },
      relations: ['campaign', 'user'],
    });
    if (!purchase || purchase.userId !== userId || purchase.method !== CardPurchaseMethod.TRANSFER) {
      throw new NotFoundException('Compra no encontrada');
    }
    if (purchase.status === CardPurchaseStatus.IN_REVIEW) {
      throw new ConflictException('Ya enviaste el comprobante. Lo estamos revisando.');
    }
    if (purchase.status !== CardPurchaseStatus.PENDING) {
      throw new BadRequestException('Esta compra ya no admite comprobante. Empieza de nuevo.');
    }
    if (new Date(purchase.reservedUntil) <= new Date()) {
      throw new BadRequestException('La reserva de esta tarjeta venció. Empieza de nuevo.');
    }
    if (!dto.proofUrl) throw new BadRequestException('Adjunta la foto del comprobante de la transferencia');

    // Solo pasa una vez a "en revisión", aunque el cliente toque el botón dos veces.
    const now = new Date();
    const result = await this.purchaseRepository.update(
      { id: purchaseId, status: CardPurchaseStatus.PENDING },
      {
        status: CardPurchaseStatus.IN_REVIEW,
        proofUrl: dto.proofUrl,
        transferNote: dto.note?.trim().slice(0, 200) || null,
        reportedAt: now,
      },
    );
    if (result.affected !== 1) throw new ConflictException('Ya enviaste el comprobante. Lo estamos revisando.');

    const benefit = purchase.campaign?.benefitLabel ?? purchase.campaign?.title ?? 'una tarjeta';
    await this.safely(() =>
      this.notifications.broadcastToAdmins(
        'Comprobante de tarjeta por revisar',
        `${purchase.user?.fullName ?? 'Un cliente'} pagó ${usd(purchase.amountCents)} por «${benefit}» (${purchase.reference}). Revisa el comprobante.`,
        '/admin_card_reviews',
      ),
    );
    return { id: purchase.id, status: CardPurchaseStatus.IN_REVIEW, reference: purchase.reference };
  }

  /** A dónde mandar al cliente para pagar (solo páginas de PayPhone). */
  async getRedirect(clientTxId: string): Promise<string | null> {
    const purchase = await this.purchaseRepository.findOne({ where: { gatewayClientTxId: clientTxId } });
    if (!purchase || purchase.status !== CardPurchaseStatus.PENDING) return null;
    if (purchase.method !== CardPurchaseMethod.PAYPHONE) return null;
    return this.payphone.isPayphoneUrl(purchase.gatewayPayUrl) ? purchase.gatewayPayUrl : null;
  }

  /**
   * El cliente vuelve de PayPhone. Se confirma el cobro desde el servidor; solo
   * si coincide con la compra se le entrega la tarjeta (una sola vez).
   */
  async confirm(gatewayId: number, clientTxId: string): Promise<{ outcome: PurchaseOutcome; reference?: string }> {
    const purchase = await this.purchaseRepository.findOne({
      where: { gatewayClientTxId: clientTxId },
      relations: ['campaign', 'campaign.participants', 'campaign.participants.business', 'user'],
    });
    if (!purchase) throw new NotFoundException('Compra no encontrada');

    // Si el cliente recarga la página de retorno, no se vuelve a entregar.
    if ([CardPurchaseStatus.PAID, CardPurchaseStatus.REFUND_DUE].includes(purchase.status)) {
      return { outcome: 'approved', reference: purchase.reference };
    }
    // Una compra por transferencia no se confirma con PayPhone.
    if (purchase.method !== CardPurchaseMethod.PAYPHONE) {
      return { outcome: 'failed', reference: purchase.reference };
    }

    const result = await this.payphone.confirm(gatewayId, clientTxId);
    if (result.statusCode !== PAYPHONE_APPROVED) {
      purchase.status = CardPurchaseStatus.FAILED;
      await this.purchaseRepository.save(purchase);
      return { outcome: 'cancelled', reference: purchase.reference };
    }
    if (result.clientTransactionId !== clientTxId || Number(result.amount) !== purchase.amountCents) {
      this.logger.error(
        `PayPhone aprobó un cobro que no coincide con la compra ${purchase.reference}: ` +
          `${result.clientTransactionId} / ${result.amount}`,
      );
      return { outcome: 'failed', reference: purchase.reference };
    }

    purchase.gatewayTransactionId = String(result.transactionId ?? gatewayId);
    purchase.gatewayAuthCode = result.authorizationCode ?? null;
    return this.deliver(purchase);
  }

  /**
   * La compra ya está pagada (PayPhone cobró o el administrador aprobó la transferencia):
   * se le entrega la tarjeta al cliente, una sola vez, y se avisa.
   */
  private async deliver(purchase: CardPurchase): Promise<{ outcome: PurchaseOutcome; reference?: string }> {
    purchase.paidAt = new Date();

    const campaign = purchase.campaign;
    const alreadyHas = await this.claimRepository.findOne({
      where: { campaignId: purchase.campaignId, userId: purchase.userId },
    });
    if (alreadyHas) {
      // Pagó dos veces la misma tarjeta (dos pestañas): la segunda se devuelve.
      purchase.status = CardPurchaseStatus.REFUND_DUE;
      await this.purchaseRepository.save(purchase);
      await this.safely(() =>
        this.notifications.broadcastToAdmins(
          'Devolver una compra de tarjeta',
          `La compra ${purchase.reference} (${usd(purchase.amountCents)}) se cobró dos veces. Hay que devolverla.`,
          '/admin_card_payouts',
        ),
      );
      return { outcome: 'approved', reference: purchase.reference };
    }

    const validDays = campaign.cardValidDays ?? 30;
    const claim = await this.claimRepository.save(
      this.claimRepository.create({
        campaignId: purchase.campaignId,
        userId: purchase.userId,
        code: randomCode('GFT'),
        status: ClaimStatus.ACTIVE,
        source: ClaimSource.PURCHASE,
        expiresAt: new Date(Date.now() + validDays * 24 * 60 * 60 * 1000),
      }),
    );
    purchase.claimId = claim.id;
    purchase.status = CardPurchaseStatus.PAID;
    await this.purchaseRepository.save(purchase);

    await this.notifyPaid(purchase, claim);
    return { outcome: 'approved', reference: purchase.reference };
  }

  private async notifyPaid(purchase: CardPurchase, claim: CampaignClaim) {
    const campaign = purchase.campaign;
    const business = campaign.participants?.[0]?.business;
    const benefit = campaign.benefitLabel ?? campaign.title;
    await this.safely(() =>
      this.notifications.sendToUser(
        purchase.userId,
        'Compra aprobada',
        `Tu tarjeta de ${business?.name ?? 'tu local'}: ${benefit} ya está en Mis regalos. Vale hasta el ${this.day(claim.expiresAt)}.`,
        { type: 'card_purchased', route: '/my_gifts' },
      ),
    );
    if (business?.ownerId) {
      await this.safely(() =>
        this.notifications.sendToUser(
          business.ownerId,
          'Vendiste una tarjeta',
          `${purchase.user?.fullName ?? 'Un cliente'} compró «${benefit}» por ${usd(purchase.amountCents)}. ` +
            `Te tocan ${usd(purchase.amountCents - purchase.commissionCents)} cuando la canjee.`,
          { type: 'card_sold', route: '/business_dashboard' },
        ),
      );
    }
  }

  private day(date: Date | null): string {
    if (!date) return '';
    const d = new Date(new Date(date).getTime() - 5 * 60 * 60 * 1000); // Ecuador, UTC-5
    return `${String(d.getUTCDate()).padStart(2, '0')}/${String(d.getUTCMonth() + 1).padStart(2, '0')}/${d.getUTCFullYear()}`;
  }

  // ------------------------------------------------------------------
  // Dueño
  // ------------------------------------------------------------------

  /** Lo vendido por los locales del dueño (o por todos, si es administrador) y lo que le toca. */
  async mySales(requester: Requester) {
    const businesses = await this.businessRepository.find({
      where: requester.role === UserRole.ADMIN ? {} : { ownerId: requester.id },
      select: ['id'],
    });
    if (businesses.length === 0) return this.emptySales();
    const businessIds = businesses.map((b) => b.id);

    const rows = await this.purchaseRepository.find({
      where: {
        businessId: In(businessIds),
        status: In([CardPurchaseStatus.PAID, CardPurchaseStatus.REFUND_DUE]),
      },
      relations: ['user', 'claim', 'campaign'],
      order: { paidAt: 'DESC' },
      take: 500,
    });

    const paid = rows.filter((r) => r.status === CardPurchaseStatus.PAID);
    const net = (r: CardPurchase) => r.amountCents - r.commissionCents;
    const sum = (list: CardPurchase[], f: (r: CardPurchase) => number) => list.reduce((t, r) => t + f(r), 0);
    const redeemed = paid.filter((r) => r.claim?.status === ClaimStatus.REDEEMED);

    return {
      sold: paid.length,
      grossCents: sum(paid, (r) => r.amountCents),
      commissionCents: sum(paid, (r) => r.commissionCents),
      netCents: sum(paid, net),
      redeemed: redeemed.length,
      /** Lo que ya puede cobrar el local: tarjetas canjeadas y aún no pagadas. */
      payableCents: sum(redeemed.filter((r) => !r.settledAt), net),
      /** Lo ya pagado al local. */
      paidOutCents: sum(paid.filter((r) => r.settledAt), net),
      /** Vendido pero todavía sin canjear. */
      pendingCents: sum(paid.filter((r) => r.claim?.status !== ClaimStatus.REDEEMED), net),
      recent: paid.slice(0, 20).map((r) => ({
        id: r.id,
        title: r.campaign?.benefitLabel ?? r.campaign?.title ?? null,
        buyer: r.user?.fullName ?? null,
        amountCents: r.amountCents,
        netCents: net(r),
        paidAt: r.paidAt,
        redeemed: r.claim?.status === ClaimStatus.REDEEMED,
        settled: !!r.settledAt,
      })),
    };
  }

  private emptySales() {
    return {
      sold: 0, grossCents: 0, commissionCents: 0, netCents: 0, redeemed: 0,
      payableCents: 0, paidOutCents: 0, pendingCents: 0, recent: [],
    };
  }

  // ------------------------------------------------------------------
  // Administrador
  // ------------------------------------------------------------------

  /** Lo que se le debe pagar a cada local (tarjetas canjeadas) y las compras por devolver. */
  async payouts() {
    const payable = await this.payableQuery()
      .select('p.business_id', 'businessId')
      .addSelect('COUNT(*)', 'cards')
      .addSelect('SUM(p.amount_cents - p.commission_cents)', 'netCents')
      .groupBy('p.business_id')
      .getRawMany<{ businessId: string; cards: string; netCents: string }>();

    const ids = payable.map((r) => r.businessId);
    const businesses = ids.length
      ? await this.businessRepository.find({ where: { id: In(ids) }, relations: ['owner'] })
      : [];

    const refunds = await this.purchaseRepository.find({
      where: { status: CardPurchaseStatus.REFUND_DUE },
      relations: ['user', 'business'],
      order: { paidAt: 'DESC' },
      take: 100,
    });

    return {
      payouts: payable
        .map((r) => {
          const business = businesses.find((b) => b.id === r.businessId);
          return {
            businessId: r.businessId,
            businessName: business?.name ?? null,
            ownerName: business?.owner?.fullName ?? null,
            ownerEmail: business?.owner?.email ?? null,
            cards: Number(r.cards),
            netCents: Number(r.netCents),
          };
        })
        .sort((a, b) => b.netCents - a.netCents),
      refunds: refunds.map((p) => ({
        id: p.id,
        reference: p.reference,
        amountCents: p.amountCents,
        buyer: p.user?.fullName ?? null,
        buyerEmail: p.user?.email ?? null,
        businessName: p.business?.name ?? null,
        paidAt: p.paidAt,
      })),
    };
  }

  /** Las transferencias con comprobante por revisar, de la más antigua a la más nueva. */
  async reviews() {
    const rows = await this.purchaseRepository.find({
      where: { status: CardPurchaseStatus.IN_REVIEW, method: CardPurchaseMethod.TRANSFER },
      relations: ['user', 'business', 'campaign'],
      order: { reportedAt: 'ASC' },
      take: 200,
    });
    return rows.map((p) => ({
      id: p.id,
      reference: p.reference,
      amountCents: p.amountCents,
      title: p.campaign?.benefitLabel ?? p.campaign?.title ?? null,
      buyer: p.user?.fullName ?? null,
      buyerEmail: p.user?.email ?? null,
      businessName: p.business?.name ?? null,
      proofUrl: p.proofUrl,
      note: p.transferNote,
      reportedAt: p.reportedAt,
    }));
  }

  /** Cuántas transferencias esperan revisión (para el aviso del panel). */
  countReviews(): Promise<number> {
    return this.purchaseRepository.count({
      where: { status: CardPurchaseStatus.IN_REVIEW, method: CardPurchaseMethod.TRANSFER },
    });
  }

  /** El administrador aprueba el comprobante: el cliente recibe su tarjeta (una sola vez). */
  async approve(purchaseId: string, adminId: string) {
    // Quien llega primero se queda con la revisión: así dos administradores no la entregan dos veces.
    const claimed = await this.purchaseRepository.update(
      { id: purchaseId, status: CardPurchaseStatus.IN_REVIEW, reviewedAt: IsNull() },
      { reviewedAt: new Date(), reviewedById: adminId },
    );
    if (claimed.affected !== 1) {
      const exists = await this.purchaseRepository.exists({ where: { id: purchaseId } });
      if (!exists) throw new NotFoundException('Compra no encontrada');
      throw new ConflictException('Este comprobante ya fue revisado');
    }
    const purchase = await this.purchaseRepository.findOne({
      where: { id: purchaseId },
      relations: ['campaign', 'campaign.participants', 'campaign.participants.business', 'user'],
    });
    try {
      const result = await this.deliver(purchase!);
      return { id: purchaseId, reference: purchase!.reference, outcome: result.outcome };
    } catch (error) {
      // Que se pueda volver a intentar.
      await this.purchaseRepository.update({ id: purchaseId }, { reviewedAt: null, reviewedById: null });
      throw error;
    }
  }

  /** El administrador no acepta el comprobante: se libera el cupo y se le dice al cliente por qué. */
  async reject(purchaseId: string, adminId: string, reason: string) {
    const note = reason?.trim();
    if (!note) throw new BadRequestException('Escribe el motivo para que el cliente sepa qué corregir');
    const purchase = await this.purchaseRepository.findOne({ where: { id: purchaseId } });
    if (!purchase) throw new NotFoundException('Compra no encontrada');

    const result = await this.purchaseRepository.update(
      { id: purchaseId, status: CardPurchaseStatus.IN_REVIEW, reviewedAt: IsNull() },
      {
        status: CardPurchaseStatus.REJECTED,
        reviewNote: note.slice(0, 300),
        reviewedById: adminId,
        reviewedAt: new Date(),
      },
    );
    if (result.affected !== 1) throw new ConflictException('Este comprobante ya fue revisado');

    await this.safely(() =>
      this.notifications.sendToUser(
        purchase.userId,
        'Comprobante no aceptado',
        `No pudimos validar tu pago de ${usd(purchase.amountCents)} (${purchase.reference}): ${note.slice(0, 300)}. Puedes intentarlo de nuevo desde la tarjeta.`,
        { type: 'card_transfer_rejected', route: '/my_gifts' },
      ),
    );
    return { id: purchaseId, status: CardPurchaseStatus.REJECTED };
  }

  /** Compras pagadas, con la tarjeta ya canjeada y sin pago al local todavía. */
  private payableQuery() {
    return this.purchaseRepository
      .createQueryBuilder('p')
      .innerJoin('campaign_claims', 'c', 'c.id = p.claim_id')
      .where('p.status = :paid', { paid: CardPurchaseStatus.PAID })
      .andWhere('p.settled_at IS NULL')
      .andWhere('c.status = :redeemed', { redeemed: ClaimStatus.REDEEMED });
  }

  /** El administrador registra que ya le pagó al local lo de sus tarjetas canjeadas. */
  async settle(businessId: string, adminId: string, note?: string) {
    return this.purchaseRepository.manager.transaction(async (manager) => {
      const due = await manager
        .getRepository(CardPurchase)
        .createQueryBuilder('p')
        .setLock('pessimistic_write')
        .innerJoin('campaign_claims', 'c', 'c.id = p.claim_id')
        .where('p.business_id = :businessId', { businessId })
        .andWhere('p.status = :paid', { paid: CardPurchaseStatus.PAID })
        .andWhere('p.settled_at IS NULL')
        .andWhere('c.status = :redeemed', { redeemed: ClaimStatus.REDEEMED })
        .getMany();
      if (due.length === 0) {
        throw new BadRequestException('Este local no tiene tarjetas canjeadas por pagar');
      }

      const now = new Date();
      for (const p of due) {
        p.settledAt = now;
        p.settledById = adminId;
        p.settlementNote = note?.trim().slice(0, 200) || null;
      }
      await manager.save(due);
      const amountCents = due.reduce((t, p) => t + p.amountCents - p.commissionCents, 0);

      const business = await manager.findOne(Business, { where: { id: businessId } });
      if (business?.ownerId) {
        await this.safely(() =>
          this.notifications.sendToUser(
            business.ownerId,
            'Te pagamos tus tarjetas canjeadas',
            `Registramos un pago de ${usd(amountCents)} por ${due.length} ${due.length === 1 ? 'tarjeta canjeada' : 'tarjetas canjeadas'}.`,
            { type: 'card_payout', route: '/business_dashboard' },
          ),
        );
      }
      return { settled: due.length, amountCents };
    });
  }

  /** El administrador marca una compra por devolver como ya devuelta. */
  async markRefunded(purchaseId: string, adminId: string, note?: string) {
    const purchase = await this.purchaseRepository.findOne({ where: { id: purchaseId } });
    if (!purchase) throw new NotFoundException('Compra no encontrada');
    if (purchase.status !== CardPurchaseStatus.REFUND_DUE) {
      throw new BadRequestException('Esta compra no está por devolver');
    }
    purchase.status = CardPurchaseStatus.FAILED;
    purchase.settledAt = new Date();
    purchase.settledById = adminId;
    purchase.settlementNote = `Devuelta${note ? `: ${note.trim()}` : ''}`.slice(0, 200);
    await this.purchaseRepository.save(purchase);
    return { id: purchase.id, status: purchase.status };
  }

  private async safely(task: () => Promise<unknown>) {
    try {
      await task();
    } catch (error) {
      this.logger.warn(`Aviso de venta no enviado: ${error.message}`);
    }
  }
}
