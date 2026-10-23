import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, LessThanOrEqual, MoreThan, Repository } from 'typeorm';
import { GameAccess } from '../../database/entities/game-access.entity';
import { GameInvite, GameResult } from '../../database/entities/game-invite.entity';
import {
  Campaign,
  CampaignBenefit,
  CampaignType,
} from '../../database/entities/campaign.entity';
import { CampaignBusiness } from '../../database/entities/campaign-business.entity';
import {
  CampaignClaim,
  ClaimSource,
  ClaimStatus,
} from '../../database/entities/campaign-claim.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { UserRole } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { BusinessAccessService } from '../businesses/business-access.service';
import { randomCode } from '../campaigns/campaigns.service';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { SettingsService } from '../settings/settings.service';
import {
  ApproveGamesDto,
  FinishFlappyDto,
  RequestGamesDto,
  SendGameDto,
} from './dto/games.dto';
import {
  FLAPPY_MAX_MS,
  FLAPPY_TARGET,
  GAME_NAMES,
  GameKey,
  emptyBoard,
  flappyIsWin,
  guessLetter,
  hangmanStatus,
  hangmanView,
  newHangman,
  normalizeLetter,
  playTttMove,
} from './games.logic';

type Requester = { id: string; role: UserRole };

/** Cuánto dura un reto si el dueño no pone hora de fin. */
export const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/** Lo máximo que puede durar el horario de un reto. */
export const MAX_INVITE_WINDOW_MS = 90 * 24 * 60 * 60 * 1000;

/** Una hora de inicio un poco en el pasado (reloj del teléfono) se toma como "ahora". */
const START_TOLERANCE_MS = 5 * 60 * 1000;

/** Intentos que tiene cada cliente para ganar un juego. */
export const MAX_GAME_ATTEMPTS = 3;

/** Los avisos pendientes que se mandan en cada pasada. */
const NOTIFY_BATCH_LIMIT = 500;

const DAY_MS = 24 * 60 * 60 * 1000;

/** Los límites que fija el administrador (ver `SettingsService`). */
export interface GameLimits {
  maxAttempts: number;
  defaultDurationMs: number;
  maxDurationMs: number;
  maxAudience: number;
}

/**
 * El horario de un reto: desde cuándo y hasta cuándo se puede jugar. Sin
 * inicio empieza ya; sin fin dura lo que fije el administrador (7 días por defecto).
 */
export function resolveGameWindow(
  startsAt: string | undefined,
  endsAt: string | undefined,
  now: Date = new Date(),
  limits: Pick<GameLimits, 'defaultDurationMs' | 'maxDurationMs'> = {
    defaultDurationMs: INVITE_TTL_MS,
    maxDurationMs: MAX_INVITE_WINDOW_MS,
  },
): { startsAt: Date; endsAt: Date } {
  let start = startsAt ? new Date(startsAt) : now;
  if (Number.isNaN(start.getTime())) throw new BadRequestException('La hora de inicio no es válida');
  if (start.getTime() < now.getTime() - START_TOLERANCE_MS) {
    throw new BadRequestException('La hora de inicio ya pasó');
  }
  if (start.getTime() < now.getTime()) start = now;

  const end = endsAt ? new Date(endsAt) : new Date(start.getTime() + limits.defaultDurationMs);
  if (Number.isNaN(end.getTime())) throw new BadRequestException('La hora de fin no es válida');
  if (end.getTime() <= start.getTime()) {
    throw new BadRequestException('El juego debe terminar después de la hora de inicio');
  }
  if (end.getTime() - start.getTime() > limits.maxDurationMs) {
    throw new BadRequestException(
      `El juego no puede durar más de ${Math.round(limits.maxDurationMs / DAY_MS)} días`,
    );
  }
  return { startsAt: start, endsAt: end };
}

/** "21/10 14:30" en hora de Ecuador, para los avisos. */
function formatWhen(date: Date): string {
  return date.toLocaleString('es-EC', {
    timeZone: 'America/Guayaquil',
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
}

/** Máximo de clientes a los que se manda un juego de una vez. */
export const MAX_GAME_AUDIENCE = 1000;

@Injectable()
export class GamesService {
  private readonly logger = new Logger(GamesService.name);

  constructor(
    @InjectRepository(GameAccess)
    private readonly accessRepository: Repository<GameAccess>,
    @InjectRepository(GameInvite)
    private readonly inviteRepository: Repository<GameInvite>,
    @InjectRepository(Campaign)
    private readonly campaignRepository: Repository<Campaign>,
    @InjectRepository(CampaignBusiness)
    private readonly participantRepository: Repository<CampaignBusiness>,
    @InjectRepository(CampaignClaim)
    private readonly claimRepository: Repository<CampaignClaim>,
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(LoyaltyCard)
    private readonly cardRepository: Repository<LoyaltyCard>,
    private readonly notificationsService: NotificationsService,
    private readonly businessAccess: BusinessAccessService,
    private readonly settings: SettingsService,
  ) {}

  /** Los límites vigentes de los minijuegos (los fija el administrador). */
  private async limits(): Promise<GameLimits> {
    const [maxAttempts, defaultDays, maxDays, maxAudience] = await Promise.all([
      this.settings.get(SETTING_KEYS.gameMaxAttempts),
      this.settings.get(SETTING_KEYS.gameDefaultDays),
      this.settings.get(SETTING_KEYS.gameMaxDays),
      this.settings.get(SETTING_KEYS.gameMaxAudience),
    ]);
    return {
      maxAttempts,
      defaultDurationMs: defaultDays * DAY_MS,
      maxDurationMs: maxDays * DAY_MS,
      maxAudience,
    };
  }

  private maxAttempts(): Promise<number> {
    return this.settings.get(SETTING_KEYS.gameMaxAttempts);
  }

  // ------------------------------------------------------------------
  // Solicitud del dueño y decisión del administrador
  // ------------------------------------------------------------------

  async request(requester: Requester, dto: RequestGamesDto) {
    const business = await this.businessRepository.findOne({ where: { id: dto.businessId } });
    if (!business) throw new NotFoundException('Negocio no encontrado');
    if (!(await this.businessAccess.canManage(requester.id, requester.role, business.id))) {
      throw new ForbiddenException('Solo el dueño del negocio puede pedir los minijuegos');
    }
    if (!business.isActive) {
      throw new BadRequestException('Tu negocio debe estar activo para pedir los minijuegos');
    }

    const existing = await this.accessRepository.findOne({ where: { businessId: business.id } });
    if (existing?.status === 'approved') {
      throw new BadRequestException('Tu negocio ya tiene los minijuegos');
    }
    if (existing?.status === 'pending') {
      throw new BadRequestException('Ya hay una solicitud en revisión');
    }

    const access =
      existing ??
      this.accessRepository.create({ businessId: business.id, ownerId: business.ownerId });
    access.status = 'pending';
    access.note = dto.note?.trim() || null;
    access.adminNote = null;
    access.resolvedAt = null;
    access.resolvedById = null;
    const saved = await this.accessRepository.save(access);

    await this.safely(() =>
      this.notificationsService.broadcastToAdmins(
        'Solicitud de minijuegos',
        `${business.name} pidió los minijuegos.`,
        '/admin_games',
      ),
    );
    return this.accessView(saved);
  }

  /** Estado de los minijuegos de un negocio, para su dueño. */
  async getAccess(requester: Requester, businessId: string) {
    if (!(await this.businessAccess.canManage(requester.id, requester.role, businessId))) {
      throw new ForbiddenException('No tienes permiso sobre este negocio');
    }
    const access = await this.accessRepository.findOne({ where: { businessId } });
    return access ? this.accessView(access) : { status: 'none', games: [], prize: null };
  }

  /** Solicitudes para el administrador (con negocio y dueño). */
  async listRequests(status?: string) {
    const rows = await this.accessRepository.find({
      where: status ? { status: status as any } : {},
      relations: ['business', 'owner'],
      order: { requestedAt: 'DESC' },
      take: 200,
    });
    return rows.map((a) => ({
      ...this.accessView(a),
      business: a.business && { id: a.business.id, name: a.business.name, logoUrl: a.business.logoUrl },
      owner: a.owner && { fullName: a.owner.fullName, email: a.owner.email, phone: a.owner.phone },
    }));
  }

  /**
   * El administrador asigna los juegos y fija el premio (también sirve para
   * cambiarlos después). El premio se entrega con una gift card oculta por juego.
   */
  async approve(adminId: string, id: string, dto: ApproveGamesDto) {
    const access = await this.accessRepository.findOne({ where: { id }, relations: ['business'] });
    if (!access) throw new NotFoundException('Solicitud no encontrada');

    if (dto.prizeType === 'discount_percent' && !dto.prizeValue) {
      throw new BadRequestException('Indica el porcentaje de descuento (1 a 100)');
    }
    if (dto.prizeType === 'mini_prize' && !dto.prizeLabel?.trim()) {
      throw new BadRequestException('Describe el mini premio');
    }

    const games = [...new Set(dto.games)];
    const wasApproved = access.status === 'approved';
    access.status = 'approved';
    access.adminNote = null;
    access.games = games;
    access.prizeType = dto.prizeType;
    access.prizeValue = dto.prizeType === 'discount_percent' ? dto.prizeValue! : null;
    access.prizeLabel = this.prizeLabel(dto);
    access.resolvedAt = new Date();
    access.resolvedById = adminId;

    access.prizeCampaigns = await this.syncPrizeCampaigns(access, games);
    const saved = await this.accessRepository.save(access);

    await this.safely(() =>
      this.notificationsService.sendToBusinessOwner(
        access.businessId,
        wasApproved ? 'Tus minijuegos cambiaron' : '¡Minijuegos activados!',
        `Ya puedes mandarle a tus clientes: ${games.map((g) => GAME_NAMES[g as GameKey]).join(', ')}.`,
        { type: 'games_approved', route: '/business_dashboard/games' },
      ),
    );
    return this.accessView(saved);
  }

  async reject(adminId: string, id: string, reason: string) {
    const access = await this.accessRepository.findOne({ where: { id } });
    if (!access) throw new NotFoundException('Solicitud no encontrada');

    // Si ya estaba aprobada, quitarla cancela los premios pendientes de juegos.
    const prizeIds = Object.values(access.prizeCampaigns ?? {});
    if (prizeIds.length > 0) {
      await this.campaignRepository.update({ id: In(prizeIds) }, { cancelledAt: new Date() });
    }

    access.status = 'rejected';
    access.adminNote = reason.trim();
    access.games = null;
    access.prizeType = null;
    access.prizeValue = null;
    access.prizeLabel = null;
    access.prizeCampaigns = null;
    access.resolvedAt = new Date();
    access.resolvedById = adminId;
    const saved = await this.accessRepository.save(access);

    await this.safely(() =>
      this.notificationsService.sendToBusinessOwner(
        access.businessId,
        'Solicitud de minijuegos',
        `No pudimos activar los minijuegos: ${saved.adminNote}`,
        { type: 'games_rejected', route: '/business_dashboard/games' },
      ),
    );
    return this.accessView(saved);
  }

  private prizeLabel(dto: ApproveGamesDto): string {
    const label = dto.prizeLabel?.trim();
    return dto.prizeType === 'discount_percent'
      ? label || `${dto.prizeValue}% de descuento`
      : label!;
  }

  /** Crea (o actualiza) la gift card oculta que entrega el premio de cada juego. */
  private async syncPrizeCampaigns(
    access: GameAccess,
    games: string[],
  ): Promise<Record<string, string>> {
    const campaigns: Record<string, string> = { ...(access.prizeCampaigns ?? {}) };
    const benefit = {
      benefitType:
        access.prizeType === 'discount_percent'
          ? CampaignBenefit.DISCOUNT_PERCENT
          : CampaignBenefit.MINI_PRIZE,
      benefitValue: access.prizeValue,
      benefitLabel: access.prizeLabel,
    };

    for (const game of games) {
      const existing = campaigns[game];
      if (existing) {
        // Si se había cancelado (juego quitado y vuelto a poner), se reactiva.
        await this.campaignRepository.update({ id: existing }, { ...benefit, cancelledAt: null });
        continue;
      }
      const now = new Date();
      const campaign = await this.campaignRepository.save(
        this.campaignRepository.create({
          businessId: access.businessId,
          type: CampaignType.GIFT_CARD,
          title: `Premio: ${GAME_NAMES[game as GameKey]}`,
          description: 'Premio de los minijuegos',
          ...benefit,
          audience: 'selected',
          // Solo entrega el premio a quien gana: no sale en las listas del dueño.
          hidden: true,
          startsAt: now,
          endsAt: null,
          // Ya "avisada": el premio se entrega solo a quien gana, nunca por aviso.
          notifiedAt: now,
        }),
      );
      await this.participantRepository.save(
        this.participantRepository.create({
          campaignId: campaign.id,
          businessId: access.businessId,
        }),
      );
      campaigns[game] = campaign.id;
    }
    return campaigns;
  }

  // ------------------------------------------------------------------
  // El dueño manda un juego
  // ------------------------------------------------------------------

  async sendInvites(requester: Requester, dto: SendGameDto) {
    if (!(await this.businessAccess.canManage(requester.id, requester.role, dto.businessId))) {
      throw new ForbiddenException('No tienes permiso sobre este negocio');
    }
    const [business, access] = await Promise.all([
      this.businessRepository.findOne({ where: { id: dto.businessId } }),
      this.accessRepository.findOne({ where: { businessId: dto.businessId } }),
    ]);
    if (!business) throw new NotFoundException('Negocio no encontrado');
    if (!access || access.status !== 'approved') {
      throw new BadRequestException('Tu negocio todavía no tiene minijuegos activos');
    }
    if (!access.games?.includes(dto.game)) {
      throw new BadRequestException('Ese juego no está asignado a tu negocio');
    }
    if (!business.isActive) {
      throw new BadRequestException('Tu negocio debe estar activo para mandar juegos');
    }
    const now = new Date();
    const limits = await this.limits();
    const window = resolveGameWindow(dto.startsAt, dto.endsAt, now, limits);

    const cards = await this.cardRepository.find({
      where: { businessId: business.id },
      select: ['userId'],
      take: limits.maxAudience * 2,
    });
    const customers = new Set(cards.map((c) => c.userId));

    let userIds: string[];
    if (dto.audience === 'selected') {
      userIds = [...new Set(dto.recipientIds ?? [])];
      if (userIds.length === 0) throw new BadRequestException('Elige al menos un cliente');
      if (userIds.some((id) => !customers.has(id))) {
        throw new BadRequestException('Algunos clientes elegidos no son clientes de este negocio');
      }
    } else {
      userIds = [...customers].slice(0, limits.maxAudience);
      if (userIds.length === 0) {
        throw new BadRequestException('Todavía no tienes clientes a quienes mandarles el juego');
      }
    }

    // Se salta a quien ya tiene este juego pendiente o ya ganó su premio.
    const open = await this.inviteRepository.find({
      where: {
        businessId: business.id,
        game: dto.game,
        userId: In(userIds),
        status: In(['sent', 'playing']),
        expiresAt: MoreThan(now),
      },
      select: ['userId'],
    });
    const prizeCampaignId = access.prizeCampaigns?.[dto.game];
    const winners = prizeCampaignId
      ? await this.claimRepository.find({
          where: { campaignId: prizeCampaignId, userId: In(userIds) },
          select: ['userId'],
        })
      : [];
    const skip = new Set([...open.map((i) => i.userId), ...winners.map((w) => w.userId)]);
    const targets = userIds.filter((id) => !skip.has(id));

    const invites = targets.length
      ? await this.inviteRepository.save(
          targets.map((userId) =>
            this.inviteRepository.create({
              businessId: business.id,
              userId,
              sentById: requester.id,
              game: dto.game,
              status: 'sent',
              startsAt: window.startsAt,
              expiresAt: window.endsAt,
            }),
          ),
        )
      : [];

    // Si empieza ya, el aviso sale ahora; si empieza después, lo manda el
    // programador a la hora de inicio.
    if (invites.length > 0) await this.notifyDue(now);
    return {
      sent: invites.length,
      skipped: userIds.length - invites.length,
      startsAt: window.startsAt,
      endsAt: window.endsAt,
    };
  }

  /**
   * Avisa a los clientes cuyo juego ya empezó y aún no recibieron el aviso.
   * Cada reto se "reclama" antes de avisar, así dos pasadas a la vez no lo
   * mandan dos veces.
   */
  async notifyDue(now: Date = new Date()): Promise<number> {
    const due = await this.inviteRepository.find({
      where: { notifiedAt: IsNull(), startsAt: LessThanOrEqual(now), expiresAt: MoreThan(now) },
      relations: ['business'],
      order: { startsAt: 'ASC' },
      take: NOTIFY_BATCH_LIMIT,
    });
    if (due.length === 0) return 0;
    const maxAttempts = await this.maxAttempts();

    const access = await this.accessRepository.find({
      where: { businessId: In([...new Set(due.map((i) => i.businessId))]) },
    });

    let notified = 0;
    const batch = 25;
    for (let i = 0; i < due.length; i += batch) {
      const results = await Promise.allSettled(
        due.slice(i, i + batch).map(async (invite) => {
          const claimed = await this.inviteRepository.update(
            { id: invite.id, notifiedAt: IsNull() },
            { notifiedAt: now },
          );
          if (!claimed.affected) return false;

          const prize = access.find((a) => a.businessId === invite.businessId)?.prizeLabel;
          const gameName = GAME_NAMES[invite.game as GameKey] ?? invite.game;
          await this.notificationsService.sendToUser(
            invite.userId,
            `${invite.business?.name ?? 'Un local'} te reta a jugar`,
            `Juega ${gameName}${prize ? ` y gana: ${prize}` : ''}. ` +
              `Tienes ${maxAttempts} intentos hasta el ${formatWhen(invite.expiresAt)}.`,
            { type: 'game_invite', route: '/play_game', invite_id: invite.id, game: invite.game },
          );
          return true;
        }),
      );
      notified += results.filter((r) => r.status === 'fulfilled' && r.value).length;
    }
    return notified;
  }

  /** Lo que el dueño mandó: cifras y los últimos envíos. */
  async listSent(requester: Requester, businessId: string) {
    if (!(await this.businessAccess.canManage(requester.id, requester.role, businessId))) {
      throw new ForbiddenException('No tienes permiso sobre este negocio');
    }
    const maxAttempts = await this.maxAttempts();
    const invites = await this.inviteRepository.find({
      where: { businessId },
      relations: ['user'],
      order: { createdAt: 'DESC' },
      take: 200,
    });
    return {
      stats: {
        sent: invites.length,
        played: invites.filter((i) => i.attempts > 0).length,
        won: invites.filter((i) => i.result === 'won').length,
      },
      items: invites.slice(0, 100).map((i) => ({
        id: i.id,
        game: i.game,
        gameName: GAME_NAMES[i.game as GameKey] ?? i.game,
        userName: i.user?.fullName ?? i.user?.email ?? null,
        status: this.statusOf(i),
        result: i.result,
        attempts: i.attempts,
        maxAttempts,
        startsAt: i.startsAt,
        expiresAt: i.expiresAt,
        createdAt: i.createdAt,
      })),
    };
  }

  // ------------------------------------------------------------------
  // El cliente juega
  // ------------------------------------------------------------------

  async myInvites(userId: string) {
    const maxAttempts = await this.maxAttempts();
    const invites = await this.inviteRepository.find({
      where: { userId },
      relations: ['business'],
      order: { createdAt: 'DESC' },
      take: 50,
    });
    if (invites.length === 0) return [];
    const access = await this.accessRepository.find({
      where: { businessId: In([...new Set(invites.map((i) => i.businessId))]) },
    });
    return invites.map((i) => ({
      id: i.id,
      game: i.game,
      gameName: GAME_NAMES[i.game as GameKey] ?? i.game,
      businessId: i.businessId,
      businessName: i.business?.name ?? null,
      businessLogoUrl: i.business?.logoUrl ?? null,
      prizeLabel: access.find((a) => a.businessId === i.businessId)?.prizeLabel ?? null,
      status: this.statusOf(i),
      result: i.result,
      attempts: i.attempts,
      maxAttempts,
      attemptsLeft: this.attemptsLeft(i, maxAttempts),
      startsAt: i.startsAt,
      expiresAt: i.expiresAt,
      createdAt: i.createdAt,
    }));
  }

  async getInvite(userId: string, id: string) {
    return this.playView(await this.ownInvite(userId, id));
  }

  /**
   * Empieza un intento (o retoma el que ya estaba en curso). Cada cliente tiene
   * hasta el máximo de intentos para ganar y solo dentro del horario.
   */
  async start(userId: string, id: string) {
    const invite = await this.ownInvite(userId, id);
    if (invite.status === 'finished') {
      throw new BadRequestException(
        invite.result === 'won' ? 'Ya ganaste este reto' : 'Ya usaste tus intentos de este reto',
      );
    }
    this.assertOpen(invite);

    if (invite.status === 'sent') {
      if (invite.attempts >= (await this.maxAttempts())) {
        throw new BadRequestException('Ya usaste tus intentos de este reto');
      }
      invite.status = 'playing';
      invite.attempts += 1;
      invite.startedAt = new Date();
      invite.state = this.initialState(invite.game as GameKey);
      await this.inviteRepository.save(invite);
    } else if (
      invite.game === 'flappy' &&
      Date.now() - (invite.startedAt?.getTime() ?? 0) > FLAPPY_MAX_MS
    ) {
      // Lo empezó y lo dejó: se da por perdido.
      await this.finish(invite, 'lost', 0);
    }
    return this.playView(invite);
  }

  async guess(userId: string, id: string, rawLetter: string) {
    const invite = await this.playingInvite(userId, id, 'hangman');
    const letter = normalizeLetter(rawLetter);
    if (!letter) throw new BadRequestException('Escribe una letra');

    const state = guessLetter(invite.state as any, letter);
    invite.state = state;
    const status = hangmanStatus(state);
    if (status === 'playing') {
      await this.inviteRepository.save(invite);
    } else {
      await this.finish(invite, status === 'won' ? 'won' : 'lost');
    }
    return this.playView(invite);
  }

  async move(userId: string, id: string, cell: number) {
    const invite = await this.playingInvite(userId, id, 'tictactoe');
    const board = (invite.state as any).board as string[];
    if (board[cell] !== '') throw new BadRequestException('Esa casilla ya está ocupada');

    const result = playTttMove(board as any, cell);
    invite.state = { board: result.board, status: result.status, line: result.line };
    if (result.status === 'playing') {
      await this.inviteRepository.save(invite);
    } else {
      await this.finish(invite, result.status === 'won' ? 'won' : 'lost');
    }
    return this.playView(invite);
  }

  /** Flappy Bird: el reloj lo lleva el servidor (el cliente solo dice su puntaje). */
  async finishFlappy(userId: string, id: string, dto: FinishFlappyDto) {
    const invite = await this.playingInvite(userId, id, 'flappy');
    const elapsed = Date.now() - (invite.startedAt?.getTime() ?? Date.now());
    const won = flappyIsWin(dto.score, elapsed);
    await this.finish(invite, won ? 'won' : 'lost', dto.score);
    return this.playView(invite);
  }

  // ------------------------------------------------------------------
  // Internos
  // ------------------------------------------------------------------

  private initialState(game: GameKey): Record<string, any> {
    switch (game) {
      case 'hangman':
        return { ...newHangman() };
      case 'tictactoe':
        return { board: emptyBoard(), status: 'playing', line: null };
      default:
        return {};
    }
  }

  private async ownInvite(userId: string, id: string): Promise<GameInvite> {
    const invite = await this.inviteRepository.findOne({
      where: { id },
      relations: ['business', 'user'],
    });
    if (!invite || invite.userId !== userId) throw new NotFoundException('Reto no encontrado');
    return invite;
  }

  private async playingInvite(userId: string, id: string, game: GameKey): Promise<GameInvite> {
    const invite = await this.ownInvite(userId, id);
    if (invite.game !== game) throw new BadRequestException('Este reto es de otro juego');
    if (invite.status === 'finished') throw new BadRequestException('Ya jugaste este reto');
    if (invite.status !== 'playing') {
      throw new BadRequestException('Empieza el juego antes de jugar');
    }
    this.assertOpen(invite);
    return invite;
  }

  /** Solo se juega dentro del horario que puso el dueño. */
  private assertOpen(invite: GameInvite, now: Date = new Date()) {
    if (invite.expiresAt.getTime() < now.getTime()) {
      throw new BadRequestException('Este reto venció');
    }
    if (invite.startsAt.getTime() > now.getTime()) {
      throw new BadRequestException(`Este juego empieza el ${formatWhen(invite.startsAt)}`);
    }
  }

  private attemptsLeft(invite: GameInvite, maxAttempts: number): number {
    return invite.status === 'finished' ? 0 : Math.max(0, maxAttempts - invite.attempts);
  }

  /**
   * Cierra un intento. Si ganó, el reto termina y le entrega el premio. Si
   * perdió y le quedan intentos, el reto vuelve a estar listo para otro; si era
   * el último, termina perdido.
   */
  private async finish(invite: GameInvite, result: GameResult, score: number | null = null) {
    invite.score = score;
    if (result === 'lost' && invite.attempts < (await this.maxAttempts())) {
      invite.status = 'sent';
      invite.state = null;
      invite.startedAt = null;
    } else {
      invite.status = 'finished';
      invite.result = result;
      invite.finishedAt = new Date();
      if (result === 'won') await this.awardPrize(invite);
    }
    await this.inviteRepository.save(invite);
  }

  private async awardPrize(invite: GameInvite) {
    const access = await this.accessRepository.findOne({
      where: { businessId: invite.businessId },
    });
    const campaignId = access?.prizeCampaigns?.[invite.game];
    if (!access || !campaignId) return;

    const already = await this.claimRepository.findOne({
      where: { campaignId, userId: invite.userId },
    });
    if (already) return; // ya ganó este premio antes: no se repite

    try {
      const claim = await this.claimRepository.save(
        this.claimRepository.create({
          campaignId,
          userId: invite.userId,
          code: randomCode('GFT'),
          status: ClaimStatus.ACTIVE,
          source: ClaimSource.CLAIM,
        }),
      );
      invite.claimId = claim.id;
    } catch (error) {
      if (error?.code !== '23505') throw error;
      return;
    }

    const gameName = GAME_NAMES[invite.game as GameKey];
    await this.safely(() =>
      this.notificationsService.sendToUser(
        invite.userId,
        '¡Ganaste!',
        `Ganaste ${gameName} y tu premio es: ${access.prizeLabel}. Ábrelo en Mis regalos.`,
        { type: 'game_won', route: '/my_gifts' },
      ),
    );
    await this.safely(() =>
      this.notificationsService.sendToBusinessOwner(
        invite.businessId,
        '¡Un cliente ganó!',
        `${invite.user?.fullName ?? 'Un cliente'} ganó ${gameName}.`,
        { type: 'game_won_owner', route: '/business_dashboard/games' },
      ),
    );
  }

  private statusOf(
    invite: GameInvite,
    now: Date = new Date(),
  ): 'upcoming' | 'sent' | 'playing' | 'finished' | 'expired' {
    if (invite.status === 'finished') return 'finished';
    if (invite.expiresAt.getTime() < now.getTime()) return 'expired';
    if (invite.startsAt.getTime() > now.getTime()) return 'upcoming';
    return invite.status;
  }

  /** La partida como la ve el cliente (sin la palabra del ahorcado). */
  private async playView(invite: GameInvite) {
    const game = invite.game as GameKey;
    const maxAttempts = await this.maxAttempts();
    const access = await this.accessRepository.findOne({
      where: { businessId: invite.businessId },
    });
    let claimCode: string | null = null;
    if (invite.claimId) {
      claimCode = (await this.claimRepository.findOne({ where: { id: invite.claimId } }))?.code ?? null;
    }

    let play: Record<string, unknown> = {};
    if (invite.state) {
      if (game === 'hangman') play = hangmanView(invite.state as any);
      else if (game === 'tictactoe') play = { ...(invite.state as any) };
    }
    if (game === 'flappy') play = { target: FLAPPY_TARGET };

    return {
      id: invite.id,
      game,
      gameName: GAME_NAMES[game],
      businessName: invite.business?.name ?? null,
      prizeLabel: access?.prizeLabel ?? null,
      status: this.statusOf(invite),
      result: invite.result,
      score: invite.score,
      startsAt: invite.startsAt,
      expiresAt: invite.expiresAt,
      attempts: invite.attempts,
      maxAttempts,
      attemptsLeft: this.attemptsLeft(invite, maxAttempts),
      // Perdió el último intento pero todavía le quedan otros.
      lastAttempt: invite.status === 'sent' && invite.attempts > 0 ? 'lost' : null,
      claimCode,
      play,
    };
  }

  accessView(a: GameAccess) {
    return {
      id: a.id,
      businessId: a.businessId,
      status: a.status,
      note: a.note,
      adminNote: a.adminNote,
      games: a.games ?? [],
      prize: a.prizeType
        ? { type: a.prizeType, value: a.prizeValue, label: a.prizeLabel }
        : null,
      requestedAt: a.requestedAt,
      resolvedAt: a.resolvedAt,
    };
  }

  private async safely(task: () => Promise<unknown>) {
    try {
      await task();
    } catch (error) {
      this.logger.warn(`Aviso de minijuegos no enviado: ${error.message}`);
    }
  }
}
