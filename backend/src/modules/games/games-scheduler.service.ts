import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { GamesService } from './games.service';

/** Cada cuánto se revisa si algún juego programado ya debe empezar. */
export const GAMES_SCHEDULER_INTERVAL_MS = 60_000;

/**
 * Programador de minijuegos: cada minuto avisa a los clientes cuyo juego tiene
 * hora de inicio y esa hora ya llegó. Corre dentro del propio servidor; si
 * estuvo apagado, los avisos atrasados salen al arrancar de nuevo.
 */
@Injectable()
export class GamesSchedulerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(GamesSchedulerService.name);
  private timer: NodeJS.Timeout | null = null;
  private running = false;

  constructor(private readonly gamesService: GamesService) {}

  onModuleInit() {
    // Los tests no deben dejar temporizadores abiertos.
    if (process.env.NODE_ENV === 'test') return;
    this.timer = setInterval(() => void this.tick(), GAMES_SCHEDULER_INTERVAL_MS);
    this.timer.unref();
    setTimeout(() => void this.tick(), 5_000).unref();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  /** Una pasada del programador; evita que dos pasadas se solapen. */
  async tick(now: Date = new Date()): Promise<number> {
    if (this.running) return 0;
    this.running = true;
    try {
      const notified = await this.gamesService.notifyDue(now);
      if (notified > 0) this.logger.log(`Juegos avisados: ${notified}`);
      return notified;
    } catch (error) {
      this.logger.error(`Error en el programador de minijuegos: ${error.message}`);
      return 0;
    } finally {
      this.running = false;
    }
  }
}
