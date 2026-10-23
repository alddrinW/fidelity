import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { FindOptionsWhere, IsNull, LessThan, Not, Repository } from 'typeorm';
import { GameInvite } from '../../database/entities/game-invite.entity';
import { Notification } from '../../database/entities/notification.entity';
import { ScanAttempt } from '../../database/entities/scan-attempt.entity';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { SettingsService } from '../settings/settings.service';

const DAY = 24 * 60 * 60 * 1000;

/** Un aviso ya leído se borra pasados estos días (por defecto; el administrador lo cambia). */
export const READ_NOTIFICATION_RETENTION_DAYS = 30;

/** Cualquier aviso (leído o no) se borra pasados estos días. */
export const NOTIFICATION_MAX_RETENTION_DAYS = 90;

/** Los intentos de escaneo son solo un registro: se borran pasados estos días. */
export const SCAN_ATTEMPT_RETENTION_DAYS = 90;

/** Un reto de minijuego ya terminado o vencido se borra pasados estos días. */
export const GAME_INVITE_RETENTION_DAYS = 90;

/** Cuántas filas se borran por pasada, para no bloquear la base de datos. */
const BATCH_SIZE = 1000;

/** Cada cuánto corre la limpieza. */
export const RETENTION_INTERVAL_MS = 6 * 60 * 60 * 1000;

export interface PurgeResult {
  notifications: number;
  scanAttempts: number;
  gameInvites: number;
}

/**
 * Limpieza automática: borra lo viejo que solo se acumula (avisos de la
 * bandeja, registro de intentos de escaneo y retos de minijuegos ya
 * terminados) para que las tablas no crezcan sin fin.
 *
 * Nunca toca lo que el cliente todavía puede usar: ni retos abiertos, ni
 * gift cards, ni tarjetas, ni premios. Corre dentro del propio servidor cada
 * 6 horas (y poco después de arrancar); borra por tandas.
 */
@Injectable()
export class RetentionService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RetentionService.name);
  private timer: NodeJS.Timeout | null = null;
  private running = false;

  constructor(
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
    @InjectRepository(ScanAttempt)
    private readonly attemptRepository: Repository<ScanAttempt>,
    @InjectRepository(GameInvite)
    private readonly inviteRepository: Repository<GameInvite>,
    private readonly settings: SettingsService,
  ) {}

  onModuleInit() {
    // Los tests no deben dejar temporizadores abiertos.
    if (process.env.NODE_ENV === 'test') return;
    this.timer = setInterval(() => void this.run(), RETENTION_INTERVAL_MS);
    this.timer.unref();
    setTimeout(() => void this.run(), 2 * 60 * 1000).unref();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  /** Una pasada; evita que dos pasadas se solapen y no se cae si algo falla. */
  async run(now: Date = new Date()): Promise<PurgeResult | null> {
    if (this.running) return null;
    this.running = true;
    try {
      const result = await this.purge(now);
      const total = result.notifications + result.scanAttempts + result.gameInvites;
      if (total > 0) {
        this.logger.log(
          `Limpieza: ${result.notifications} avisos, ${result.scanAttempts} intentos de escaneo, ${result.gameInvites} retos de minijuegos`,
        );
      }
      return result;
    } catch (error) {
      this.logger.error(`Error en la limpieza automática: ${error.message}`);
      return null;
    } finally {
      this.running = false;
    }
  }

  async purge(now: Date = new Date()): Promise<PurgeResult> {
    const before = (days: number) => new Date(now.getTime() - days * DAY);
    const [readDays, anyDays, scanDays, inviteDays] = await Promise.all([
      this.settings.get(SETTING_KEYS.keepReadNotificationsDays),
      this.settings.get(SETTING_KEYS.keepNotificationsDays),
      this.settings.get(SETTING_KEYS.keepScanAttemptsDays),
      this.settings.get(SETTING_KEYS.keepGameInvitesDays),
    ]);

    const notifications =
      (await this.deleteInBatches(this.notificationRepository, {
        readAt: Not(IsNull()),
        createdAt: LessThan(before(readDays)),
      })) +
      (await this.deleteInBatches(this.notificationRepository, {
        createdAt: LessThan(before(anyDays)),
      }));

    const scanAttempts = await this.deleteInBatches(this.attemptRepository, {
      createdAt: LessThan(before(scanDays)),
    });

    const gameInvites =
      (await this.deleteInBatches(this.inviteRepository, {
        status: 'finished',
        finishedAt: LessThan(before(inviteDays)),
      })) +
      // Retos que nunca se jugaron y vencieron hace tiempo.
      (await this.deleteInBatches(this.inviteRepository, {
        expiresAt: LessThan(before(inviteDays)),
      }));

    return { notifications, scanAttempts, gameInvites };
  }

  /** Borra lo que cumpla [where] de a [BATCH_SIZE] filas; devuelve cuántas. */
  private async deleteInBatches<T extends { id: string }>(
    repository: Repository<T>,
    where: FindOptionsWhere<T>,
  ): Promise<number> {
    let total = 0;
    for (;;) {
      const rows = await repository.find({ where, select: ['id'] as any, take: BATCH_SIZE });
      if (rows.length === 0) break;
      await repository.delete(rows.map((r) => r.id));
      total += rows.length;
      if (rows.length < BATCH_SIZE) break;
    }
    return total;
  }
}
