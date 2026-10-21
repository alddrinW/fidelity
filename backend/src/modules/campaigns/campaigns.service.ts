import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomBytes } from 'crypto';
import { Between, In, IsNull, LessThanOrEqual, MoreThan, MoreThanOrEqual, Not, Repository } from 'typeorm';
import {
  Campaign,
  CampaignAudience,
  CampaignBenefit,
  CampaignPhase,
  CampaignType,
  campaignPhase,
} from '../../database/entities/campaign.entity';
import { CampaignBusiness } from '../../database/entities/campaign-business.entity';
import {
  CampaignClaim,
  ClaimSource,
  ClaimStatus,
} from '../../database/entities/campaign-claim.entity';
import { CampaignStamp } from '../../database/entities/campaign-stamp.entity';
import { CampaignRecipient } from '../../database/entities/campaign-recipient.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Scan, ScanStatus } from '../../database/entities/scan.entity';
import { UserRole } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { BusinessAccessService } from '../businesses/business-access.service';
import { CreateCampaignDto, UpdateCampaignDto } from './dto/campaigns.dto';

type Requester = { id: string; role: UserRole };

// Sin 0/O/1/I para que el código sea fácil de dictar.
const CODE_ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

/** Máximo de clientes a los que se avisa por campaña. */
export const MAX_AUDIENCE = 5000;

export function randomCode(prefix: string, length = 6): string {
  const bytes = randomBytes(length);
  let code = '';
  for (let i = 0; i < length; i++) code += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
  return `${prefix}-${code}`;
}

@Injectable()
export class CampaignsService {
  private readonly logger = new Logger(CampaignsService.name);

  constructor(
    @InjectRepository(Campaign)
    private readonly campaignRepository: Repository<Campaign>,
    @InjectRepository(CampaignBusiness)
    private readonly participantRepository: Repository<CampaignBusiness>,
    @InjectRepository(CampaignClaim)
    private readonly claimRepository: Repository<CampaignClaim>,
    @InjectRepository(CampaignStamp)
    private readonly stampRepository: Repository<CampaignStamp>,
    @InjectRepository(CampaignRecipient)
    private readonly recipientRepository: Repository<CampaignRecipient>,
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(LoyaltyCard)
    private readonly cardRepository: Repository<LoyaltyCard>,
    @InjectRepository(Scan)
    private readonly scanRepository: Repository<Scan>,
    private readonly notificationsService: NotificationsService,
    private readonly businessAccess: BusinessAccessService,
  ) {}

  // ------------------------------------------------------------------
  // Dueño
  // ------------------------------------------------------------------

  async create(requester: Requester, dto: CreateCampaignDto) {
    const businessIds = [...new Set(dto.businessIds)];
    const businesses = await this.businessRepository.find({ where: { id: In(businessIds) } });
    if (businesses.length !== businessIds.length) {
      throw new BadRequestException('Alguno de los negocios elegidos no existe');
    }
    if (requester.role !== UserRole.ADMIN && businesses.some((b) => b.ownerId !== requester.id)) {
      throw new ForbiddenException('Solo puedes crear campañas para tus propios negocios');
    }
    if (businesses.some((b) => !b.isActive)) {
      throw new BadRequestException('Solo los negocios activos pueden lanzar campañas');
    }

    const now = new Date();
    const startsAt = dto.startsAt && new Date(dto.startsAt) > now ? new Date(dto.startsAt) : now;
    const endsAt = dto.endsAt ? new Date(dto.endsAt) : null;
    if (endsAt && endsAt <= now) {
      throw new BadRequestException('La fecha de fin ya pasó');
    }
    if (endsAt && endsAt <= startsAt) {
      throw new BadRequestException('La fecha de fin debe ser posterior al inicio');
    }

    const benefit = this.resolveBenefit(dto, businessIds.length);

    // Gift cards: a todos los clientes o solo a los elegidos (que deben serlo).
    const audience: CampaignAudience =
      dto.type === CampaignType.GIFT_CARD && dto.audience === 'selected' ? 'selected' : 'all';
    const recipientIds = [...new Set(dto.recipientIds ?? [])];
    if (audience === 'selected') {
      if (recipientIds.length === 0) {
        throw new BadRequestException('Elige al menos un cliente para la gift card');
      }
      const cards = await this.cardRepository.find({
        where: { userId: In(recipientIds), businessId: In(businessIds) },
        select: ['userId'],
      });
      if (new Set(cards.map((c) => c.userId)).size !== recipientIds.length) {
        throw new BadRequestException('Algunos clientes elegidos no son clientes de este negocio');
      }
    }

    const campaign = await this.campaignRepository.save(
      this.campaignRepository.create({
        businessId: businessIds[0],
        type: dto.type,
        title: dto.title.trim(),
        description: dto.description?.trim() || null,
        imageUrl: dto.imageUrl || null,
        ...benefit,
        audience,
        startsAt,
        endsAt,
      }),
    );
    if (audience === 'selected') {
      await this.recipientRepository.save(
        recipientIds.map((userId) =>
          this.recipientRepository.create({ campaignId: campaign.id, userId }),
        ),
      );
    }
    await this.participantRepository.save(
      businessIds.map((businessId) =>
        this.participantRepository.create({ campaignId: campaign.id, businessId }),
      ),
    );

    // Si empieza ya, se avisa en seguida; si está programada, lo hace el
    // programador (CampaignSchedulerService) cuando llegue su hora.
    if (campaignPhase(campaign, now) === 'active') {
      void this.dispatch(campaign.id).catch((e) =>
        this.logger.warn(`No se pudo avisar de la campaña ${campaign.id}: ${e.message}`),
      );
    }

    return this.findOneView(campaign.id);
  }

  /** Beneficio de la campaña según su tipo (valida y normaliza). */
  private resolveBenefit(dto: CreateCampaignDto, participants: number) {
    const none = {
      benefitType: null,
      benefitValue: null,
      benefitLabel: null,
      requiredStamps: null,
      requiredScans: null,
    };

    /** El beneficio de una gift card (y del premio de un reto): descuento o mini premio. */
    const giftBenefit = () => {
      if (!dto.benefitType) {
        throw new BadRequestException('Elige el beneficio: descuento o mini premio');
      }
      if (dto.benefitType === CampaignBenefit.DISCOUNT_PERCENT) {
        if (!dto.benefitValue) {
          throw new BadRequestException('Indica el porcentaje de descuento (1 a 100)');
        }
        return {
          ...none,
          benefitType: dto.benefitType,
          benefitValue: dto.benefitValue,
          benefitLabel: dto.benefitLabel?.trim() || `${dto.benefitValue}% de descuento`,
        };
      }
      if (!dto.benefitLabel?.trim()) {
        throw new BadRequestException('Describe el mini premio');
      }
      return { ...none, benefitType: dto.benefitType, benefitLabel: dto.benefitLabel.trim() };
    };

    switch (dto.type) {
      case CampaignType.EVENT:
        return none;

      case CampaignType.GIFT_CARD:
        return giftBenefit();

      case CampaignType.SCAN_CHALLENGE:
        if (!dto.requiredScans) {
          throw new BadRequestException('Indica cuántos escaneos debe hacer el cliente');
        }
        return { ...giftBenefit(), requiredScans: dto.requiredScans };

      case CampaignType.ROUTE: {
        if (participants < 2) {
          throw new BadRequestException('Una ruta necesita al menos 2 locales');
        }
        if (!dto.benefitLabel?.trim()) {
          throw new BadRequestException('Describe el premio de la ruta');
        }
        const required = dto.requiredStamps ?? participants;
        if (required > participants) {
          throw new BadRequestException('Los sellos requeridos no pueden superar la cantidad de locales');
        }
        return {
          ...none,
          benefitType: CampaignBenefit.MINI_PRIZE,
          benefitLabel: dto.benefitLabel.trim(),
          requiredStamps: required,
        };
      }
    }
  }

  async update(id: string, requester: Requester, dto: UpdateCampaignDto) {
    const campaign = await this.getManageable(id, requester);
    const now = new Date();
    const phase = campaignPhase(campaign, now);
    if (phase === 'cancelled' || phase === 'ended') {
      throw new BadRequestException('Una campaña terminada o cancelada no se puede editar');
    }

    if (dto.startsAt) {
      if (phase !== 'scheduled') {
        throw new BadRequestException('La fecha de inicio solo se cambia antes de que empiece');
      }
      const startsAt = new Date(dto.startsAt);
      campaign.startsAt = startsAt > now ? startsAt : now;
    }
    if (dto.endsAt) {
      const endsAt = new Date(dto.endsAt);
      if (endsAt <= now) throw new BadRequestException('La fecha de fin ya pasó');
      if (endsAt <= campaign.startsAt) {
        throw new BadRequestException('La fecha de fin debe ser posterior al inicio');
      }
      campaign.endsAt = endsAt;
    }
    let benefitChanged = false;
    if (dto.benefitLabel !== undefined || dto.benefitValue !== undefined) {
      if (campaign.type !== CampaignType.GIFT_CARD) {
        throw new BadRequestException('Solo las gift cards tienen un beneficio editable');
      }
      if (campaign.benefitType === CampaignBenefit.DISCOUNT_PERCENT) {
        if (dto.benefitValue !== undefined) campaign.benefitValue = dto.benefitValue;
        campaign.benefitLabel =
          dto.benefitLabel?.trim() || `${campaign.benefitValue}% de descuento`;
      } else {
        if (dto.benefitValue !== undefined) {
          throw new BadRequestException('Un mini premio no lleva porcentaje de descuento');
        }
        const label = dto.benefitLabel?.trim();
        if (!label) throw new BadRequestException('Describe el mini premio');
        campaign.benefitLabel = label;
      }
      benefitChanged = true;
    }
    const endChanged = !!dto.endsAt;
    if (dto.title) campaign.title = dto.title.trim();
    if (dto.description !== undefined) campaign.description = dto.description.trim() || null;
    if (dto.imageUrl !== undefined) campaign.imageUrl = dto.imageUrl || null;

    await this.campaignRepository.save(campaign);

    // Quienes ya tienen la gift card se enteran de que cambió.
    if (campaign.type === CampaignType.GIFT_CARD && (benefitChanged || endChanged)) {
      await this.safely(() =>
        this.notifyHolders(
          campaign,
          'Tu gift card cambió',
          `Actualizamos "${campaign.title}": ${campaign.benefitLabel ?? 'revisa los detalles'}.`,
          'gift_card_updated',
        ),
      );
    }
    return this.findOneView(id);
  }

  async cancel(id: string, requester: Requester) {
    const campaign = await this.getManageable(id, requester);
    const phase = campaignPhase(campaign);
    if (phase === 'cancelled') throw new BadRequestException('La campaña ya estaba cancelada');
    if (phase === 'ended') throw new BadRequestException('La campaña ya terminó');

    campaign.cancelledAt = new Date();
    await this.campaignRepository.save(campaign);

    if (campaign.type === CampaignType.GIFT_CARD) {
      await this.safely(() =>
        this.notifyHolders(
          campaign,
          'Gift card cancelada',
          `El local canceló la gift card "${campaign.title}". Ya no se puede canjear.`,
          'gift_card_cancelled',
        ),
      );
    }
    return this.findOneView(id);
  }

  /** Campañas de los negocios del dueño (o todas, si es administrador). */
  async listMine(requester: Requester) {
    let campaignIds: string[] | undefined;
    if (requester.role !== UserRole.ADMIN) {
      const businesses = await this.businessRepository.find({
        where: { ownerId: requester.id },
        select: ['id'],
      });
      if (businesses.length === 0) return [];
      const links = await this.participantRepository.find({
        where: { businessId: In(businesses.map((b) => b.id)) },
      });
      campaignIds = [...new Set(links.map((l) => l.campaignId))];
      if (campaignIds.length === 0) return [];
    }

    const campaigns = await this.campaignRepository.find({
      where: campaignIds ? { id: In(campaignIds), hidden: false } : { hidden: false },
      relations: ['participants', 'participants.business'],
      order: { createdAt: 'DESC' },
      take: 200,
    });
    if (campaigns.length === 0) return [];

    const ids = campaigns.map((c) => c.id);
    const [claims, stamps, recipients] = await Promise.all([
      this.claimRepository.find({ where: { campaignId: In(ids) }, select: ['campaignId', 'status'] }),
      this.stampRepository.find({ where: { campaignId: In(ids) }, select: ['campaignId', 'userId'] }),
      this.recipientRepository.find({ where: { campaignId: In(ids) }, select: ['campaignId'] }),
    ]);

    return campaigns.map((c) => ({
      ...this.toView(c),
      stats: {
        recipients: recipients.filter((x) => x.campaignId === c.id).length,
        claims: claims.filter((x) => x.campaignId === c.id).length,
        redeemed: claims.filter((x) => x.campaignId === c.id && x.status === ClaimStatus.REDEEMED)
          .length,
        participants: new Set(stamps.filter((s) => s.campaignId === c.id).map((s) => s.userId)).size,
      },
    }));
  }

  /** Tarjetas y premios emitidos por una campaña, para quien opera el local. */
  async claimsForCampaign(id: string, requester: Requester) {
    const campaign = await this.campaignRepository.findOne({
      where: { id },
      relations: ['participants'],
    });
    if (!campaign) throw new NotFoundException('Campaña no encontrada');
    await this.assertCanOperate(requester, campaign);

    const claims = await this.claimRepository.find({
      where: { campaignId: id },
      relations: ['user'],
      order: { createdAt: 'DESC' },
      take: 200,
    });
    return claims.map((c) => ({
      id: c.id,
      code: c.code,
      status: c.status,
      source: c.source,
      createdAt: c.createdAt,
      redeemedAt: c.redeemedAt,
      userName: c.user?.fullName ?? null,
      userEmail: c.user?.email ?? null,
    }));
  }

  /** El local canjea el código que le muestra el cliente. */
  async redeem(requester: Requester, rawCode: string) {
    const code = rawCode.trim().toUpperCase();
    const claim = await this.claimRepository.findOne({
      where: { code },
      relations: ['campaign', 'campaign.participants', 'user'],
    });
    if (!claim) throw new NotFoundException('Código no válido');

    await this.assertCanOperate(requester, claim.campaign);

    if (claim.status === ClaimStatus.REDEEMED) {
      throw new ConflictException('Este código ya fue canjeado');
    }
    const phase = campaignPhase(claim.campaign);
    if (phase === 'cancelled') throw new BadRequestException('La campaña fue cancelada');
    if (phase === 'ended') throw new BadRequestException('La campaña ya terminó');

    claim.status = ClaimStatus.REDEEMED;
    claim.redeemedAt = new Date();
    claim.redeemedById = requester.id;
    await this.claimRepository.save(claim);

    await this.safely(() =>
      this.notificationsService.sendToUser(
        claim.userId,
        'Tarjeta canjeada',
        `Canjeaste: ${claim.campaign.benefitLabel ?? claim.campaign.title}. ¡Disfrútalo!`,
        { type: 'claim_redeemed' },
      ),
    );

    return {
      id: claim.id,
      code: claim.code,
      status: claim.status,
      redeemedAt: claim.redeemedAt,
      campaignTitle: claim.campaign.title,
      benefitLabel: claim.campaign.benefitLabel,
      userName: claim.user?.fullName ?? null,
    };
  }

  // ------------------------------------------------------------------
  // Cliente
  // ------------------------------------------------------------------

  /** Novedades: campañas vigentes de los negocios donde el cliente tiene tarjeta. */
  async feed(userId: string) {
    const cards = await this.cardRepository.find({ where: { userId }, select: ['businessId'] });
    const businessIds = [...new Set(cards.map((c) => c.businessId))];
    if (businessIds.length === 0) return [];

    const links = await this.participantRepository.find({ where: { businessId: In(businessIds) } });
    const campaignIds = [...new Set(links.map((l) => l.campaignId))];
    if (campaignIds.length === 0) return [];

    const now = new Date();
    const campaigns = await this.campaignRepository.find({
      where: [
        { id: In(campaignIds), hidden: false, cancelledAt: IsNull(), startsAt: LessThanOrEqual(now), endsAt: IsNull() },
        { id: In(campaignIds), hidden: false, cancelledAt: IsNull(), startsAt: LessThanOrEqual(now), endsAt: MoreThan(now) },
      ],
      relations: ['participants', 'participants.business'],
      order: { startsAt: 'DESC' },
      take: 50,
    });
    if (campaigns.length === 0) return [];

    const ids = campaigns.map((c) => c.id);
    const [claims, stamps, chosen] = await Promise.all([
      this.claimRepository.find({ where: { campaignId: In(ids), userId } }),
      this.stampRepository.find({ where: { campaignId: In(ids), userId } }),
      this.recipientRepository.find({ where: { campaignId: In(ids), userId }, select: ['campaignId'] }),
    ]);
    const chosenIds = new Set(chosen.map((r) => r.campaignId));
    const claimedIds = new Set(claims.map((c) => c.campaignId));

    // Una gift card para clientes elegidos solo la ve quien fue elegido o ya la tiene.
    const visible = campaigns.filter(
      (c) =>
        c.type !== CampaignType.GIFT_CARD ||
        c.audience !== 'selected' ||
        chosenIds.has(c.id) ||
        claimedIds.has(c.id),
    );

    // El avance del cliente en cada reto de escaneos.
    const progress = new Map<string, number>();
    for (const c of visible) {
      if (c.type === CampaignType.SCAN_CHALLENGE) {
        progress.set(c.id, await this.challengeProgress(c, userId));
      }
    }

    return visible.map((c) => {
      const claim = claims.find((x) => x.campaignId === c.id) ?? null;
      const stamped = stamps.filter((s) => s.campaignId === c.id).map((s) => s.businessId);
      return {
        ...this.toView(c),
        claim: claim && this.claimView(claim),
        stampedBusinessIds: stamped,
        scanProgress: progress.get(c.id) ?? 0,
        completed:
          !!claim &&
          (claim.source === ClaimSource.ROUTE_COMPLETE || claim.source === ClaimSource.CHALLENGE_COMPLETE),
      };
    });
  }

  /** El cliente reclama la tarjeta de regalo de una campaña. */
  async claim(userId: string, campaignId: string) {
    const campaign = await this.campaignRepository.findOne({
      where: { id: campaignId },
      relations: ['participants'],
    });
    if (!campaign) throw new NotFoundException('Campaña no encontrada');
    if (campaign.type !== CampaignType.GIFT_CARD) {
      throw new BadRequestException('Esta campaña no tiene tarjeta de regalo');
    }
    if (campaignPhase(campaign) !== 'active') {
      throw new BadRequestException('Esta campaña no está vigente');
    }

    if (campaign.audience === 'selected') {
      const chosen = await this.recipientRepository.exists({ where: { campaignId, userId } });
      if (!chosen) throw new ForbiddenException('Esta gift card no es para ti');
    }

    const participantIds = campaign.participants.map((p) => p.businessId);
    const hasCard = await this.cardRepository.exists({
      where: { userId, businessId: In(participantIds) },
    });
    if (!hasCard) {
      throw new ForbiddenException('Solo los clientes de este local pueden reclamar la tarjeta');
    }

    const existing = await this.claimRepository.findOne({ where: { campaignId, userId } });
    if (existing) return this.claimView(existing);

    try {
      const saved = await this.claimRepository.save(
        this.claimRepository.create({
          campaignId,
          userId,
          code: randomCode('GFT'),
          status: ClaimStatus.ACTIVE,
          source: ClaimSource.CLAIM,
        }),
      );
      return this.claimView(saved);
    } catch (error) {
      // Dos toques seguidos: la restricción única ya creó la tarjeta.
      if (error?.code === '23505') {
        const again = await this.claimRepository.findOne({ where: { campaignId, userId } });
        if (again) return this.claimView(again);
      }
      throw error;
    }
  }

  /** Tarjetas de regalo y premios de ruta del cliente. */
  async myClaims(userId: string) {
    const claims = await this.claimRepository.find({
      where: { userId },
      relations: ['campaign', 'campaign.participants', 'campaign.participants.business'],
      order: { createdAt: 'DESC' },
      take: 100,
    });
    return claims.map((c) => ({
      ...this.claimView(c),
      campaign: this.toView(c.campaign),
    }));
  }

  // ------------------------------------------------------------------
  // Rutas: sellos por escaneos aprobados
  // ------------------------------------------------------------------

  /**
   * Suma un sello en las rutas vigentes que incluyen el local del escaneo. Al
   * juntar los sellos requeridos emite el premio de la ruta. Solo cuentan los
   * escaneos reales de un QR (no los puntos regalados a mano).
   */
  async registerApprovedScan(scan: {
    id: string;
    userId: string;
    businessId: string;
    qrCodeId?: string | null;
    scannedAt?: Date;
  }): Promise<number> {
    if (!scan.qrCodeId) return 0;
    const at = scan.scannedAt ? new Date(scan.scannedAt) : new Date();

    const links = await this.participantRepository.find({
      where: { businessId: scan.businessId },
      relations: ['campaign', 'campaign.participants'],
    });
    const routes = links
      .map((l) => l.campaign)
      .filter((c) => c.type === CampaignType.ROUTE && campaignPhase(c, at) === 'active');

    let added = 0;
    for (const route of routes) {
      const already = await this.stampRepository.exists({
        where: { campaignId: route.id, userId: scan.userId, businessId: scan.businessId },
      });
      if (already) continue;

      await this.stampRepository.save(
        this.stampRepository.create({
          campaignId: route.id,
          userId: scan.userId,
          businessId: scan.businessId,
          scanId: scan.id,
        }),
      );
      added++;
      await this.afterStamp(route, scan.userId);
    }

    // Retos de escaneos vigentes de este local: el escaneo suma a su avance.
    const challenges = links
      .map((l) => l.campaign)
      .filter((c) => c.type === CampaignType.SCAN_CHALLENGE && campaignPhase(c, at) === 'active');
    for (const challenge of challenges) {
      await this.afterChallengeScan(challenge, scan.userId);
    }
    return added;
  }

  /**
   * Cuántos escaneos reales (de un QR) aprobados lleva el cliente en los
   * locales del reto, desde que empezó. Se cuenta de los escaneos, así que es
   * siempre exacto y no se duplica.
   */
  async challengeProgress(challenge: Campaign, userId: string): Promise<number> {
    const businessIds = (challenge.participants ?? []).map((p) => p.businessId);
    if (businessIds.length === 0) return 0;
    const end = challenge.endsAt;
    return this.scanRepository.count({
      where: {
        userId,
        businessId: In(businessIds),
        status: ScanStatus.APPROVED,
        qrCodeId: Not(IsNull()),
        scannedAt: end ? Between(challenge.startsAt, end) : MoreThanOrEqual(challenge.startsAt),
      },
    });
  }

  private async afterChallengeScan(challenge: Campaign, userId: string) {
    const required = challenge.requiredScans ?? 0;
    if (required < 1) return;
    const done = await this.challengeProgress(challenge, userId);

    if (done < required) {
      await this.safely(() =>
        this.notificationsService.sendToUser(
          userId,
          `Reto: ${challenge.title}`,
          `Llevas ${done} de ${required} escaneos. ¡Sigue así!`,
          { type: 'challenge_progress', campaign_id: challenge.id },
        ),
      );
      return;
    }

    const existing = await this.claimRepository.findOne({ where: { campaignId: challenge.id, userId } });
    if (existing) return;
    let claim: CampaignClaim;
    try {
      claim = await this.claimRepository.save(
        this.claimRepository.create({
          campaignId: challenge.id,
          userId,
          code: randomCode('RTO'),
          status: ClaimStatus.ACTIVE,
          source: ClaimSource.CHALLENGE_COMPLETE,
        }),
      );
    } catch (error) {
      // Dos escaneos a la vez: la restricción única ya entregó el premio.
      if (error?.code === '23505') return;
      throw error;
    }
    await this.safely(() =>
      this.notificationsService.sendToUser(
        userId,
        `¡Completaste el reto ${challenge.title}!`,
        `Tu premio: ${challenge.benefitLabel}. Ábrelo en Mis regalos.`,
        { type: 'challenge_completed', campaign_id: challenge.id, route: '/my_gifts' },
      ),
    );
  }

  private async afterStamp(route: Campaign, userId: string) {
    const required = route.requiredStamps ?? route.participants.length;
    const stamps = await this.stampRepository.count({ where: { campaignId: route.id, userId } });

    if (stamps >= required) {
      const existing = await this.claimRepository.findOne({
        where: { campaignId: route.id, userId },
      });
      if (existing) return;
      const claim = await this.claimRepository.save(
        this.claimRepository.create({
          campaignId: route.id,
          userId,
          code: randomCode('RTA'),
          status: ClaimStatus.ACTIVE,
          source: ClaimSource.ROUTE_COMPLETE,
        }),
      );
      await this.safely(() =>
        this.notificationsService.sendToUser(
          userId,
          `¡Completaste la ruta ${route.title}!`,
          `Muestra el código ${claim.code} para reclamar: ${route.benefitLabel}.`,
          { type: 'route_completed' },
        ),
      );
    } else {
      await this.safely(() =>
        this.notificationsService.sendToUser(
          userId,
          `Nuevo sello en ${route.title}`,
          `Llevas ${stamps} de ${required} sellos. ¡Sigue la ruta!`,
          { type: 'route_stamp' },
        ),
      );
    }
  }

  // ------------------------------------------------------------------
  // Programación y avisos
  // ------------------------------------------------------------------

  /**
   * Avisa a los clientes de las campañas que ya empezaron y todavía no se
   * notificaron (las programadas llegan aquí cuando se cumple su hora).
   */
  async dispatchDue(now: Date = new Date()): Promise<number> {
    const due = await this.campaignRepository.find({
      where: [
        { notifiedAt: IsNull(), cancelledAt: IsNull(), startsAt: LessThanOrEqual(now), endsAt: IsNull() },
        { notifiedAt: IsNull(), cancelledAt: IsNull(), startsAt: LessThanOrEqual(now), endsAt: MoreThan(now) },
      ],
      select: ['id'],
      take: 50,
    });
    for (const campaign of due) {
      await this.dispatch(campaign.id);
    }
    return due.length;
  }

  /** Marca la campaña como avisada y notifica a su audiencia. */
  async dispatch(campaignId: string): Promise<number> {
    // Se marca primero: un reinicio a mitad de envío no debe duplicar avisos.
    const claimed = await this.campaignRepository.update(
      { id: campaignId, notifiedAt: IsNull() },
      { notifiedAt: new Date() },
    );
    if (!claimed.affected) return 0;

    const campaign = await this.campaignRepository.findOne({
      where: { id: campaignId },
      relations: ['participants', 'participants.business'],
    });
    if (!campaign) return 0;

    const audienceIds = await this.audienceUserIds(campaign);
    if (audienceIds.length === 0) return 0;

    // Una gift card no espera a que el cliente la reclame: se le entrega ya,
    // con su propio código, y el aviso le dice que la abra en "Mis regalos".
    if (campaign.type === CampaignType.GIFT_CARD) {
      const issued = await this.issueGiftCards(campaign, audienceIds);
      if (issued.length === 0) return 0;
      const gift = this.announcement(campaign);
      return this.notificationsService.sendToUsers(issued, gift.title, gift.body, {
        type: 'gift_card',
        campaign_id: campaign.id,
        route: '/my_gifts',
      });
    }

    const { title, body } = this.announcement(campaign);
    return this.notificationsService.sendToUsers(audienceIds, title, body, {
      type: 'campaign',
      campaign_id: campaign.id,
    });
  }

  /** A quién le llega la campaña: los clientes del local o, en una gift card, los elegidos. */
  private async audienceUserIds(campaign: Campaign): Promise<string[]> {
    if (campaign.type === CampaignType.GIFT_CARD && campaign.audience === 'selected') {
      const recipients = await this.recipientRepository.find({
        where: { campaignId: campaign.id },
        select: ['userId'],
        take: MAX_AUDIENCE,
      });
      return recipients.map((r) => r.userId);
    }
    const businessIds = campaign.participants.map((p) => p.businessId);
    const cards = await this.cardRepository.find({
      where: { businessId: In(businessIds) },
      select: ['userId'],
      take: MAX_AUDIENCE * 4,
    });
    return [...new Set(cards.map((c) => c.userId))].slice(0, MAX_AUDIENCE);
  }

  /**
   * Emite una gift card (con su código) a cada cliente que aún no la tiene.
   * Devuelve a quiénes se les entregó ahora.
   */
  private async issueGiftCards(campaign: Campaign, userIds: string[]): Promise<string[]> {
    const have = new Set(
      (
        await this.claimRepository.find({
          where: { campaignId: campaign.id, userId: In(userIds) },
          select: ['userId'],
        })
      ).map((c) => c.userId),
    );
    const todo = userIds.filter((id) => !have.has(id));

    const issued: string[] = [];
    const batchSize = 200;
    for (let i = 0; i < todo.length; i += batchSize) {
      const batch = todo.slice(i, i + batchSize);
      const rows = batch.map((userId) =>
        this.claimRepository.create({
          campaignId: campaign.id,
          userId,
          code: randomCode('GFT'),
          status: ClaimStatus.ACTIVE,
          source: ClaimSource.CLAIM,
        }),
      );
      try {
        await this.claimRepository.save(rows);
        issued.push(...batch);
      } catch {
        // Un choque (dos tarjetas a la vez o un código repetido): una por una.
        for (const row of rows) {
          try {
            await this.claimRepository.save(row);
            issued.push(row.userId);
          } catch (error) {
            if (error?.code !== '23505') this.logger.warn(`Gift card no emitida: ${error?.message}`);
          }
        }
      }
    }
    return issued;
  }

  /** Avisa a quienes tienen la gift card vigente (sin canjear). */
  private async notifyHolders(
    campaign: Campaign,
    title: string,
    body: string,
    type: string,
  ): Promise<void> {
    const holders = await this.claimRepository.find({
      where: { campaignId: campaign.id, status: ClaimStatus.ACTIVE },
      select: ['userId'],
    });
    await this.notificationsService.sendToUsers(
      holders.map((h) => h.userId),
      title,
      body,
      { type, campaign_id: campaign.id, route: '/my_gifts' },
    );
  }

  /** Clientes de los negocios del dueño, para elegir a quién le llega una gift card. */
  async customersFor(requester: Requester, businessIds: string[], q?: string) {
    const ids = [...new Set(businessIds)];
    if (ids.length === 0) return [];
    const businesses = await this.businessRepository.find({ where: { id: In(ids) } });
    if (businesses.length !== ids.length) {
      throw new BadRequestException('Alguno de los negocios elegidos no existe');
    }
    if (requester.role !== UserRole.ADMIN && businesses.some((b) => b.ownerId !== requester.id)) {
      throw new ForbiddenException('Solo puedes ver los clientes de tus propios negocios');
    }

    const cards = await this.cardRepository.find({
      where: { businessId: In(ids) },
      relations: ['user'],
      take: 2000,
    });
    const term = q?.trim().toLowerCase();
    const seen = new Map<string, { id: string; fullName: string | null; email: string }>();
    for (const card of cards) {
      const u = card.user;
      if (!u || seen.has(u.id)) continue;
      if (term && !`${u.fullName ?? ''} ${u.email}`.toLowerCase().includes(term)) continue;
      seen.set(u.id, { id: u.id, fullName: u.fullName ?? null, email: u.email });
    }
    return [...seen.values()]
      .sort((a, b) => (a.fullName ?? a.email).localeCompare(b.fullName ?? b.email))
      .slice(0, 200);
  }

  private announcement(campaign: Campaign): { title: string; body: string } {
    const business = campaign.participants[0]?.business?.name ?? 'Tu local';
    const text = (campaign.description ?? '').slice(0, 100);
    switch (campaign.type) {
      case CampaignType.GIFT_CARD:
        return {
          title: `${business} te regaló una gift card`,
          body: `${campaign.benefitLabel ?? campaign.title}. Ábrela en Mis regalos y muestra su código.`,
        };
      case CampaignType.SCAN_CHALLENGE:
        return {
          title: `Nuevo reto: ${campaign.title}`,
          body: `Haz ${campaign.requiredScans} escaneos en ${business} y gana: ${campaign.benefitLabel}.`,
        };
      case CampaignType.ROUTE:
        return {
          title: `Nueva ruta: ${campaign.title}`,
          body: `Visita ${campaign.requiredStamps ?? campaign.participants.length} locales y gana: ${campaign.benefitLabel}.`,
        };
      default:
        return { title: campaign.title, body: text || `Novedades de ${business}` };
    }
  }

  // ------------------------------------------------------------------
  // Utilidades
  // ------------------------------------------------------------------

  private async getManageable(id: string, requester: Requester): Promise<Campaign> {
    const campaign = await this.campaignRepository.findOne({
      where: { id },
      relations: ['participants'],
    });
    if (!campaign) throw new NotFoundException('Campaña no encontrada');
    const allowed = await this.businessAccess.canManage(
      requester.id,
      requester.role,
      campaign.businessId,
    );
    if (!allowed) throw new ForbiddenException('No tienes permiso para gestionar esta campaña');
    return campaign;
  }

  /** Dueño, administrador o aprobador de alguno de los locales participantes. */
  private async assertCanOperate(requester: Requester, campaign: Campaign) {
    for (const participant of campaign.participants ?? []) {
      if (await this.businessAccess.canOperate(requester.id, requester.role, participant.businessId)) {
        return;
      }
    }
    throw new ForbiddenException('No tienes permiso sobre esta campaña');
  }

  private async findOneView(id: string) {
    const campaign = await this.campaignRepository.findOne({
      where: { id },
      relations: ['participants', 'participants.business'],
    });
    if (!campaign) throw new NotFoundException('Campaña no encontrada');
    return this.toView(campaign);
  }

  toView(campaign: Campaign) {
    const phase: CampaignPhase = campaignPhase(campaign);
    return {
      id: campaign.id,
      type: campaign.type,
      title: campaign.title,
      description: campaign.description,
      imageUrl: campaign.imageUrl,
      benefitType: campaign.benefitType,
      benefitValue: campaign.benefitValue,
      benefitLabel: campaign.benefitLabel,
      requiredStamps: campaign.requiredStamps,
      requiredScans: campaign.requiredScans,
      audience: campaign.audience ?? 'all',
      startsAt: campaign.startsAt,
      endsAt: campaign.endsAt,
      cancelledAt: campaign.cancelledAt,
      phase,
      businesses: (campaign.participants ?? []).map((p) => ({
        id: p.businessId,
        name: p.business?.name ?? null,
        logoUrl: p.business?.logoUrl ?? null,
      })),
    };
  }

  private claimView(claim: CampaignClaim) {
    return {
      id: claim.id,
      campaignId: claim.campaignId,
      code: claim.code,
      status: claim.status,
      source: claim.source,
      createdAt: claim.createdAt,
      redeemedAt: claim.redeemedAt,
    };
  }

  private async safely(task: () => Promise<unknown>) {
    try {
      await task();
    } catch (error) {
      this.logger.warn(`Notificación de campaña no enviada: ${error.message}`);
    }
  }
}
