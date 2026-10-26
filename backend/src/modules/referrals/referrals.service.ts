import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { randomBytes } from 'crypto';
import { IsNull, Not, Repository } from 'typeorm';
import { Business } from '../../database/entities/business.entity';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { Referral, ReferralUse } from '../../database/entities/referral.entity';
import { Scan, ScanStatus } from '../../database/entities/scan.entity';
import { LoyaltyCardsService } from '../loyalty-cards/loyalty-cards.service';
import { NotificationsService } from '../notifications/notifications.service';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { SettingsService } from '../settings/settings.service';

// Sin 0/O/1/I para que el código sea fácil de dictar.
const CODE_ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
const CODE_PREFIX = 'AMG-';

/** Un código nuevo: `AMG-` y 6 caracteres. */
export function newReferralCode(): string {
  const bytes = randomBytes(6);
  let code = '';
  for (let i = 0; i < 6; i++) code += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
  return CODE_PREFIX + code;
}

/** Acepta el código con o sin guion, en minúsculas y con espacios. */
export function normalizeReferralCode(raw: unknown): string {
  const text = typeof raw === 'string' ? raw.toUpperCase().replace(/\s+/g, '') : '';
  if (/^AMG[2-9A-HJ-NP-Z]{6}$/.test(text)) return `${CODE_PREFIX}${text.slice(3)}`;
  return text;
}

const points = (n: number) => `${n} ${n === 1 ? 'punto' : 'puntos'}`;

const displayName = (p?: Pick<Profile, 'fullName' | 'email'> | null, fallback = 'un amigo') =>
  p?.fullName?.trim() || p?.email?.split('@')[0] || fallback;

/**
 * Invitar amigos **a la app**. Cada cliente tiene un código (y un enlace) para
 * invitar a Fidelity. El amigo lo usa al registrarse. Quien invita gana
 * "puntos de invitación" **cada vez que se unen los amigos que se piden** (3 por
 * defecto); el amigo, si el administrador lo fija, gana los suyos con su primer
 * escaneo aprobado. Cada uno elige después **en qué local usarlos**, entre los
 * que el administrador marcó como participantes. El administrador decide cuándo
 * cuenta un amigo: al registrarse, o solo con su primer escaneo aprobado (más
 * difícil de falsificar con cuentas falsas).
 */
@Injectable()
export class ReferralsService {
  private readonly logger = new Logger(ReferralsService.name);

  constructor(
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(Profile)
    private readonly profileRepository: Repository<Profile>,
    @InjectRepository(Referral)
    private readonly referralRepository: Repository<Referral>,
    @InjectRepository(ReferralUse)
    private readonly useRepository: Repository<ReferralUse>,
    @InjectRepository(Scan)
    private readonly scanRepository: Repository<Scan>,
    private readonly loyaltyCards: LoyaltyCardsService,
    private readonly notifications: NotificationsService,
    private readonly settings: SettingsService,
    private readonly config: ConfigService,
  ) {}

  /** Lo que fijó el administrador. Con 0 y 0, invitar amigos queda apagado. */
  async rules() {
    const [referrerPoints, friendPoints, maxFriends, friendsRequired, trigger] = await Promise.all([
      this.settings.get(SETTING_KEYS.referralReferrerPoints),
      this.settings.get(SETTING_KEYS.referralFriendPoints),
      this.settings.get(SETTING_KEYS.referralMaxFriends),
      this.settings.get(SETTING_KEYS.referralFriendsRequired),
      this.settings.get(SETTING_KEYS.referralTrigger),
    ]);
    return {
      referrerPoints,
      friendPoints,
      maxFriends,
      /** Cuántos amigos deben unirse para que quien invita gane sus puntos. */
      friendsRequired,
      /** Cuándo cuenta un amigo: al registrarse o con su primer escaneo aprobado. */
      trigger: trigger === 1 ? ('first_scan' as const) : ('registration' as const),
      enabled: referrerPoints > 0 || friendPoints > 0,
    };
  }

  /** El enlace de invitación (una página del backend); null si no hay dirección pública. */
  inviteLink(code: string): string | null {
    const base = this.config.get<string>('referrals.publicApiUrl') ?? '';
    if (!base) return null;
    const prefix = this.config.get<string>('apiPrefix') ?? 'api/v1';
    return `${base}/${prefix}/invite/${encodeURIComponent(code)}`;
  }

  // ------------------------------------------------------------------
  // Lo que ve el cliente
  // ------------------------------------------------------------------

  /**
   * Su código y su enlace para invitar (se crea el código la primera vez), sus
   * puntos de invitación sin usar, cuántos amigos ya vinieron y, si él llegó
   * invitado, de parte de quién.
   */
  async me(userId: string) {
    const user = await this.profileRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('Usuario no encontrado');

    const rules = await this.rules();
    const code = rules.enabled ? await this.ensureCode(user) : user.referralCode;

    const [invited, rewarded, counted, cameWith, eligible] = await Promise.all([
      this.referralRepository.count({ where: { referrerId: userId } }),
      this.referralRepository.count({ where: { referrerId: userId, status: 'rewarded' } }),
      this.referralRepository.count({ where: { referrerId: userId, countedAt: Not(IsNull()) } }),
      this.referralRepository.findOne({ where: { refereeId: userId }, relations: ['referrer'] }),
      this.businessRepository.count({ where: { isActive: true, referralEnabled: true } }),
    ]);

    return {
      enabled: rules.enabled,
      code: rules.enabled ? code : null,
      link: rules.enabled && code ? this.inviteLink(code) : null,
      referrerPoints: rules.referrerPoints,
      friendPoints: rules.friendPoints,
      maxFriends: rules.maxFriends,
      friendsRequired: rules.friendsRequired,
      trigger: rules.trigger,
      invited,
      rewarded,
      // Amigos que ya cuentan para su meta y cuántos grupos completos le han pagado.
      counted,
      groupsPaid: user.referralGroupsPaid ?? 0,
      // Puntos de invitación ganados y todavía sin usar.
      balance: user.referralBalance ?? 0,
      eligibleLocals: eligible,
      // Si él llegó invitado: de parte de quién y si ya cobró su punto.
      referredBy: cameWith
        ? {
            name: cameWith.referrer?.fullName?.trim() || cameWith.referrer?.email?.split('@')[0] || null,
            status: cameWith.status,
            points: cameWith.status === 'rewarded' ? cameWith.friendPoints : rules.friendPoints,
          }
        : null,
    };
  }

  private async ensureCode(user: Profile): Promise<string> {
    if (user.referralCode) return user.referralCode;
    for (let attempt = 0; attempt < 5; attempt++) {
      try {
        await this.profileRepository.update(
          { id: user.id, referralCode: IsNull() },
          { referralCode: newReferralCode() },
        );
        const saved = await this.profileRepository.findOne({ where: { id: user.id } });
        if (saved?.referralCode) return saved.referralCode;
      } catch {
        // El código ya lo tenía otra persona: se prueba con otro.
      }
    }
    throw new ConflictException('No se pudo crear tu código. Inténtalo de nuevo.');
  }

  /** Los locales donde se pueden usar los puntos de invitación (los marcó el administrador). */
  async eligibleLocals(userId: string) {
    const businesses = await this.businessRepository.find({
      where: { isActive: true, referralEnabled: true },
      relations: ['categoryRef'],
      order: { name: 'ASC' },
      take: 200,
    });
    const cards = businesses.length
      ? await this.loyaltyCards.cardsOf(
          userId,
          businesses.map((b) => b.id),
        )
      : [];
    const mine = new Map(cards.map((c) => [c.businessId, c.currentPoints]));

    return businesses.map((b) => ({
      id: b.id,
      name: b.name,
      logoUrl: b.logoUrl ?? null,
      category: b.categoryRef?.name ?? b.category ?? null,
      address: b.address ?? null,
      rewardDescription: b.rewardDescription ?? null,
      pointsRequired: b.pointsRequired || 10,
      // Cuántos puntos lleva el cliente ahí (null si todavía no tiene tarjeta).
      currentPoints: mine.has(b.id) ? mine.get(b.id)! : null,
    }));
  }

  /**
   * Usa [amount] de sus puntos de invitación en el local que elige (uno de los
   * participantes). Se suman a su tarjeta de ese local, que se crea si hace
   * falta, y funcionan como cualquier punto: al completarlos sale el premio.
   */
  async use(userId: string, businessId: string, amount = 1) {
    if (!Number.isInteger(amount) || amount < 1) {
      throw new BadRequestException('Elige cuántos puntos usar (1 o más)');
    }
    const business = await this.businessRepository.findOne({ where: { id: businessId } });
    if (!business) throw new NotFoundException('Local no encontrado');
    if (!business.isActive || !business.referralEnabled) {
      throw new BadRequestException('Ese local no participa en los puntos de invitación');
    }

    // Se descuentan antes de sumarlos: dos toques seguidos no gastan el mismo punto dos veces.
    const spent = await this.profileRepository
      .createQueryBuilder()
      .update(Profile)
      .set({ referralBalance: () => `referral_balance - ${amount}` })
      .where('id = :userId AND referral_balance >= :amount', { userId, amount })
      .execute();
    if (!spent.affected) throw new BadRequestException('No tienes tantos puntos de invitación');

    let granted: { cardId: string; currentPoints: number; newRewards: number };
    try {
      granted = await this.loyaltyCards.grantBonusPoints(userId, businessId, amount);
    } catch (error) {
      // No se pudo sumar: se devuelven los puntos.
      await this.profileRepository.increment({ id: userId }, 'referralBalance', amount);
      throw error;
    }
    await this.useRepository.save(this.useRepository.create({ userId, businessId, points: amount }));

    try {
      await this.notifications.sendToUser(
        userId,
        'Puntos de invitación usados',
        `Sumaste ${points(amount)} en ${business.name}.`,
        {
          type: 'referral',
          route: '/points_approved',
          business_id: businessId,
          loyalty_card_id: granted.cardId,
          business_name: business.name,
        },
      );
      if (granted.newRewards > 0) {
        await this.notifications.sendToUser(
          userId,
          'Premio alcanzado',
          `Has ganado premio en ${business.name}, acercate a retirar.`,
          { route: '/reward', business_id: businessId, loyalty_card_id: granted.cardId, business_name: business.name },
        );
      }
    } catch (error) {
      this.logger.warn(`No se pudo avisar del uso de puntos: ${error.message}`);
    }

    const left = (await this.profileRepository.findOne({ where: { id: userId } }))?.referralBalance ?? 0;
    return {
      businessId,
      businessName: business.name,
      used: amount,
      balance: left,
      currentPoints: granted.currentPoints,
      newRewards: granted.newRewards,
      loyaltyCardId: granted.cardId,
    };
  }

  // ------------------------------------------------------------------
  // Usar un código
  // ------------------------------------------------------------------

  /** Revisa que el código sirva (sin usarlo). Devuelve a quien lo creó. */
  async validateCode(rawCode: string, userId?: string) {
    const rules = await this.rules();
    if (!rules.enabled) throw new BadRequestException('Por ahora no hay invitaciones de amigos activas');

    const code = normalizeReferralCode(rawCode);
    const inviter = code ? await this.profileRepository.findOne({ where: { referralCode: code } }) : null;
    if (!inviter) throw new BadRequestException('Ese código de amigo no existe');
    if (userId && inviter.id === userId) throw new BadRequestException('No puedes usar tu propio código');

    const used = await this.referralRepository.count({ where: { referrerId: inviter.id } });
    if (used >= rules.maxFriends) {
      throw new BadRequestException('Ese código ya alcanzó su límite de invitaciones');
    }
    return { inviter, rules };
  }

  /**
   * El amigo usa el código. Solo sirve para gente nueva en la app (sin
   * escaneos aprobados) y una sola vez en la vida.
   */
  async redeem(userId: string, rawCode: string) {
    const user = await this.profileRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('Usuario no encontrado');
    if (user.role !== UserRole.CLIENT) {
      throw new ForbiddenException('Solo los clientes pueden usar un código de amigo');
    }

    const { inviter, rules } = await this.validateCode(rawCode, userId);

    const already = await this.referralRepository.findOne({ where: { refereeId: userId } });
    if (already) throw new ConflictException('Ya usaste un código de amigo');

    const alreadyUsing = await this.scanRepository.count({ where: { userId, status: ScanStatus.APPROVED } });
    if (alreadyUsing > 0) {
      throw new BadRequestException('Ya usas Fidelity: el código es para quienes llegan por primera vez');
    }

    const referral = await this.referralRepository.save(
      this.referralRepository.create({ referrerId: inviter.id, refereeId: userId, status: 'pending' }),
    );

    if (rules.trigger === 'registration') {
      // El amigo ya cuenta: se registró con el código.
      await this.countFriend(referral, user, 'registration');
    } else {
      try {
        await this.notifications.sendToUser(
          inviter.id,
          `${displayName(user, 'Un amigo')} se unió con tu código`,
          'Cuando haga su primer escaneo, contará para tu punto.',
          { type: 'referral', route: '/referral' },
        );
      } catch (error) {
        this.logger.warn(`No se pudo avisar al que invitó: ${error.message}`);
      }
    }

    return {
      friendPoints: rules.friendPoints,
      referrerName: displayName(inviter, null as any),
    };
  }

  // ------------------------------------------------------------------
  // Contar amigos y primer escaneo
  // ------------------------------------------------------------------

  /**
   * Un amigo cuenta para la meta de quien invita. Cuando se juntan los amigos
   * que pide el administrador (3 por defecto), quien invita gana sus puntos de
   * invitación; se repite con cada grupo completo. Cada amigo cuenta una sola
   * vez y cada grupo se paga una sola vez, aunque lleguen dos a la vez.
   */
  private async countFriend(
    referral: Referral,
    friend: Pick<Profile, 'fullName' | 'email'>,
    cause: 'registration' | 'first_scan',
  ) {
    // Se aparta antes de contar: dos avisos seguidos no cuentan dos veces al mismo amigo.
    const marked = await this.referralRepository.update(
      { id: referral.id, countedAt: IsNull() },
      { countedAt: new Date() },
    );
    if (!marked.affected) return;

    const [rules, referrer, counted] = await Promise.all([
      this.rules(),
      this.profileRepository.findOne({ where: { id: referral.referrerId } }),
      this.referralRepository.count({ where: { referrerId: referral.referrerId, countedAt: Not(IsNull()) } }),
    ]);
    if (!referrer) return;

    const required = Math.max(1, rules.friendsRequired);
    const paidBefore = referrer.referralGroupsPaid ?? 0;
    const due = Math.floor(counted / required) - paidBefore;

    if (due > 0 && rules.referrerPoints > 0) {
      // Compara y cambia en un solo paso: si otro proceso ya pagó ese grupo, no se repite.
      const claimed = await this.profileRepository.update(
        { id: referrer.id, referralGroupsPaid: paidBefore },
        { referralGroupsPaid: paidBefore + due },
      );
      if (!claimed.affected) return;
      const total = rules.referrerPoints * due;
      await this.credit(referrer.id, total, {
        title: `¡Se unieron ${required} amigos!`,
        body: `Ganaste ${points(total)} de invitación. Elige en qué local usarlos.`,
      });
      this.logger.log(`Invitación pagada: ${referrer.id} (${counted} amigos)`);
      return;
    }

    // Todavía no completa el grupo: se le cuenta cómo va.
    const inGroup = counted % required || required;
    const name = displayName(friend, 'Un amigo');
    try {
      await this.notifications.sendToUser(
        referrer.id,
        cause === 'registration' ? `${name} se unió con tu código` : `${name} ya hizo su primer escaneo`,
        rules.referrerPoints > 0
          ? `Van ${inGroup} de ${required} amigos. Cuando se unan ${required}, ganas ${points(rules.referrerPoints)}.`
          : `Van ${inGroup} de ${required} amigos.`,
        { type: 'referral', route: '/referral' },
      );
    } catch (error) {
      this.logger.warn(`No se pudo avisar al que invitó: ${error.message}`);
    }
  }

  /**
   * Se llama cuando un local aprueba un escaneo. Si esa persona llegó invitada y
   * es su primer escaneo real (de un QR): recibe sus puntos (si el administrador
   * los fijó) y, si así se configuró, cuenta para la meta de quien la invitó.
   * Devuelve true si era su primer escaneo.
   */
  async onScanApproved(userId: string): Promise<boolean> {
    const referral = await this.referralRepository.findOne({ where: { refereeId: userId, status: 'pending' } });
    if (!referral) return false;

    const realScans = await this.scanRepository
      .createQueryBuilder('scan')
      .where('scan.userId = :userId', { userId })
      .andWhere('scan.status = :status', { status: ScanStatus.APPROVED })
      .andWhere('scan.qrCodeId IS NOT NULL')
      .getCount();
    if (realScans < 1) return false;

    const rules = await this.rules();
    // Se aparta antes de pagar: dos aprobaciones seguidas no pagan dos veces.
    const claimed = await this.referralRepository.update(
      { id: referral.id, status: 'pending' },
      {
        status: 'rewarded',
        rewardedAt: new Date(),
        friendPoints: rules.friendPoints,
      },
    );
    if (!claimed.affected) return false;

    const [referrer, friend] = await Promise.all([
      this.profileRepository.findOne({ where: { id: referral.referrerId } }),
      this.profileRepository.findOne({ where: { id: userId } }),
    ]);

    if (rules.friendPoints > 0) {
      await this.credit(userId, rules.friendPoints, {
        title: `¡Ganaste ${points(rules.friendPoints)} de invitación!`,
        body: `Por tu primer escaneo, invitado por ${displayName(referrer)}. Elige en qué local usarlos.`,
      });
    }
    if (rules.trigger === 'first_scan' && friend) {
      await this.countFriend(referral, friend, 'first_scan');
    }
    return true;
  }

  /** Suma puntos al saldo de invitación y avisa. */
  private async credit(userId: string, amount: number, notice: { title: string; body: string }) {
    await this.profileRepository.increment({ id: userId }, 'referralBalance', amount);
    try {
      await this.notifications.sendToUser(userId, notice.title, notice.body, { type: 'referral', route: '/referral' });
    } catch (error) {
      this.logger.warn(`No se pudo avisar de los puntos de invitación: ${error.message}`);
    }
  }

  // ------------------------------------------------------------------
  // Administrador: qué locales participan
  // ------------------------------------------------------------------

  /** Los locales activos con su marca de participación (para que el administrador los elija). */
  async adminBusinesses(search?: string) {
    const term = search?.trim().toLowerCase();
    const businesses = await this.businessRepository.find({
      where: { isActive: true },
      relations: ['categoryRef'],
      order: { name: 'ASC' },
      take: 1000,
    });
    return businesses
      .filter((b) => !term || b.name.toLowerCase().includes(term))
      .map((b) => ({
        id: b.id,
        name: b.name,
        logoUrl: b.logoUrl ?? null,
        category: b.categoryRef?.name ?? b.category ?? null,
        address: b.address ?? null,
        enabled: !!b.referralEnabled,
      }));
  }

  /** El administrador marca (o desmarca) un local como participante. */
  async setBusinessEnabled(businessId: string, enabled: boolean) {
    const result = await this.businessRepository.update({ id: businessId }, { referralEnabled: enabled });
    if (!result.affected) throw new NotFoundException('Local no encontrado');
    return { id: businessId, enabled };
  }

  /** Marca o desmarca varios locales de una vez. */
  async setManyEnabled(ids: string[], enabled: boolean) {
    if (ids.length === 0) return { updated: 0 };
    const result = await this.businessRepository
      .createQueryBuilder()
      .update(Business)
      .set({ referralEnabled: enabled })
      .where('id IN (:...ids) AND is_active = true', { ids })
      .execute();
    return { updated: result.affected ?? 0 };
  }
}
