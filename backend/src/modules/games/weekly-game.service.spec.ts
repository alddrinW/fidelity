import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { GameInvite } from '../../database/entities/game-invite.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { LoyaltyCardsService } from '../loyalty-cards/loyalty-cards.service';
import { NotificationsService } from '../notifications/notifications.service';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { SettingsService } from '../settings/settings.service';
import { fakeSettings } from '../settings/settings.testing';
import { GAME_KEYS } from './games.logic';
import { WeeklyGameService } from './weekly-game.service';
import { weekOf } from './weekly-game.utils';

// Miércoles 21 de octubre de 2026, 12:00 en Ecuador: semana del lunes 2026-10-19.
const NOW = new Date('2026-10-21T17:00:00Z');
const WEEK = weekOf(NOW);

describe('WeeklyGameService', () => {
  let service: WeeklyGameService;
  let inviteRepo: any;
  let cardRepo: any;
  let loyalty: any;
  let notifications: any;
  let settings: any;

  const card = (businessId: string, extra: any = {}, businessExtra: any = {}) => ({
    userId: 'u1',
    businessId,
    currentPoints: 3,
    business: { id: businessId, name: `Local ${businessId}`, logoUrl: null, isActive: true, pointsRequired: 10, ...businessExtra },
    ...extra,
  });

  const win = (businessId: string) => ({ businessId, finishedAt: new Date() });

  const thisWeek = (extra: any = {}): any => ({
    id: 'w1',
    userId: 'u1',
    businessId: 'a',
    game: 'hangman',
    status: 'sent',
    result: null,
    attempts: 0,
    weekly: true,
    weekStart: WEEK.key,
    business: { name: 'Local a' },
    ...extra,
  });

  beforeEach(async () => {
    inviteRepo = {
      findOne: jest.fn().mockResolvedValue(null),
      find: jest.fn().mockResolvedValue([]),
      create: jest.fn((d) => ({ id: 'w-new', ...d })),
      save: jest.fn(async (x) => x),
    };
    cardRepo = { find: jest.fn().mockResolvedValue([card('a'), card('b'), card('c')]) };
    loyalty = { grantBonusPoints: jest.fn().mockResolvedValue({ cardId: 'card-1', currentPoints: 4, newRewards: 0 }) };
    notifications = {
      sendToUser: jest.fn().mockResolvedValue(true),
      sendToBusinessOwner: jest.fn().mockResolvedValue(true),
    };
    settings = fakeSettings({ [SETTING_KEYS.weeklyGameEnabled]: 1 });

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WeeklyGameService,
        { provide: getRepositoryToken(GameInvite), useValue: inviteRepo },
        { provide: getRepositoryToken(LoyaltyCard), useValue: cardRepo },
        { provide: LoyaltyCardsService, useValue: loyalty },
        { provide: NotificationsService, useValue: notifications },
        { provide: SettingsService, useValue: settings },
      ],
    }).compile();
    service = module.get(WeeklyGameService);
  });

  describe('status', () => {
    it('apagado por el administrador: no hay juego', async () => {
      settings.get.mockResolvedValue(0);

      const status = await service.status('u1', NOW);

      expect(status).toMatchObject({ enabled: false, state: 'off', businesses: [] });
      expect(cardRepo.find).not.toHaveBeenCalled();
    });

    it('sin haber jugado: disponible, con los negocios donde es cliente', async () => {
      const status: any = await service.status('u1', NOW);

      expect(status).toMatchObject({ enabled: true, state: 'available', weekStart: '2026-10-19', current: null, points: 1 });
      expect(status.nextAt).toEqual(WEEK.endsAt);
      expect(status.businesses.map((b: any) => [b.id, b.blocked])).toEqual([['a', false], ['b', false], ['c', false]]);
      expect(status.businesses[0]).toMatchObject({ name: 'Local a', currentPoints: 3, pointsRequired: 10 });
    });

    it('el negocio donde ya ganó sale bloqueado y va al final de la lista', async () => {
      inviteRepo.find.mockResolvedValue([win('a')]);

      const status: any = await service.status('u1', NOW);

      expect(status.businesses.map((b: any) => [b.id, b.blocked])).toEqual([['b', false], ['c', false], ['a', true]]);
    });

    it('consulta los juegos ganados de siempre, no solo los de esta semana', async () => {
      await service.status('u1', NOW);

      expect(inviteRepo.find.mock.calls[0][0].where).toEqual({ userId: 'u1', weekly: true, result: 'won' });
      expect(inviteRepo.find.mock.calls[0][0].order).toEqual({ finishedAt: 'ASC' });
    });

    it('al ganar en todos los negocios, la lista se abre de nuevo', async () => {
      inviteRepo.find.mockResolvedValue([win('a'), win('b'), win('c')]);

      const status: any = await service.status('u1', NOW);

      expect(status.businesses.every((b: any) => !b.blocked)).toBe(true);
    });

    it('un local desactivado o donde no es cliente no sale para elegir', async () => {
      cardRepo.find.mockResolvedValue([card('a'), card('b', {}, { isActive: false })]);

      const status: any = await service.status('u1', NOW);

      expect(status.businesses.map((b: any) => b.id)).toEqual(['a']);
    });

    it('sin ningún negocio donde ser cliente: "empty"', async () => {
      cardRepo.find.mockResolvedValue([]);

      expect((await service.status('u1', NOW)).state).toBe('empty');
    });

    it('ya eligió y le falta jugar: "playing", con el reto para retomarlo', async () => {
      inviteRepo.findOne.mockResolvedValue(thisWeek());

      const status: any = await service.status('u1', NOW);

      expect(status.state).toBe('playing');
      expect(status.current).toMatchObject({ inviteId: 'w1', businessId: 'a', businessName: 'Local a', gameName: 'Ahorcado', canChange: true });
    });

    it('con el primer intento en curso ya no puede cambiar de negocio', async () => {
      inviteRepo.findOne.mockResolvedValue(thisWeek({ status: 'playing', attempts: 1 }));

      expect(((await service.status('u1', NOW)) as any).current.canChange).toBe(false);
    });

    it('ya jugó (ganó o perdió): "done" hasta el lunes', async () => {
      inviteRepo.findOne.mockResolvedValue(thisWeek({ status: 'finished', result: 'won', attempts: 1 }));

      const status: any = await service.status('u1', NOW);

      expect(status.state).toBe('done');
      expect(status.current.result).toBe('won');
    });

    it('los puntos que da los fija el administrador', async () => {
      settings.get.mockImplementation(async (key: string) => (key === SETTING_KEYS.weeklyGamePoints ? 2 : 1));

      expect(((await service.status('u1', NOW)) as any).points).toBe(2);
    });
  });

  describe('start (elegir negocio y jugar)', () => {
    it('crea el juego de la semana en el negocio elegido, hasta el domingo', async () => {
      const result = await service.start('u1', 'b', NOW);

      const saved = inviteRepo.create.mock.calls[0][0];
      expect(saved).toMatchObject({
        businessId: 'b',
        userId: 'u1',
        sentById: null,
        status: 'sent',
        weekly: true,
        weekStart: '2026-10-19',
        startsAt: NOW,
        notifiedAt: NOW,
      });
      expect(saved.expiresAt).toEqual(WEEK.endsAt);
      expect(GAME_KEYS).toContain(saved.game);
      expect(result).toEqual({ inviteId: 'w-new', game: saved.game });
    });

    it('el juego de la semana es siempre el mismo para la misma persona', async () => {
      await service.start('u1', 'a', NOW);
      await service.start('u1', 'b', NOW);

      expect(inviteRepo.create.mock.calls[0][0].game).toBe(inviteRepo.create.mock.calls[1][0].game);
    });

    it('apagado: no se puede jugar', async () => {
      settings.get.mockResolvedValue(0);

      await expect(service.start('u1', 'a', NOW)).rejects.toThrow('no está disponible');
      expect(inviteRepo.save).not.toHaveBeenCalled();
    });

    it('solo en negocios donde tiene tarjeta', async () => {
      await expect(service.start('u1', 'zzz', NOW)).rejects.toThrow('donde tienes tarjeta');
    });

    it('un negocio donde ya ganó no se puede elegir', async () => {
      inviteRepo.find.mockResolvedValue([win('a')]);

      await expect(service.start('u1', 'a', NOW)).rejects.toThrow('Ya ganaste un punto en este negocio');
      expect(inviteRepo.save).not.toHaveBeenCalled();
      // pero sí otro
      await expect(service.start('u1', 'b', NOW)).resolves.toBeDefined();
    });

    it('ya jugó esta semana: vuelve el lunes', async () => {
      inviteRepo.findOne.mockResolvedValue(thisWeek({ status: 'finished', result: 'lost', attempts: 3 }));

      await expect(service.start('u1', 'b', NOW)).rejects.toThrow('Vuelve el lunes');
      expect(inviteRepo.save).not.toHaveBeenCalled();
    });

    it('volver a elegir el mismo negocio retoma el juego, sin crear otro', async () => {
      inviteRepo.findOne.mockResolvedValue(thisWeek());

      const result = await service.start('u1', 'a', NOW);

      expect(result).toEqual({ inviteId: 'w1', game: 'hangman' });
      expect(inviteRepo.create).not.toHaveBeenCalled();
    });

    it('antes de jugar puede cambiar de negocio', async () => {
      const existing = thisWeek();
      inviteRepo.findOne.mockResolvedValue(existing);

      const result = await service.start('u1', 'c', NOW);

      expect(existing.businessId).toBe('c');
      expect(inviteRepo.save).toHaveBeenCalledWith(existing);
      expect(result.inviteId).toBe('w1');
    });

    it('después de empezar a jugar ya no puede cambiar de negocio', async () => {
      inviteRepo.findOne.mockResolvedValue(thisWeek({ status: 'playing', attempts: 1 }));

      await expect(service.start('u1', 'c', NOW)).rejects.toBeInstanceOf(BadRequestException);
      expect(inviteRepo.save).not.toHaveBeenCalled();
    });

    it('al cambiar de negocio tampoco puede elegir uno bloqueado', async () => {
      inviteRepo.findOne.mockResolvedValue(thisWeek());
      inviteRepo.find.mockResolvedValue([win('c')]);

      await expect(service.start('u1', 'c', NOW)).rejects.toThrow('Ya ganaste un punto');
    });

    it('dos toques seguidos no crean dos juegos: se devuelve el que ya existe', async () => {
      inviteRepo.save.mockRejectedValueOnce({ code: '23505' });
      inviteRepo.findOne.mockResolvedValueOnce(null).mockResolvedValueOnce(thisWeek({ businessId: 'b' }));

      const result = await service.start('u1', 'b', NOW);

      expect(result.inviteId).toBe('w1');
    });

    it('otro error al guardar se muestra', async () => {
      inviteRepo.save.mockRejectedValueOnce(new Error('db caída'));

      await expect(service.start('u1', 'b', NOW)).rejects.toThrow('db caída');
    });
  });

  describe('awardPoint (ganó el juego)', () => {
    const won = (extra: any = {}): any => ({
      id: 'w1',
      userId: 'u1',
      businessId: 'a',
      business: { name: 'Café Aurora' },
      user: { fullName: 'Ana Paz' },
      ...extra,
    });

    it('suma los puntos del administrador en el negocio elegido', async () => {
      await service.awardPoint(won());

      expect(loyalty.grantBonusPoints).toHaveBeenCalledWith('u1', 'a', 1);
    });

    it('con 2 puntos configurados suma 2', async () => {
      settings.get.mockImplementation(async (key: string) => (key === SETTING_KEYS.weeklyGamePoints ? 2 : 1));

      await service.awardPoint(won());

      expect(loyalty.grantBonusPoints).toHaveBeenCalledWith('u1', 'a', 2);
      expect(notifications.sendToUser).toHaveBeenCalledWith('u1', expect.any(String), expect.stringContaining('2 puntos en Café Aurora'), expect.anything());
    });

    it('avisa al cliente y al dueño', async () => {
      await service.awardPoint(won());

      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'u1',
        '¡Ganaste tu juego de la semana!',
        'Sumaste 1 punto en Café Aurora. La próxima semana juega en otro negocio.',
        expect.objectContaining({ type: 'weekly_game_won' }),
      );
      expect(notifications.sendToBusinessOwner).toHaveBeenCalledWith(
        'a',
        '¡Un cliente ganó un punto jugando!',
        'Ana Paz ganó 1 punto con el juego semanal de Fidelity.',
        expect.anything(),
      );
    });

    it('si con el punto completa su tarjeta, se lo dice', async () => {
      loyalty.grantBonusPoints.mockResolvedValue({ cardId: 'card-1', currentPoints: 0, newRewards: 1 });

      await service.awardPoint(won());

      expect(notifications.sendToUser).toHaveBeenCalledWith('u1', '¡Completaste tu tarjeta!', expect.stringContaining('Café Aurora'), expect.anything());
    });

    it('un aviso que falla no deshace el punto', async () => {
      notifications.sendToUser.mockRejectedValue(new Error('fcm caído'));

      await expect(service.awardPoint(won())).resolves.toBeUndefined();
      expect(loyalty.grantBonusPoints).toHaveBeenCalled();
    });

    it('si no se pudieron sumar los puntos, el error sale (no se avisa de algo que no pasó)', async () => {
      loyalty.grantBonusPoints.mockRejectedValue(new Error('sin negocio'));

      await expect(service.awardPoint(won())).rejects.toThrow('sin negocio');
      expect(notifications.sendToUser).not.toHaveBeenCalled();
    });
  });

  describe('prizeLabel', () => {
    it('"1 punto en X" y en plural', async () => {
      expect(await service.prizeLabel('Café Aurora')).toBe('1 punto en Café Aurora');
      settings.get.mockImplementation(async (key: string) => (key === SETTING_KEYS.weeklyGamePoints ? 3 : 1));
      expect(await service.prizeLabel('Café Aurora')).toBe('3 puntos en Café Aurora');
      expect(await service.prizeLabel(null)).toBe('3 puntos en el negocio');
    });
  });
});
