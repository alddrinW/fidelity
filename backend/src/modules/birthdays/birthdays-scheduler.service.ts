import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { BirthdaysService } from './birthdays.service';

/** Cada cuánto se revisa si hay cumpleaños de los que avisar. */
export const BIRTHDAYS_SCHEDULER_INTERVAL_MS = 30 * 60_000;

/**
 * Programador de cumpleaños: cada media hora avisa a los dueños de los clientes
 * que cumplen años hoy (a partir de la hora que fija el administrador). Cada
 * aviso sale una sola vez por cliente y año, aunque la revisión corra muchas veces.
 */
@Injectable()
export class BirthdaysSchedulerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(BirthdaysSchedulerService.name);
  private timer: NodeJS.Timeout | null = null;
  private running = false;

  constructor(private readonly birthdaysService: BirthdaysService) {}

  onModuleInit() {
    // Los tests no deben dejar temporizadores abiertos.
    if (process.env.NODE_ENV === 'test') return;
    this.timer = setInterval(() => void this.tick(), BIRTHDAYS_SCHEDULER_INTERVAL_MS);
    this.timer.unref();
    setTimeout(() => void this.tick(), 15_000).unref();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  /** Una pasada; evita que dos pasadas se solapen. */
  async tick(now: Date = new Date()): Promise<number> {
    if (this.running) return 0;
    this.running = true;
    try {
      const sent = await this.birthdaysService.notifyDue(now);
      if (sent > 0) this.logger.log(`Avisos de cumpleaños: ${sent}`);
      return sent;
    } catch (error) {
      this.logger.error(`Error en el programador de cumpleaños: ${error.message}`);
      return 0;
    } finally {
      this.running = false;
    }
  }
}
