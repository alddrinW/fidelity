import { BirthdaysSchedulerService } from './birthdays-scheduler.service';

describe('BirthdaysSchedulerService', () => {
  const make = (notifyDue: jest.Mock) => new BirthdaysSchedulerService({ notifyDue } as any);

  it('cada pasada avisa de los cumpleaños de hoy y devuelve cuántos avisos salieron', async () => {
    const notifyDue = jest.fn().mockResolvedValue(2);
    const now = new Date('2026-10-22T15:00:00Z');

    expect(await make(notifyDue).tick(now)).toBe(2);
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
  });

  it('un error no detiene el programador', async () => {
    const notifyDue = jest.fn().mockRejectedValueOnce(new Error('db caída')).mockResolvedValue(1);
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
