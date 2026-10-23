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
