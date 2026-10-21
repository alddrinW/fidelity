import { GamesSchedulerService } from './games-scheduler.service';

describe('GamesSchedulerService', () => {
  const make = (notifyDue: jest.Mock) => new GamesSchedulerService({ notifyDue } as any);

  it('cada pasada avisa de los juegos que ya empezaron y devuelve cuántos fueron', async () => {
    const notifyDue = jest.fn().mockResolvedValue(3);
    const now = new Date('2026-10-21T15:00:00Z');

    expect(await make(notifyDue).tick(now)).toBe(3);
    expect(notifyDue).toHaveBeenCalledWith(now);
  });

  it('una pasada no se solapa con otra que sigue corriendo', async () => {
    let release!: () => void;
    const notifyDue = jest.fn(() => new Promise<number>((resolve) => (release = () => resolve(1))));
    const scheduler = make(notifyDue as any);

    const first = scheduler.tick();
    const second = await scheduler.tick();
    release();

    expect(second).toBe(0);
    expect(await first).toBe(1);
    expect(notifyDue).toHaveBeenCalledTimes(1);
  });

  it('un error no detiene el programador y permite la siguiente pasada', async () => {
    const notifyDue = jest.fn().mockRejectedValueOnce(new Error('db caida')).mockResolvedValue(1);
    const scheduler = make(notifyDue);

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
