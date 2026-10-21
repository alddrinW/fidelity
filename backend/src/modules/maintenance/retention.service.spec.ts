import { IsNull, Not } from 'typeorm';
import {
  GAME_INVITE_RETENTION_DAYS,
  NOTIFICATION_MAX_RETENTION_DAYS,
  READ_NOTIFICATION_RETENTION_DAYS,
  RetentionService,
  SCAN_ATTEMPT_RETENTION_DAYS,
} from './retention.service';

const DAY = 24 * 60 * 60 * 1000;
const now = new Date('2026-10-21T15:00:00Z');
const daysAgo = (n: number) => new Date(now.getTime() - n * DAY).getTime();

/** Un repositorio falso con `rows` filas (ids) que `find` entrega por tandas. */
function fakeRepo(rows = 0) {
  let remaining = rows;
  return {
    find: jest.fn(async (options: { take: number }) => {
      const n = Math.min(remaining, options.take);
      remaining -= n;
      return Array.from({ length: n }, (_, i) => ({ id: `id-${i}` }));
    }),
    delete: jest.fn().mockResolvedValue({ affected: 1 }),
  };
}

describe('RetentionService', () => {
  let notifications: ReturnType<typeof fakeRepo>;
  let attempts: ReturnType<typeof fakeRepo>;
  let invites: ReturnType<typeof fakeRepo>;
  const make = () => new RetentionService(notifications as any, attempts as any, invites as any);

  beforeEach(() => {
    notifications = fakeRepo();
    attempts = fakeRepo();
    invites = fakeRepo();
  });

  const cutoff = (repo: ReturnType<typeof fakeRepo>, call: number, field: string): number =>
    (repo.find.mock.calls[call][0] as any).where[field].value.getTime();

  describe('qué se borra y desde cuándo', () => {
    it('avisos: los leídos pasados 30 días y cualquiera pasados 90', async () => {
      await make().purge(now);

      const [readPass, anyPass] = notifications.find.mock.calls.map((c) => (c[0] as any).where);
      expect(readPass.readAt).toEqual(Not(IsNull()));
      expect(cutoff(notifications, 0, 'createdAt')).toBe(daysAgo(READ_NOTIFICATION_RETENTION_DAYS));
      expect(anyPass.readAt).toBeUndefined();
      expect(cutoff(notifications, 1, 'createdAt')).toBe(daysAgo(NOTIFICATION_MAX_RETENTION_DAYS));
    });

    it('intentos de escaneo: los de más de 90 días', async () => {
      await make().purge(now);

      expect(cutoff(attempts, 0, 'createdAt')).toBe(daysAgo(SCAN_ATTEMPT_RETENTION_DAYS));
    });

    it('retos de minijuegos: los terminados y los vencidos hace más de 90 días', async () => {
      await make().purge(now);

      const [finished, expired] = invites.find.mock.calls.map((c) => (c[0] as any).where);
      expect(finished.status).toBe('finished');
      expect(cutoff(invites, 0, 'finishedAt')).toBe(daysAgo(GAME_INVITE_RETENTION_DAYS));
      expect(expired.status).toBeUndefined();
      expect(cutoff(invites, 1, 'expiresAt')).toBe(daysAgo(GAME_INVITE_RETENTION_DAYS));
    });

    it('un reto abierto nunca se borra por la regla de "terminado"', async () => {
      await make().purge(now);

      const finishedRule = (invites.find.mock.calls[0][0] as any).where;
      expect(finishedRule).toMatchObject({ status: 'finished' });
    });
  });

  describe('cómo se borra', () => {
    it('borra lo que encuentra y devuelve cuántas filas fueron', async () => {
      notifications = fakeRepo(5);
      attempts = fakeRepo(3);
      invites = fakeRepo(2);

      const result = await make().purge(now);

      // 5 avisos en la primera pasada; la segunda ya no encuentra nada.
      expect(result).toEqual({ notifications: 5, scanAttempts: 3, gameInvites: 2 });
      expect(notifications.delete).toHaveBeenCalledWith(['id-0', 'id-1', 'id-2', 'id-3', 'id-4']);
    });

    it('borra por tandas de 1000 para no bloquear la base', async () => {
      notifications = fakeRepo(2500);

      const result = await make().purge(now);

      expect(result.notifications).toBe(2500);
      const sizes = notifications.delete.mock.calls.map((c) => (c[0] as string[]).length);
      expect(sizes).toEqual([1000, 1000, 500]);
    });

    it('sin nada viejo no borra nada', async () => {
      const result = await make().purge(now);

      expect(result).toEqual({ notifications: 0, scanAttempts: 0, gameInvites: 0 });
      expect(notifications.delete).not.toHaveBeenCalled();
      expect(attempts.delete).not.toHaveBeenCalled();
      expect(invites.delete).not.toHaveBeenCalled();
    });
  });

  describe('programador', () => {
    it('una pasada que falla no tumba al servidor y deja correr la siguiente', async () => {
      const service = make();
      notifications.find.mockRejectedValueOnce(new Error('db caída'));

      expect(await service.run(now)).toBeNull();
      expect(await service.run(now)).toEqual({ notifications: 0, scanAttempts: 0, gameInvites: 0 });
    });

    it('dos pasadas a la vez no se solapan', async () => {
      const service = make();
      let release!: () => void;
      notifications.find.mockImplementationOnce(() => new Promise((resolve) => (release = () => resolve([]))));

      const first = service.run(now);
      const second = await service.run(now);
      release();
      await first;

      expect(second).toBeNull();
    });

    it('en tests no deja temporizadores abiertos', () => {
      const service = make();

      service.onModuleInit();
      service.onModuleDestroy();

      expect((service as any).timer).toBeNull();
    });
  });
});
