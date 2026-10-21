import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { NotificationsService } from './notifications.service';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { Business } from '../../database/entities/business.entity';
import { BusinessMember } from '../../database/entities/business-member.entity';
import { Notification } from '../../database/entities/notification.entity';

describe('NotificationsService - bandeja', () => {
  let service: NotificationsService;
  let profileRepo: any;
  let businessRepo: any;
  let memberRepo: any;
  let inbox: any;

  beforeEach(async () => {
    profileRepo = { findOne: jest.fn(), find: jest.fn() };
    businessRepo = { findOne: jest.fn() };
    memberRepo = { find: jest.fn().mockResolvedValue([]) };
    inbox = {
      insert: jest.fn().mockResolvedValue(undefined),
      find: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        { provide: ConfigService, useValue: { get: () => undefined } },
        { provide: getRepositoryToken(Profile), useValue: profileRepo },
        { provide: getRepositoryToken(Business), useValue: businessRepo },
        { provide: getRepositoryToken(BusinessMember), useValue: memberRepo },
        { provide: getRepositoryToken(Notification), useValue: inbox },
      ],
    }).compile();
    service = module.get(NotificationsService);
  });

  const saved = () => inbox.insert.mock.calls.flatMap((c: any[]) => c[0]);

  describe('guardar en la bandeja', () => {
    it('un aviso a un usuario queda guardado aunque no tenga token de push', async () => {
      profileRepo.findOne.mockResolvedValue({ id: 'u1', fcmToken: null });

      const pushed = await service.sendToUser('u1', 'Punto aprobado', 'Tu escaneo fue aprobado.', {
        type: 'scan_approved',
        route: '/points_approved',
      });

      expect(pushed).toBe(false);
      expect(saved()).toEqual([
        {
          userId: 'u1',
          type: 'scan_approved',
          title: 'Punto aprobado',
          body: 'Tu escaneo fue aprobado.',
          data: { type: 'scan_approved', route: '/points_approved' },
        },
      ]);
    });

    it('sin tipo se guarda como general y sin datos', async () => {
      profileRepo.findOne.mockResolvedValue({ id: 'u1', fcmToken: 'tok' });

      await service.sendToUser('u1', 'Hola', 'Mundo');

      expect(saved()[0]).toMatchObject({ type: 'general', data: null });
    });

    it('un usuario que no existe no recibe nada', async () => {
      profileRepo.findOne.mockResolvedValue(null);

      expect(await service.sendToUser('nadie', 'x', 'y')).toBe(false);
      expect(inbox.insert).not.toHaveBeenCalled();
    });

    it('un aviso a muchos usuarios queda en la bandeja de cada uno, sin repetir', async () => {
      profileRepo.find.mockResolvedValue([{ id: 'a', fcmToken: 't1' }, { id: 'b', fcmToken: null }]);

      const sent = await service.sendToUsers(['a', 'b', 'a'], 'Gift card', 'Recibiste una', { type: 'gift_card' });

      expect(saved().map((r: any) => r.userId)).toEqual(['a', 'b']);
      expect(sent).toBe(1); // solo uno tenía token
    });

    it('un aviso al personal llega al dueño y a sus aprobadores', async () => {
      businessRepo.findOne.mockResolvedValue({ id: 'b1', ownerId: 'owner', owner: { fcmToken: 't' } });
      memberRepo.find.mockResolvedValue([{ userId: 'appr', user: { fcmToken: null } }]);

      await service.sendToBusinessStaff('b1', 'Escaneo por aprobar', 'Un cliente escaneó');

      expect(saved().map((r: any) => r.userId).sort()).toEqual(['appr', 'owner']);
    });

    it('un aviso al dueño queda en su bandeja', async () => {
      businessRepo.findOne.mockResolvedValue({ id: 'b1', owner: { id: 'owner', fcmToken: null } });

      await service.sendToBusinessOwner('b1', 'Pago validado', 'Tu cuenta está activa');

      expect(saved()[0]).toMatchObject({ userId: 'owner', title: 'Pago validado' });
    });

    it('los avisos a administradores quedan en la bandeja de cada uno', async () => {
      profileRepo.find.mockResolvedValue([
        { id: 'ad1', role: UserRole.ADMIN, fcmToken: 't' },
        { id: 'ad2', role: UserRole.ADMIN, fcmToken: null },
      ]);

      await service.broadcastToAdmins('Nuevo pago', 'Un negocio pagó', '/admin_payments');

      expect(saved().map((r: any) => r.userId)).toEqual(['ad1', 'ad2']);
      expect(saved()[0]).toMatchObject({ type: 'admin', data: { type: 'admin', route: '/admin_payments' } });
    });

    it('un fallo al guardar no rompe el envío', async () => {
      profileRepo.find.mockResolvedValue([{ id: 'a', fcmToken: 't1' }]);
      inbox.insert.mockRejectedValue(new Error('db caida'));

      await expect(service.sendToUsers(['a'], 'x', 'y')).resolves.toBe(1);
    });

    it('guarda en tandas cuando la audiencia es grande', async () => {
      const ids = Array.from({ length: 1200 }, (_, i) => `u${i}`);
      profileRepo.find.mockResolvedValue([]);

      await service.sendToUsers(ids, 'x', 'y');

      expect(inbox.insert).toHaveBeenCalledTimes(3);
      expect(saved()).toHaveLength(1200);
    });
  });

  describe('consultar la bandeja', () => {
    it('lista sus movimientos con el estado de lectura', async () => {
      inbox.find.mockResolvedValue([
        { id: '1', type: 'gift_card', title: 'A', body: 'a', data: null, readAt: null, createdAt: new Date('2026-10-16') },
        { id: '2', type: 'general', title: 'B', body: 'b', data: null, readAt: new Date(), createdAt: new Date('2026-10-15') },
      ]);

      const items = await service.listForUser('u1');

      expect(items.map((i) => [i.id, i.read])).toEqual([['1', false], ['2', true]]);
      expect(inbox.find).toHaveBeenCalledWith(
        expect.objectContaining({ where: { userId: 'u1' }, order: { createdAt: 'DESC' }, take: 30 }),
      );
    });

    it('el tamaño de página tiene un tope de 50', async () => {
      await service.listForUser('u1', 9999);

      expect(inbox.find.mock.calls[0][0].take).toBe(50);
    });

    it('pagina con una fecha y ignora una fecha inválida', async () => {
      await service.listForUser('u1', 10, '2026-10-15T00:00:00.000Z');
      expect(inbox.find.mock.calls[0][0].where.createdAt).toBeDefined();

      inbox.find.mockClear();
      await service.listForUser('u1', 10, 'no-es-fecha');
      expect(inbox.find.mock.calls[0][0].where.createdAt).toBeUndefined();
    });

    it('cuenta solo las no leídas del usuario', async () => {
      inbox.count.mockResolvedValue(4);

      expect(await service.unreadCount('u1')).toBe(4);
      expect(inbox.count.mock.calls[0][0].where.userId).toBe('u1');
    });

    it('solo marca como leídas las suyas', async () => {
      await service.markRead('u1', 'n1');
      expect(inbox.update.mock.calls[0][0]).toMatchObject({ id: 'n1', userId: 'u1' });

      inbox.update.mockClear();
      await service.markAllRead('u1');
      expect(inbox.update.mock.calls[0][0]).toMatchObject({ userId: 'u1' });
    });
  });
});
