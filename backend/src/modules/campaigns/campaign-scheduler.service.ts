import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { CampaignsService } from './campaigns.service';

/** Cada cuánto se revisa si alguna campaña programada ya debe empezar. */
export const SCHEDULER_INTERVAL_MS = 60_000;

/**
 * Programador de campañas: cada minuto avisa a los clientes de las campañas
 * programadas cuya hora de inicio ya llegó. Corre dentro del propio servidor
 * (no hace falta un servicio externo); si el servidor estuvo apagado, las
 * campañas atrasadas se avisan al arrancar de nuevo.
 */
@Injectable()
export class CampaignSchedulerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(CampaignSchedulerService.name);
  private timer: NodeJS.Timeout | null = null;
  private running = false;

  constructor(private readonly campaignsService: CampaignsService) {}

  onModuleInit() {
    // Los tests no deben dejar temporizadores abiertos.
    if (process.env.NODE_ENV === 'test') return;
    this.timer = setInterval(() => void this.tick(), SCHEDULER_INTERVAL_MS);
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
      const dispatched = await this.campaignsService.dispatchDue(now);
      if (dispatched > 0) this.logger.log(`Campañas avisadas: ${dispatched}`);
      return dispatched;
    } catch (error) {
      this.logger.error(`Error en el programador de campañas: ${error.message}`);
      return 0;
    } finally {
      this.running = false;
    }
  }
}
