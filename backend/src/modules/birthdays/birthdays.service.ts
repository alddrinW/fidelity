import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, Repository } from 'typeorm';
import { BirthdayNotice } from '../../database/entities/birthday-notice.entity';
import { Business } from '../../database/entities/business.entity';
import { CampaignType } from '../../database/entities/campaign.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { BusinessAccessService } from '../businesses/business-access.service';
import { CampaignsService } from '../campaigns/campaigns.service';
import { CreateCampaignDto } from '../campaigns/dto/campaigns.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { SettingsService } from '../settings/settings.service';
import { GiftBirthdayDto } from './dto/birthdays.dto';
import { birthdayOffset, celebrationDate, ecuadorInstant, ecuadorNow, isLeapYear } from './birthday.utils';

type Requester = { id: string; role: UserRole };

/** Cuántos clientes se revisan como máximo en cada pasada o lista. */
const CARD_LIMIT = 5000;

/** Primer nombre para saludar ("Ana María Pérez" → "Ana"). */
function firstName(profile: Pick<Profile, 'fullName' | 'email'>): string {
  const name = profile.fullName?.trim();
  return name ? name.split(/\s+/)[0] : profile.email.split('@')[0];
}

function displayName(profile: Pick<Profile, 'fullName' | 'email'>): string {
  return profile.fullName?.trim() || profile.email.split('@')[0];
}

@Injectable()
export class BirthdaysService {
  private readonly logger = new Logger(BirthdaysService.name);

  constructor(
    @InjectRepository(Profile)
    private readonly profileRepository: Repository<Profile>,
    @InjectRepository(LoyaltyCard)
    private readonly cardRepository: Repository<LoyaltyCard>,
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(BirthdayNotice)
    private readonly noticeRepository: Repository<BirthdayNotice>,
    private readonly notificationsService: NotificationsService,
    private readonly campaignsService: CampaignsService,
    private readonly businessAccess: BusinessAccessService,
    private readonly settings: SettingsService,
  ) {}

  // ------------------------------------------------------------------
  // Aviso diario al dueño
  // ------------------------------------------------------------------

  /**
   * Avisa a cada dueño de los clientes suyos que cumplen años hoy (hora de
   * Ecuador), una sola vez por cliente y año, a partir de la hora que fija el
   * administrador. Si el servidor estuvo apagado, el aviso sale al volver a
   * arrancar ese mismo día. Devuelve cuántos avisos salieron.
   */
  async notifyDue(now: Date = new Date()): Promise<number> {
    const today = ecuadorNow(now);
    if (today.hour < (await this.settings.get(SETTING_KEYS.birthdayNoticeHour))) return 0;

    const dates: { month: number; day: number }[] = [{ month: today.month, day: today.day }];
    // Quien nació un 29 de febrero lo celebra el 28 en los años no bisiestos.
    if (today.month === 2 && today.day === 28 && !isLeapYear(today.year)) {
      dates.push({ month: 2, day: 29 });
    }

    const query = this.profileRepository
      .createQueryBuilder('p')
      .select(['p.id', 'p.fullName', 'p.email'])
      .where('p.role = :role', { role: UserRole.CLIENT })
      .andWhere('p.birth_date IS NOT NULL');
    query.andWhere(
      '(' +
        dates
          .map(
            (_, i) =>
              `(EXTRACT(MONTH FROM p.birth_date) = :m${i} AND EXTRACT(DAY FROM p.birth_date) = :d${i})`,
          )
          .join(' OR ') +
        ')',
      Object.fromEntries(dates.flatMap((d, i) => [[`m${i}`, d.month], [`d${i}`, d.day]])),
    );
    const celebrating = await query.getMany();
    if (celebrating.length === 0) return 0;

    const cards = await this.cardRepository.find({
      where: { userId: In(celebrating.map((p) => p.id)) },
      relations: ['business'],
      take: CARD_LIMIT,
    });
    const byId = new Map(celebrating.map((p) => [p.id, p]));

    let sent = 0;
    const batch = 25;
    const targets = cards.filter((c) => c.business?.isActive && byId.has(c.userId));
    for (let i = 0; i < targets.length; i += batch) {
      const results = await Promise.allSettled(
        targets.slice(i, i + batch).map(async (card) => {
          if (!(await this.claimNotice(card.businessId, card.userId, today.year, now))) return false;
          const person = byId.get(card.userId)!;
          await this.notificationsService.sendToBusinessOwner(
            card.businessId,
            `Hoy cumple años ${displayName(person)}`,
            `${displayName(person)} es cliente de ${card.business.name}. Regálale una gift card para celebrarlo.`,
            {
              type: 'birthday',
              route: '/birthdays',
              business_id: card.businessId,
              user_id: card.userId,
            },
          );
          return true;
        }),
      );
      for (const r of results) {
        if (r.status === 'fulfilled' && r.value) sent++;
        else if (r.status === 'rejected') this.logger.warn(`Aviso de cumpleaños fallido: ${r.reason?.message}`);
      }
    }
    return sent;
  }

  /** Apunta que ya se avisó; false si ya estaba apuntado (otra pasada u otro servidor). */
  private async claimNotice(businessId: string, userId: string, year: number, now: Date): Promise<boolean> {
    const result = await this.noticeRepository
      .createQueryBuilder()
      .insert()
      .into(BirthdayNotice)
      .values({ businessId, userId, year, notifiedAt: now })
      .orIgnore()
      .execute();
    return Array.isArray(result.raw) ? result.raw.length > 0 : !!result.identifiers?.length;
  }

  // ------------------------------------------------------------------
  // Lista del dueño
  // ------------------------------------------------------------------

  /**
   * Los cumpleaños de los clientes del dueño: los de hoy y los próximos
   * (según el plazo que fija el administrador). Nunca se muestra el año de
   * nacimiento ni la edad.
   */
  async upcoming(requester: Requester, businessId?: string) {
    const upcomingDays = await this.settings.get(SETTING_KEYS.birthdayUpcomingDays);
    const today = ecuadorNow();

    let businesses: Business[];
    if (businessId) {
      if (!(await this.businessAccess.canManage(requester.id, requester.role, businessId))) {
        throw new ForbiddenException('No tienes permiso sobre este negocio');
      }
      const business = await this.businessRepository.findOne({ where: { id: businessId } });
      businesses = business ? [business] : [];
    } else if (requester.role === UserRole.ADMIN) {
      businesses = [];
    } else {
      businesses = await this.businessRepository.find({ where: { ownerId: requester.id, isActive: true } });
    }
    if (businesses.length === 0) return { upcomingDays, items: [] };

    const cards = await this.cardRepository.find({
      where: { businessId: In(businesses.map((b) => b.id)) },
      relations: ['user'],
      take: CARD_LIMIT,
    });
    const names = new Map(businesses.map((b) => [b.id, b.name]));

    const rows: {
      card: LoyaltyCard;
      days: number;
      year: number;
    }[] = [];
    for (const card of cards) {
      const birthDate = card.user?.birthDate;
      if (!birthDate) continue;
      const { days, year } = birthdayOffset(birthDate, today);
      if (days < 0 || days > upcomingDays) continue;
      rows.push({ card, days, year });
    }
    if (rows.length === 0) return { upcomingDays, items: [] };

    const notices = await this.noticeRepository.find({
      where: {
        businessId: In([...new Set(rows.map((r) => r.card.businessId))]),
        userId: In([...new Set(rows.map((r) => r.card.userId))]),
      },
    });
    const gifted = new Map(
      notices.filter((n) => n.giftedAt).map((n) => [`${n.businessId}|${n.userId}|${n.year}`, n.giftedAt!]),
    );

    // Del más cercano al más lejano.
    rows.sort((a, b) => a.days - b.days);

    return {
      upcomingDays,
      items: rows.map(({ card, days, year }) => {
        const birthDate = card.user.birthDate!;
        const [, month, day] = birthDate.split('-').map(Number);
        const giftedAt = gifted.get(`${card.businessId}|${card.userId}|${year}`) ?? null;
        return {
          userId: card.userId,
          name: displayName(card.user),
          email: card.user.email,
          avatarUrl: card.user.avatarUrl ?? null,
          businessId: card.businessId,
          businessName: names.get(card.businessId) ?? null,
          month,
          day,
          daysUntil: days,
          isToday: days === 0,
          gifted: !!giftedAt,
          giftedAt,
        };
      }),
    };
  }

  // ------------------------------------------------------------------
  // Regalo
  // ------------------------------------------------------------------

  /**
   * El dueño le regala una gift card a un cliente por su cumpleaños, con la
   * plantilla de cumpleaños: el diseño y el texto ya vienen puestos y el dueño
   * solo elige el premio, a quién y las horas. La fecha no se elige: **vale
   * solo el día del cumpleaños** (hora de Ecuador), entre `startTime` (por
   * defecto la hora del aviso) y `endTime` (por defecto, todo el día). Si el
   * cumpleaños es otro día, el cliente la recibe ese día a la hora de inicio.
   * Es una gift card normal dirigida solo a esa persona (con su cheque, su
   * código y su aviso). Solo se puede una por cliente, local y año.
   */
  async gift(requester: Requester, dto: GiftBirthdayDto) {
    if (!(await this.businessAccess.canManage(requester.id, requester.role, dto.businessId))) {
      throw new ForbiddenException('No tienes permiso sobre este negocio');
    }
    const business = await this.businessRepository.findOne({ where: { id: dto.businessId } });
    if (!business) throw new NotFoundException('Negocio no encontrado');
    if (!business.isActive) {
      throw new BadRequestException('Tu negocio debe estar activo para regalar gift cards');
    }

    const card = await this.cardRepository.findOne({
      where: { businessId: dto.businessId, userId: dto.userId },
      relations: ['user'],
    });
    if (!card?.user) {
      throw new BadRequestException('Ese cliente no tiene tarjeta en tu negocio');
    }
    if (!card.user.birthDate) {
      throw new BadRequestException('Este cliente no compartió su fecha de cumpleaños');
    }

    const [upcomingDays, noticeHour] = await Promise.all([
      this.settings.get(SETTING_KEYS.birthdayUpcomingDays),
      this.settings.get(SETTING_KEYS.birthdayNoticeHour),
    ]);
    const today = ecuadorNow();
    const { days, year } = birthdayOffset(card.user.birthDate, today);
    if (days < 0) {
      throw new BadRequestException('Su cumpleaños ya pasó: la gift card de cumpleaños vale solo ese día');
    }
    if (days > upcomingDays) {
      throw new BadRequestException(`Todavía falta mucho: puedes regalar hasta ${upcomingDays} días antes`);
    }

    // Las horas dentro del día del cumpleaños (hora de Ecuador).
    const startTime = dto.startTime ?? `${String(noticeHour).padStart(2, '0')}:00`;
    const endTime = dto.endTime ?? '23:59';
    const day = celebrationDate(card.user.birthDate, year);
    const startsAt = ecuadorInstant(day, startTime);
    // "Hasta las 23:59" es hasta el final del día.
    const endsAt = new Date(ecuadorInstant(day, endTime).getTime() + (endTime === '23:59' ? 59_000 : 0));
    if (endsAt <= startsAt) {
      throw new BadRequestException('La hora de fin debe ser después de la hora de inicio');
    }
    const now = new Date();
    if (endsAt <= now) {
      throw new BadRequestException('Esa hora ya pasó: elige una hora de fin más tarde');
    }

    // Se aparta el regalo antes de crearlo: dos toques seguidos no lo duplican.
    await this.noticeRepository
      .createQueryBuilder()
      .insert()
      .into(BirthdayNotice)
      .values({ businessId: dto.businessId, userId: dto.userId, year })
      .orIgnore()
      .execute();
    const claimed = await this.noticeRepository.update(
      { businessId: dto.businessId, userId: dto.userId, year, giftedAt: IsNull() },
      { giftedAt: now },
    );
    if (!claimed.affected) {
      throw new ConflictException('Ya le regalaste una gift card por este cumpleaños');
    }

    try {
      const campaign = await this.campaignsService.create(
        requester,
        {
          type: CampaignType.GIFT_CARD,
          // El texto de la plantilla: no se edita.
          title: `Feliz cumpleaños, ${firstName(card.user)}`,
          description: `Un regalo de ${business.name} por tu cumpleaños. Vale solo ese día.`,
          businessIds: [business.id],
          audience: 'selected',
          recipientIds: [dto.userId],
          benefitType: dto.benefitType,
          benefitValue: dto.benefitValue,
          benefitLabel: dto.benefitLabel,
          startsAt: startsAt.toISOString(),
          endsAt: endsAt.toISOString(),
        } as unknown as CreateCampaignDto,
        { template: 'birthday' },
      );

      const campaignId = (campaign as { id: string }).id;
      await this.noticeRepository.update(
        { businessId: dto.businessId, userId: dto.userId, year },
        { giftCampaignId: campaignId },
      );
      return {
        campaignId,
        startsAt: startsAt > now ? startsAt : now,
        endsAt,
      };
    } catch (error) {
      // No se pudo crear: se libera el regalo para que pueda intentarlo de nuevo.
      await this.noticeRepository.update(
        { businessId: dto.businessId, userId: dto.userId, year },
        { giftedAt: null },
      );
      throw error;
    }
  }
}
