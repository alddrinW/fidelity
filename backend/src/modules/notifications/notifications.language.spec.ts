import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { NotificationsService } from './notifications.service';
import { Profile } from '../../database/entities/profile.entity';
import { Business } from '../../database/entities/business.entity';
import { BusinessMember } from '../../database/entities/business-member.entity';
import { Notification } from '../../database/entities/notification.entity';

/** Los avisos salen en el idioma de la app de cada usuario. */
describe('NotificationsService - idioma', () => {
  let service: NotificationsService;
  let profileRepo: any;
  let businessRepo: any;
  let memberRepo: any;
  let inbox: any;
  let push: jest.SpyInstance;

  beforeEach(async () => {
    profileRepo = { findOne: jest.fn(), find: jest.fn() };
    businessRepo = { findOne: jest.fn() };
    memberRepo = { find: jest.fn().mockResolvedValue([]) };
    inbox = {
      insert: jest.fn().mockResolvedValue(undefined),
      find: jest.fn().mockResolvedValue([]),
      count: jest.fn(),
      update: jest.fn(),
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
    push = jest.spyOn(service, 'sendPushNotification').mockResolvedValue(true);
  });

  const pushedTo = (token: string) => push.mock.calls.find((c) => c[0] === token);

  describe('push', () => {
    it('a un usuario con la app en inglés le llega en inglés', async () => {
      profileRepo.findOne.mockResolvedValue({ id: 'u1', fcmToken: 't-en', language: 'en' });

      await service.sendToUser('u1', 'Punto aprobado', 'Tu escaneo en Café Aurora fue aprobado.');

      expect(push).toHaveBeenCalledWith('t-en', 'Point approved', 'Your scan at Café Aurora was approved.', {});
    });

    it('a un usuario en español le llega en español', async () => {
      profileRepo.findOne.mockResolvedValue({ id: 'u1', fcmToken: 't-es', language: 'es' });

      await service.sendToUser('u1', 'Punto aprobado', 'Tu escaneo en Café Aurora fue aprobado.');

      expect(push).toHaveBeenCalledWith('t-es', 'Punto aprobado', 'Tu escaneo en Café Aurora fue aprobado.', {});
    });

    it('un usuario sin idioma guardado se trata como español', async () => {
      profileRepo.findOne.mockResolvedValue({ id: 'u1', fcmToken: 't', language: undefined });

      await service.sendToUser('u1', 'Punto aprobado', 'x');

      expect(push.mock.calls[0][1]).toBe('Punto aprobado');
    });

    it('al dueño del negocio le llega en su idioma', async () => {
      businessRepo.findOne.mockResolvedValue({ id: 'b1', owner: { id: 'o1', fcmToken: 'to', language: 'en' } });

      await service.sendToBusinessOwner('b1', '¡Pago validado!', 'x');

      expect(push.mock.calls[0][1]).toBe('Payment validated!');
    });

    it('el personal del local recibe cada aviso en su idioma', async () => {
      businessRepo.findOne.mockResolvedValue({
        id: 'b1',
        ownerId: 'o1',
        owner: { id: 'o1', fcmToken: 't-owner', language: 'es' },
      });
      memberRepo.find.mockResolvedValue([
        { userId: 'a1', user: { id: 'a1', fcmToken: 't-ap-en', language: 'en' } },
        { userId: 'a2', user: { id: 'a2', fcmToken: 't-ap-es', language: 'es' } },
      ]);

      const sent = await service.sendToBusinessStaff('b1', 'Escaneo por aprobar', 'x');

      expect(sent).toBe(3);
      expect(pushedTo('t-owner')![1]).toBe('Escaneo por aprobar');
      expect(pushedTo('t-ap-es')![1]).toBe('Escaneo por aprobar');
      expect(pushedTo('t-ap-en')![1]).toBe('Scan to approve');
    });

    it('un aviso a muchos usuarios sale en el idioma de cada uno', async () => {
      profileRepo.find.mockResolvedValue([
        { id: 'a', fcmToken: 't1', language: 'en' },
        { id: 'b', fcmToken: 't2', language: 'es' },
        { id: 'c', fcmToken: 't3', language: 'en' },
        { id: 'd', fcmToken: null, language: 'en' },
      ]);

      const sent = await service.sendToUsers(['a', 'b', 'c', 'd'], 'Gift card cancelada', 'x');

      expect(sent).toBe(3);
      expect(pushedTo('t1')![1]).toBe('Gift card cancelled');
      expect(pushedTo('t3')![1]).toBe('Gift card cancelled');
      expect(pushedTo('t2')![1]).toBe('Gift card cancelada');
    });

    it('el mismo dispositivo no recibe el aviso dos veces', async () => {
      profileRepo.find.mockResolvedValue([
        { id: 'a', fcmToken: 'igual', language: 'en' },
        { id: 'b', fcmToken: 'igual', language: 'en' },
      ]);

      expect(await service.sendToUsers(['a', 'b'], 'Punto aprobado', 'x')).toBe(1);
    });

    it('los administradores reciben el aviso en su idioma', async () => {
      profileRepo.find.mockResolvedValue([
        { id: 'ad1', fcmToken: 'tad1', language: 'en' },
        { id: 'ad2', fcmToken: 'tad2', language: 'es' },
      ]);

      await service.broadcastToAdmins('Pago por validar', 'x', '/admin_payments');

      expect(pushedTo('tad1')![1]).toBe('Payment to validate');
      expect(pushedTo('tad2')![1]).toBe('Pago por validar');
      expect(pushedTo('tad1')![3]).toEqual({ route: '/admin_payments' });
    });
  });

  describe('bandeja', () => {
    it('lo que se guarda en la bandeja es el texto original en español', async () => {
      profileRepo.findOne.mockResolvedValue({ id: 'u1', fcmToken: 't', language: 'en' });

      await service.sendToUser('u1', 'Punto aprobado', 'Tu escaneo en Café Aurora fue aprobado.');

      expect(inbox.insert.mock.calls[0][0][0]).toMatchObject({
        title: 'Punto aprobado',
        body: 'Tu escaneo en Café Aurora fue aprobado.',
      });
    });

    it('al leerla, un usuario en inglés la ve traducida', async () => {
      profileRepo.findOne.mockResolvedValue({ id: 'u1', language: 'en' });
      inbox.find.mockResolvedValue([
        { id: '1', type: 'x', title: 'Punto aprobado', body: 'Tu escaneo en Café Aurora fue aprobado.', data: null, readAt: null, createdAt: new Date() },
      ]);

      const [item] = await service.listForUser('u1');

      expect(item.title).toBe('Point approved');
      expect(item.body).toBe('Your scan at Café Aurora was approved.');
    });

    it('si cambia de idioma, sus avisos viejos cambian también', async () => {
      inbox.find.mockResolvedValue([
        { id: '1', type: 'x', title: 'Punto aprobado', body: 'x', data: null, readAt: null, createdAt: new Date() },
      ]);

      profileRepo.findOne.mockResolvedValue({ id: 'u1', language: 'en' });
      expect((await service.listForUser('u1'))[0].title).toBe('Point approved');

      profileRepo.findOne.mockResolvedValue({ id: 'u1', language: 'es' });
      expect((await service.listForUser('u1'))[0].title).toBe('Punto aprobado');
    });

    it('un aviso sin traducción se muestra en español', async () => {
      profileRepo.findOne.mockResolvedValue({ id: 'u1', language: 'en' });
      inbox.find.mockResolvedValue([
        { id: '1', type: 'x', title: 'Aviso nuevo', body: 'Sin traducir', data: null, readAt: null, createdAt: new Date() },
      ]);

      const [item] = await service.listForUser('u1');

      expect(item.title).toBe('Aviso nuevo');
    });
  });
});
