import { ForbiddenException } from '@nestjs/common';
import { UserRole } from '../../database/entities/profile.entity';
import { fakeSettings } from '../settings/settings.testing';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { FidelyService } from './fidely.service';
import { LoyaltyCardsService } from './loyalty-cards.service';

describe('LoyaltyCardsService (insignia FidelyUsuario)', () => {
  let cardRepo: any;
  let businessRepo: any;
  let scanRepo: any;
  let rewardRepo: any;
  let transferRepo: any;
  let counts: any[];
  let settings: ReturnType<typeof fakeSettings>;
  let service: LoyaltyCardsService;

  const query = () => {
    const q: any = {
      select: jest.fn().mockReturnThis(),
      addSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      groupBy: jest.fn().mockReturnThis(),
      getRawMany: jest.fn(async () => counts),
    };
    return q;
  };

  beforeEach(() => {
    counts = [];
    cardRepo = { find: jest.fn(), findOne: jest.fn() };
    businessRepo = { findOne: jest.fn().mockResolvedValue({ id: 'b1', ownerId: 'owner-1' }) };
    scanRepo = { createQueryBuilder: jest.fn(() => query()), find: jest.fn().mockResolvedValue([]) };
    rewardRepo = { find: jest.fn().mockResolvedValue([]) };
    transferRepo = { find: jest.fn().mockResolvedValue([]) };
    settings = fakeSettings();
    const fidely = new FidelyService(scanRepo, businessRepo, {} as any, {} as any, settings as any);
    service = new LoyaltyCardsService(cardRepo, businessRepo, scanRepo, rewardRepo, transferRepo, fidely);
  });

  describe('tarjetas del cliente', () => {
    it('cada tarjeta dice cuántos escaneos lleva en ese local y si ya es FidelyUsuario', async () => {
      cardRepo.find.mockResolvedValue([
        { id: 'c1', userId: 'u1', businessId: 'b1' },
        { id: 'c2', userId: 'u1', businessId: 'b2' },
      ]);
      // Las dos consultas (pendientes y escaneos reales) devuelven filas distintas.
      scanRepo.createQueryBuilder
        .mockImplementationOnce(() => {
          const q = query();
          q.getRawMany = jest.fn(async () => []);
          return q;
        })
        .mockImplementationOnce(() => {
          const q = query();
          q.getRawMany = jest.fn(async () => [{ key: 'b1', count: '3' }, { key: 'b2', count: '2' }]);
          return q;
        });

      const cards = await service.getUserCards('u1');

      expect(cards[0]).toMatchObject({ id: 'c1', verifiedScans: 3, fidelyRequired: 3, isFidely: true });
      expect(cards[1]).toMatchObject({ id: 'c2', verifiedScans: 2, fidelyRequired: 3, isFidely: false });
    });

    it('sin tarjetas devuelve la lista vacía', async () => {
      cardRepo.find.mockResolvedValue([]);

      expect(await service.getUserCards('u1')).toEqual([]);
    });
  });

  describe('clientes del local (vista del dueño)', () => {
    it('cada cliente trae su insignia según los escaneos que lleva en este local', async () => {
      cardRepo.find.mockResolvedValue([
        { id: 'c1', userId: 'u1', businessId: 'b1', user: { id: 'u1' } },
        { id: 'c2', userId: 'u2', businessId: 'b1', user: { id: 'u2' } },
        { id: 'c3', userId: 'u3', businessId: 'b1', user: { id: 'u3' } },
      ]);
      counts = [{ key: 'u1', count: '7' }, { key: 'u2', count: '2' }];

      const cards = await service.getBusinessCards('b1', 'owner-1', UserRole.BUSINESS);

      expect(cards.map((c) => [c.userId, c.isFidely, c.verifiedScans])).toEqual([
        ['u1', true, 7],
        ['u2', false, 2],
        ['u3', false, 0],
      ]);
    });

    it('si el administrador cambia la cantidad, cambian quienes la tienen', async () => {
      settings.get.mockImplementation(fakeSettings({ [SETTING_KEYS.fidelyScansRequired]: 2 }).get);
      cardRepo.find.mockResolvedValue([{ id: 'c2', userId: 'u2', businessId: 'b1', user: { id: 'u2' } }]);
      counts = [{ key: 'u2', count: '2' }];

      const [card] = await service.getBusinessCards('b1', 'owner-1', UserRole.BUSINESS);

      expect(card).toMatchObject({ isFidely: true, fidelyRequired: 2 });
    });

    it('solo el dueño (o el administrador) ve a los clientes', async () => {
      await expect(service.getBusinessCards('b1', 'otro', UserRole.BUSINESS)).rejects.toBeInstanceOf(ForbiddenException);
    });
  });

  describe('tarjetas de un cliente en varios locales', () => {
    it('trae solo las de esos locales', async () => {
      cardRepo.find.mockResolvedValue([{ businessId: 'b1', currentPoints: 3 }]);

      const cards = await service.cardsOf('u1', ['b1', 'b2']);

      expect(cardRepo.find).toHaveBeenCalledWith({ where: { userId: 'u1', businessId: expect.anything() } });
      expect(cards).toEqual([{ businessId: 'b1', currentPoints: 3 }]);
    });
  });

  describe('puntos de regalo (invitar amigos)', () => {
    let saved: any[];
    let transactionManager: any;

    beforeEach(() => {
      saved = [];
      transactionManager = {
        findOne: jest.fn(async (entity: any) =>
          entity.name === 'Business'
            ? { id: 'b1', pointsRequired: 10, rewardDescription: 'Café gratis' }
            : { id: 'card-1', userId: 'u1', businessId: 'b1', currentPoints: 4, totalPointsLifetime: 4, rewardsClaimed: 0 },
        ),
        create: jest.fn((_entity: any, data: any) => data),
        save: jest.fn(async (_entity: any, data: any) => {
          saved.push(data);
          return { id: 'card-1', ...data };
        }),
      };
      cardRepo.manager = { transaction: (cb: any) => cb(transactionManager) };
    });

    it('suma los puntos a la tarjeta', async () => {
      const result = await service.grantBonusPoints('u1', 'b1', 2);

      expect(result).toEqual({ cardId: 'card-1', currentPoints: 6, newRewards: 0 });
      expect(saved[0]).toMatchObject({ currentPoints: 6, totalPointsLifetime: 6, rewardsClaimed: 0 });
    });

    it('al completar los puntos del local genera el premio', async () => {
      transactionManager.findOne.mockImplementation(async (entity: any) =>
        entity.name === 'Business'
          ? { id: 'b1', pointsRequired: 10, rewardDescription: 'Café gratis' }
          : { id: 'card-1', userId: 'u1', businessId: 'b1', currentPoints: 9, totalPointsLifetime: 19, rewardsClaimed: 1 },
      );

      const result = await service.grantBonusPoints('u1', 'b1', 1);

      expect(result).toEqual({ cardId: 'card-1', currentPoints: 0, newRewards: 1 });
      expect(saved[0]).toMatchObject({ currentPoints: 0, totalPointsLifetime: 20, rewardsClaimed: 2 });
      expect(saved[1]).toMatchObject({ userId: 'u1', businessId: 'b1', status: 'pending', description: 'Café gratis', pointsUsed: 10 });
    });

    it('no se frena si ya tenía un premio pendiente: invitar amigos nunca le quita puntos', async () => {
      rewardRepo.find.mockResolvedValue([{ id: 'r1', status: 'pending' }]);

      await expect(service.grantBonusPoints('u1', 'b1', 1)).resolves.toMatchObject({ currentPoints: 5 });
    });

    it('si no tenía tarjeta en ese local, se la crea', async () => {
      transactionManager.findOne.mockImplementation(async (entity: any) =>
        entity.name === 'Business' ? { id: 'b1', pointsRequired: 10 } : null,
      );

      const result = await service.grantBonusPoints('u1', 'b1', 1);

      expect(transactionManager.create).toHaveBeenCalledWith(expect.anything(), expect.objectContaining({ userId: 'u1', businessId: 'b1' }));
      expect(result.currentPoints).toBe(1);
    });

    it('un local que no existe se rechaza', async () => {
      transactionManager.findOne.mockResolvedValue(null);

      await expect(service.grantBonusPoints('u1', 'nada', 1)).rejects.toThrow('Negocio no encontrado');
    });
  });

  describe('historial de una tarjeta', () => {
    it('trae la insignia del cliente en ese local', async () => {
      cardRepo.findOne.mockResolvedValue({
        id: 'c1',
        userId: 'u1',
        businessId: 'b1',
        business: { ownerId: 'owner-1' },
        user: { id: 'u1' },
      });
      counts = [{ key: 'b1', count: '3' }];

      const history = await service.getCardHistory('c1', 'u1', UserRole.CLIENT);

      expect(history.fidely).toEqual({ verifiedScans: 3, fidelyRequired: 3, isFidely: true });
    });
  });
});
