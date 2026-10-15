import { CampaignSchedulerService } from './campaign-scheduler.service';

describe('CampaignSchedulerService', () => {
  const make = (dispatchDue: jest.Mock) =>
    new CampaignSchedulerService({ dispatchDue } as any);

  it('cada pasada avisa de las campañas vencidas y devuelve cuantas fueron', async () => {
    const dispatchDue = jest.fn().mockResolvedValue(2);
    const now = new Date('2026-10-14T12:00:00Z');

    expect(await make(dispatchDue).tick(now)).toBe(2);
    expect(dispatchDue).toHaveBeenCalledWith(now);
  });

  it('una pasada no se solapa con otra que sigue corriendo', async () => {
    let release!: () => void;
    const dispatchDue = jest.fn(
      () => new Promise<number>((resolve) => (release = () => resolve(1))),
    );
    const scheduler = make(dispatchDue as any);

    const first = scheduler.tick();
    const second = await scheduler.tick();
    release();

    expect(second).toBe(0);
    expect(await first).toBe(1);
    expect(dispatchDue).toHaveBeenCalledTimes(1);
  });

  it('un error no detiene el programador y permite la siguiente pasada', async () => {
    const dispatchDue = jest.fn().mockRejectedValueOnce(new Error('db caida')).mockResolvedValue(1);
    const scheduler = make(dispatchDue);

    expect(await scheduler.tick()).toBe(0);
    expect(await scheduler.tick()).toBe(1);
  });

  it('en tests no deja temporizadores abiertos', () => {
    const scheduler = make(jest.fn());

    scheduler.onModuleInit();
    scheduler.onModuleDestroy();

    expect((scheduler as any).timer).toBeNull();
  });
});
