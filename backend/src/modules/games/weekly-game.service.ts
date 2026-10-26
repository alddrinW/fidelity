import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { GameInvite } from '../../database/entities/game-invite.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { LoyaltyCardsService } from '../loyalty-cards/loyalty-cards.service';
import { NotificationsService } from '../notifications/notifications.service';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { SettingsService } from '../settings/settings.service';
import { GAME_NAMES, GameKey } from './games.logic';
import { blockedBusinesses, pickWeeklyGame, weekOf } from './weekly-game.utils';

export type WeeklyState =
  /** Apagado por el administrador. */
  | 'off'
  /** Puede elegir un negocio y jugar. */
  | 'available'
  /** Ya eligió negocio y le falta jugar (o terminar el intento). */
  | 'playing'
  /** Ya jugó esta semana (ganó o perdió): vuelve el lunes. */
  | 'done'
  /** No tiene ningún negocio donde jugar (aún no es cliente de ninguno). */
  | 'empty';

/**
 * El juego semanal: una vez por semana (de lunes a domingo, hora de Ecuador) el
 * cliente elige un negocio y juega; si gana, suma puntos en ese negocio. No
 * puede repetir un negocio donde ya ganó (hasta haber ganado en todos; entonces
 * la lista se abre de nuevo). Si pierde, pierde la semana pero no bloquea el
 * negocio. Usa los mismos juegos y la misma pantalla que los retos de los dueños.
 */
@Injectable()
export class WeeklyGameService {
  private readonly logger = new Logger(WeeklyGameService.name);

  constructor(
    @InjectRepository(GameInvite)
    private readonly inviteRepository: Repository<GameInvite>,
    @InjectRepository(LoyaltyCard)
    private readonly cardRepository: Repository<LoyaltyCard>,
    private readonly loyaltyCards: LoyaltyCardsService,
    private readonly notifications: NotificationsService,
    private readonly settings: SettingsService,
  ) {}

  private async enabled(): Promise<boolean> {
    return (await this.settings.get(SETTING_KEYS.weeklyGameEnabled)) === 1;
  }

  private points(): Promise<number> {
    return this.settings.get(SETTING_KEYS.weeklyGamePoints);
  }

  /** "1 punto en Café Aurora" / "2 puntos en Café Aurora". */
  async prizeLabel(businessName: string | null | undefined): Promise<string> {
    const n = await this.points();
    return `${n} ${n === 1 ? 'punto' : 'puntos'} en ${businessName ?? 'el negocio'}`;
  }

  /** Los negocios donde el cliente puede jugar (es cliente y el local está activo) y los que tiene bloqueados. */
  private async choices(userId: string) {
    const [cards, wins] = await Promise.all([
      this.cardRepository.find({ where: { userId }, relations: ['business'] }),
      this.inviteRepository.find({
        where: { userId, weekly: true, result: 'won' },
        order: { finishedAt: 'ASC' },
        select: ['businessId', 'finishedAt'],
      }),
    ]);
    const eligible = cards.filter((c) => c.business?.isActive);
    const blocked = blockedBusinesses(
      wins.map((w) => w.businessId),
      new Set(eligible.map((c) => c.businessId)),
    );
    return { eligible, blocked };
  }

  /** Lo que ve el cliente: si puede jugar esta semana y qué negocios tiene para elegir. */
  async status(userId: string, now: Date = new Date()) {
    const week = weekOf(now);
    if (!(await this.enabled())) {
      return { enabled: false, state: 'off' as WeeklyState, weekStart: week.key, nextAt: week.endsAt, points: 0, businesses: [], current: null };
    }

    const [mine, { eligible, blocked }, points] = await Promise.all([
      this.inviteRepository.findOne({
        where: { userId, weekly: true, weekStart: week.key },
        relations: ['business'],
      }),
      this.choices(userId),
      this.points(),
    ]);

    let state: WeeklyState;
    if (mine) state = mine.status === 'finished' ? 'done' : 'playing';
    else state = eligible.length === 0 ? 'empty' : 'available';

    return {
      enabled: true,
      state,
      weekStart: week.key,
      /** Cuándo vuelve a estar disponible (el lunes siguiente). */
      nextAt: week.endsAt,
      points,
      current: mine && {
        inviteId: mine.id,
        businessId: mine.businessId,
        businessName: mine.business?.name ?? null,
        game: mine.game,
        gameName: GAME_NAMES[mine.game as GameKey] ?? mine.game,
        status: mine.status,
        result: mine.result,
        /** Aún no empezó el primer intento: puede cambiar de negocio. */
        canChange: mine.status === 'sent' && mine.attempts === 0,
      },
      businesses: eligible
        .map((c) => ({
          id: c.businessId,
          name: c.business.name,
          logoUrl: c.business.logoUrl ?? null,
          currentPoints: c.currentPoints,
          pointsRequired: c.business.pointsRequired || 10,
          blocked: blocked.has(c.businessId),
        }))
        .sort((a, b) => Number(a.blocked) - Number(b.blocked) || a.name.localeCompare(b.name)),
    };
  }

  /**
   * El cliente elige el negocio y arranca su juego de la semana. Si ya lo había
   * elegido y no ha jugado, puede cambiar de negocio; si ya jugó, no.
   */
  async start(userId: string, businessId: string, now: Date = new Date()) {
    if (!(await this.enabled())) {
      throw new BadRequestException('El juego semanal no está disponible por ahora');
    }
    const week = weekOf(now);

    let invite = await this.inviteRepository.findOne({
      where: { userId, weekly: true, weekStart: week.key },
    });
    if (invite?.status === 'finished') {
      throw new BadRequestException('Ya jugaste esta semana. Vuelve el lunes para elegir otro negocio.');
    }
    if (invite && invite.businessId === businessId) return { inviteId: invite.id, game: invite.game };
    if (invite && invite.attempts > 0) {
      throw new BadRequestException('Ya empezaste a jugar en otro negocio esta semana.');
    }

    const { eligible, blocked } = await this.choices(userId);
    if (!eligible.some((c) => c.businessId === businessId)) {
      throw new BadRequestException('Solo puedes jugar en los negocios donde tienes tarjeta');
    }
    if (blocked.has(businessId)) {
      throw new BadRequestException('Ya ganaste un punto en este negocio. Elige otro.');
    }

    if (invite) {
      // Aún no jugaba: cambia de negocio.
      invite.businessId = businessId;
      await this.inviteRepository.save(invite);
      return { inviteId: invite.id, game: invite.game };
    }

    try {
      invite = await this.inviteRepository.save(
        this.inviteRepository.create({
          businessId,
          userId,
          sentById: null,
          game: pickWeeklyGame(userId, week.key),
          status: 'sent',
          weekly: true,
          weekStart: week.key,
          startsAt: now,
          expiresAt: week.endsAt,
          notifiedAt: now,
        }),
      );
    } catch (error) {
      // Dos toques seguidos: la restricción única ya creó el juego de esta semana.
      if (error?.code === '23505') {
        const again = await this.inviteRepository.findOne({ where: { userId, weekly: true, weekStart: week.key } });
        if (again) return { inviteId: again.id, game: again.game };
      }
      throw error;
    }
    return { inviteId: invite.id, game: invite.game };
  }

  /** El cliente ganó su juego semanal: se le suman los puntos en el negocio que eligió. */
  async awardPoint(invite: GameInvite) {
    const points = await this.points();
    const business = invite.business?.name ?? 'tu local';
    const result = await this.loyaltyCards.grantBonusPoints(invite.userId, invite.businessId, points);
    const label = `${points} ${points === 1 ? 'punto' : 'puntos'}`;

    await this.safely(() =>
      this.notifications.sendToUser(
        invite.userId,
        '¡Ganaste tu juego de la semana!',
        `Sumaste ${label} en ${business}. La próxima semana juega en otro negocio.`,
        { type: 'weekly_game_won', route: '/home' },
      ),
    );
    if (result.newRewards > 0) {
      await this.safely(() =>
        this.notifications.sendToUser(
          invite.userId,
          '¡Completaste tu tarjeta!',
          `Con tu juego de la semana completaste tu tarjeta en ${business}: ¡tienes un premio por reclamar!`,
          { type: 'weekly_game_reward', route: '/home' },
        ),
      );
    }
    await this.safely(() =>
      this.notifications.sendToBusinessOwner(
        invite.businessId,
        '¡Un cliente ganó un punto jugando!',
        `${invite.user?.fullName ?? 'Un cliente'} ganó ${label} con el juego semanal de Fidelity.`,
        { type: 'weekly_game_owner', route: '/business_dashboard/customers' },
      ),
    );
  }

  private async safely(task: () => Promise<unknown>) {
    try {
      await task();
    } catch (error) {
      this.logger.warn(`Aviso del juego semanal no enviado: ${error.message}`);
    }
  }
}
