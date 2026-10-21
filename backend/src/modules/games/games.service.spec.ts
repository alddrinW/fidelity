import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import {
  GamesService,
  INVITE_TTL_MS,
  MAX_GAME_ATTEMPTS,
  MAX_INVITE_WINDOW_MS,
  resolveGameWindow,
} from './games.service';
import { GameAccess } from '../../database/entities/game-access.entity';
import { GameInvite } from '../../database/entities/game-invite.entity';
import { Campaign } from '../../database/entities/campaign.entity';
import { CampaignBusiness } from '../../database/entities/campaign-business.entity';
import { CampaignClaim } from '../../database/entities/campaign-claim.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { UserRole } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { BusinessAccessService } from '../businesses/business-access.service';
import { FLAPPY_MIN_MS_PER_PIPE, FLAPPY_TARGET } from './games.logic';

const owner = { id: 'owner-1', role: UserRole.BUSINESS };
const admin = { id: 'admin-1', role: UserRole.ADMIN };

describe('GamesService', () => {
  let service: GamesService;
  let accessRepo: any;
  let inviteRepo: any;
  let campaignRepo: any;
  let participantRepo: any;
  let claimRepo: any;
  let businessRepo: any;
  let cardRepo: any;
  let notifications: any;
  let access: any;

  const business = (extra: any = {}) => ({
    id: 'b1',
    name: 'Café Aurora',
    ownerId: 'owner-1',
    isActive: true,
    ...extra,
  });

  const approved = (extra: any = {}): any => ({
    id: 'a1',
    businessId: 'b1',
    ownerId: 'owner-1',
    status: 'approved',
    games: ['tictactoe', 'hangman', 'flappy'],
    prizeType: 'discount_percent',
    prizeValue: 20,
    prizeLabel: '20% de descuento',
    prizeCampaigns: { tictactoe: 'c-ttt', hangman: 'c-hang', flappy: 'c-flap' },
    ...extra,
  });

  const invite = (extra: any = {}): any => ({
    id: 'i1',
    businessId: 'b1',
    userId: 'u1',
    game: 'hangman',
    status: 'sent',
    result: null,
    score: null,
    state: null,
    claimId: null,
    startsAt: new Date(Date.now() - 1000),
    expiresAt: new Date(Date.now() + INVITE_TTL_MS),
    attempts: extra.status && extra.status !== 'sent' ? 1 : 0,
    startedAt: null,
    business: business(),
    user: { id: 'u1', fullName: 'Ana Paz', email: 'ana@mail.com' },
    ...extra,
  });

  beforeEach(async () => {
    accessRepo = {
      create: jest.fn((d) => ({ id: 'a1', ...d })),
      save: jest.fn((a) => Promise.resolve({ requestedAt: new Date(), ...a })),
      findOne: jest.fn().mockResolvedValue(null),
      find: jest.fn().mockResolvedValue([]),
    };
    inviteRepo = {
      create: jest.fn((d) => ({ id: `i-${d.userId}`, ...d })),
      save: jest.fn((x) => Promise.resolve(x)),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
      findOne: jest.fn(),
      find: jest.fn().mockResolvedValue([]),
    };
    campaignRepo = {
      create: jest.fn((d) => d),
      save: jest.fn((c) => Promise.resolve({ id: `camp-${c.title}`, ...c })),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    participantRepo = {
      create: jest.fn((d) => d),
      save: jest.fn((p) => Promise.resolve(p)),
    };
    claimRepo = {
      create: jest.fn((d) => d),
      save: jest.fn((c) => Promise.resolve({ id: 'claim-1', ...c })),
      find: jest.fn().mockResolvedValue([]),
      findOne: jest.fn().mockResolvedValue(null),
    };
    businessRepo = { findOne: jest.fn().mockResolvedValue(business()) };
    cardRepo = { find: jest.fn().mockResolvedValue([{ userId: 'u1' }, { userId: 'u2' }]) };
    notifications = {
      sendToUser: jest.fn().mockResolvedValue(true),
      sendToBusinessOwner: jest.fn().mockResolvedValue(true),
      broadcastToAdmins: jest.fn().mockResolvedValue(undefined),
    };
    access = { canManage: jest.fn().mockResolvedValue(true) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        GamesService,
        { provide: getRepositoryToken(GameAccess), useValue: accessRepo },
        { provide: getRepositoryToken(GameInvite), useValue: inviteRepo },
        { provide: getRepositoryToken(Campaign), useValue: campaignRepo },
        { provide: getRepositoryToken(CampaignBusiness), useValue: participantRepo },
        { provide: getRepositoryToken(CampaignClaim), useValue: claimRepo },
        { provide: getRepositoryToken(Business), useValue: businessRepo },
        { provide: getRepositoryToken(LoyaltyCard), useValue: cardRepo },
        { provide: NotificationsService, useValue: notifications },
        { provide: BusinessAccessService, useValue: access },
      ],
    }).compile();
    service = module.get(GamesService);
  });

  describe('solicitud del dueño', () => {
    it('crea la solicitud pendiente y avisa a los administradores', async () => {
      const view = await service.request(owner, { businessId: 'b1', note: ' Quiero atraer clientes ' });

      expect(view.status).toBe('pending');
      expect(view.note).toBe('Quiero atraer clientes');
      expect(notifications.broadcastToAdmins).toHaveBeenCalledWith(
        'Solicitud de minijuegos',
        expect.stringContaining('Café Aurora'),
        '/admin_games',
      );
    });

    it('solo el dueño del negocio puede pedirlos', async () => {
      access.canManage.mockResolvedValue(false);

      await expect(service.request(owner, { businessId: 'b1' })).rejects.toBeInstanceOf(ForbiddenException);
      expect(accessRepo.save).not.toHaveBeenCalled();
    });

    it('un negocio inexistente o inactivo no puede pedirlos', async () => {
      businessRepo.findOne.mockResolvedValue(null);
      await expect(service.request(owner, { businessId: 'x' })).rejects.toBeInstanceOf(NotFoundException);

      businessRepo.findOne.mockResolvedValue(business({ isActive: false }));
      await expect(service.request(owner, { businessId: 'b1' })).rejects.toThrow('debe estar activo');
    });

    it('no se pide dos veces ni cuando ya están aprobados', async () => {
      accessRepo.findOne.mockResolvedValue(approved());
      await expect(service.request(owner, { businessId: 'b1' })).rejects.toThrow('ya tiene los minijuegos');

      accessRepo.findOne.mockResolvedValue({ status: 'pending' });
      await expect(service.request(owner, { businessId: 'b1' })).rejects.toThrow('en revisión');
    });

    it('tras un rechazo se puede volver a pedir y se limpia el motivo', async () => {
      const rejected = { id: 'a1', businessId: 'b1', status: 'rejected', adminNote: 'Aún no' };
      accessRepo.findOne.mockResolvedValue(rejected);

      const view = await service.request(owner, { businessId: 'b1' });

      expect(view.status).toBe('pending');
      expect(view.adminNote).toBeNull();
      expect(accessRepo.create).not.toHaveBeenCalled(); // reutiliza la misma fila
    });

    it('el dueño consulta su estado; sin solicitud es "none"', async () => {
      expect(await service.getAccess(owner, 'b1')).toEqual({ status: 'none', games: [], prize: null });

      accessRepo.findOne.mockResolvedValue(approved());
      const view: any = await service.getAccess(owner, 'b1');
      expect(view.games).toHaveLength(3);
      expect(view.prize.label).toBe('20% de descuento');

      access.canManage.mockResolvedValue(false);
      await expect(service.getAccess(owner, 'b1')).rejects.toBeInstanceOf(ForbiddenException);
    });
  });

  describe('decisión del administrador', () => {
    const dto = (extra: any = {}) => ({
      games: ['tictactoe', 'hangman', 'flappy'],
      prizeType: 'discount_percent' as const,
      prizeValue: 20,
      ...extra,
    });

    beforeEach(() => {
      accessRepo.findOne.mockResolvedValue({ id: 'a1', businessId: 'b1', status: 'pending', business: business() });
    });

    it('aprueba: asigna los juegos, fija el premio y crea una gift card oculta por juego', async () => {
      const view = await service.approve('admin-1', 'a1', dto());

      expect(view.status).toBe('approved');
      expect(view.games).toEqual(['tictactoe', 'hangman', 'flappy']);
      expect(view.prize).toEqual({ type: 'discount_percent', value: 20, label: '20% de descuento' });
      expect(campaignRepo.save).toHaveBeenCalledTimes(3);
      const created = campaignRepo.create.mock.calls[0][0];
      expect(created).toMatchObject({
        businessId: 'b1',
        type: 'gift_card',
        audience: 'selected',
        benefitLabel: '20% de descuento',
        // no sale en las listas del dueño
        hidden: true,
      });
      // "ya avisada": jamás se manda como campaña
      expect(created.notifiedAt).toBeInstanceOf(Date);
      expect(participantRepo.save).toHaveBeenCalledTimes(3);
      const saved = accessRepo.save.mock.calls[0][0];
      expect(Object.keys(saved.prizeCampaigns).sort()).toEqual(['flappy', 'hangman', 'tictactoe']);
    });

    it('avisa al dueño', async () => {
      await service.approve('admin-1', 'a1', dto({ games: ['hangman'] }));

      expect(notifications.sendToBusinessOwner).toHaveBeenCalledWith(
        'b1',
        '¡Minijuegos activados!',
        expect.stringContaining('Ahorcado'),
        expect.objectContaining({ type: 'games_approved' }),
      );
    });

    it('un mini premio usa su descripción', async () => {
      const view = await service.approve(
        'admin-1',
        'a1',
        dto({ prizeType: 'mini_prize', prizeValue: undefined, prizeLabel: ' Café gratis ' }),
      );

      expect(view.prize).toEqual({ type: 'mini_prize', value: null, label: 'Café gratis' });
    });

    it('exige el porcentaje o la descripción del premio', async () => {
      await expect(service.approve('admin-1', 'a1', dto({ prizeValue: undefined }))).rejects.toThrow('porcentaje');
      await expect(
        service.approve('admin-1', 'a1', dto({ prizeType: 'mini_prize', prizeValue: undefined })),
      ).rejects.toThrow('mini premio');
      expect(accessRepo.save).not.toHaveBeenCalled();
    });

    it('al cambiar el premio actualiza las gift cards que ya existían, no crea otras', async () => {
      accessRepo.findOne.mockResolvedValue(approved({ business: business() }));

      await service.approve('admin-1', 'a1', dto({ prizeValue: 35 }));

      expect(campaignRepo.save).not.toHaveBeenCalled();
      expect(campaignRepo.update).toHaveBeenCalledWith(
        { id: 'c-ttt' },
        expect.objectContaining({ benefitValue: 35, benefitLabel: '35% de descuento', cancelledAt: null }),
      );
      expect(notifications.sendToBusinessOwner.mock.calls[0][1]).toBe('Tus minijuegos cambiaron');
    });

    it('una solicitud inexistente da 404', async () => {
      accessRepo.findOne.mockResolvedValue(null);

      await expect(service.approve('admin-1', 'zzz', dto())).rejects.toBeInstanceOf(NotFoundException);
    });

    it('rechaza con un motivo y avisa al dueño', async () => {
      const view = await service.reject('admin-1', 'a1', ' Aún no ');

      expect(view.status).toBe('rejected');
      expect(view.adminNote).toBe('Aún no');
      expect(notifications.sendToBusinessOwner).toHaveBeenCalledWith(
        'b1',
        'Solicitud de minijuegos',
        expect.stringContaining('Aún no'),
        expect.objectContaining({ type: 'games_rejected' }),
      );
    });

    it('quitar unos juegos ya aprobados cancela sus gift cards de premio', async () => {
      accessRepo.findOne.mockResolvedValue(approved());

      const view = await service.reject('admin-1', 'a1', 'Se terminó el convenio');

      expect(campaignRepo.update).toHaveBeenCalledWith(
        { id: expect.anything() },
        { cancelledAt: expect.any(Date) },
      );
      expect(view.games).toEqual([]);
      expect(view.prize).toBeNull();
    });

    it('lista las solicitudes con el negocio y el dueño', async () => {
      accessRepo.find.mockResolvedValue([
        {
          id: 'a1',
          businessId: 'b1',
          status: 'pending',
          business: { id: 'b1', name: 'Café Aurora', logoUrl: null },
          owner: { fullName: 'Aurora', email: 'a@mail.com', phone: '099' },
        },
      ]);

      const [row]: any[] = await service.listRequests('pending');

      expect(accessRepo.find).toHaveBeenCalledWith(expect.objectContaining({ where: { status: 'pending' } }));
      expect(row.business.name).toBe('Café Aurora');
      expect(row.owner.email).toBe('a@mail.com');
    });
  });

  describe('horario de un reto', () => {
    const now = new Date('2026-10-21T15:00:00Z');
    const at = (minutes: number) => new Date(now.getTime() + minutes * 60_000).toISOString();

    it('sin horario empieza ya y dura 7 días', () => {
      const w = resolveGameWindow(undefined, undefined, now);

      expect(w.startsAt).toEqual(now);
      expect(w.endsAt.getTime()).toBe(now.getTime() + INVITE_TTL_MS);
    });

    it('respeta el inicio y el fin que pone el dueño', () => {
      const w = resolveGameWindow(at(60), at(180), now);

      expect(w.startsAt.toISOString()).toBe(at(60));
      expect(w.endsAt.toISOString()).toBe(at(180));
    });

    it('con inicio y sin fin, dura 7 días desde el inicio', () => {
      const w = resolveGameWindow(at(60), undefined, now);

      expect(w.endsAt.getTime()).toBe(now.getTime() + 60 * 60_000 + INVITE_TTL_MS);
    });

    it('un inicio unos minutos atrás se toma como ahora; mucho atrás se rechaza', () => {
      expect(resolveGameWindow(at(-3), undefined, now).startsAt).toEqual(now);
      expect(() => resolveGameWindow(at(-30), undefined, now)).toThrow('ya pasó');
    });

    it('el fin debe ser después del inicio y en el futuro', () => {
      expect(() => resolveGameWindow(at(60), at(30), now)).toThrow('después de la hora de inicio');
      expect(() => resolveGameWindow(at(10), at(10), now)).toThrow('después de la hora de inicio');
      expect(() => resolveGameWindow(undefined, at(-1), now)).toThrow('después de la hora de inicio');
    });

    it('no puede durar más de 90 días', () => {
      const tooLong = new Date(now.getTime() + MAX_INVITE_WINDOW_MS + 60_000).toISOString();

      expect(() => resolveGameWindow(undefined, tooLong, now)).toThrow('90 días');
    });

    it('una fecha ilegible se rechaza', () => {
      expect(() => resolveGameWindow('mañana', undefined, now)).toThrow('inicio no es válida');
      expect(() => resolveGameWindow(undefined, 'luego', now)).toThrow('fin no es válida');
    });
  });

  describe('mandar un juego', () => {
    // Lo que se guardó, para que la búsqueda de "avisos pendientes" lo encuentre.
    let saved: any[];
    let open: any[];

    const findImpl = async (opts: any) =>
      opts?.where?.notifiedAt !== undefined
        ? saved
            .filter((i) => i.notifiedAt == null && i.startsAt.getTime() <= Date.now())
            .map((i) => ({ ...i, business: business() }))
        : open;

    beforeEach(() => {
      saved = [];
      open = [];
      accessRepo.findOne.mockResolvedValue(approved());
      accessRepo.find.mockResolvedValue([approved()]);
      inviteRepo.save.mockImplementation(async (x: any) => {
        saved = x;
        return x;
      });
      inviteRepo.find.mockImplementation(findImpl);
    });

    const send = (extra: any = {}) => service.sendInvites(owner, { businessId: 'b1', game: 'hangman', ...extra });

    it('a todos los clientes: un reto por cliente, con su aviso y su enlace', async () => {
      const result = await send();

      expect(result).toMatchObject({ sent: 2, skipped: 0 });
      expect(inviteRepo.save.mock.calls[0][0].map((i: any) => i.userId)).toEqual(['u1', 'u2']);
      const first = inviteRepo.save.mock.calls[0][0][0];
      expect(first.expiresAt.getTime()).toBeGreaterThan(Date.now() + INVITE_TTL_MS - 5000);
      expect(notifications.sendToUser).toHaveBeenCalledTimes(2);
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'u1',
        'Café Aurora te reta a jugar',
        expect.stringMatching(/^Juega Ahorcado y gana: 20% de descuento\. Tienes 3 intentos hasta el /),
        { type: 'game_invite', route: '/play_game', invite_id: 'i-u1', game: 'hangman' },
      );
    });

    it('con horario: guarda el inicio y el fin, y avisa ya si empieza ya', async () => {
      const startsAt = new Date(Date.now() + 1000).toISOString();
      const endsAt = new Date(Date.now() + 3 * 3600_000).toISOString();

      const result = await send({ startsAt, endsAt });

      const invite = inviteRepo.save.mock.calls[0][0][0];
      expect(invite.startsAt.toISOString()).toBe(startsAt);
      expect(invite.expiresAt.toISOString()).toBe(endsAt);
      expect(result.endsAt.toISOString()).toBe(endsAt);
    });

    it('si empieza más tarde, no avisa ahora: avisa el programador a la hora de inicio', async () => {
      const startsAt = new Date(Date.now() + 2 * 3600_000);
      const endsAt = new Date(Date.now() + 5 * 3600_000);

      const result = await send({ startsAt: startsAt.toISOString(), endsAt: endsAt.toISOString() });

      expect(result.sent).toBe(2);
      expect(notifications.sendToUser).not.toHaveBeenCalled();

      // Llega la hora de inicio: ahora sí se avisa, una sola vez por cliente.
      const later = new Date(startsAt.getTime() + 1000);
      jest.useFakeTimers({ now: later });
      try {
        expect(await service.notifyDue(later)).toBe(2);
        expect(notifications.sendToUser).toHaveBeenCalledTimes(2);
        expect(inviteRepo.update).toHaveBeenCalledWith(
          expect.objectContaining({ id: 'i-u1' }),
          { notifiedAt: later },
        );
      } finally {
        jest.useRealTimers();
      }
    });

    it('un aviso ya tomado por otra pasada no se manda dos veces', async () => {
      await send({ startsAt: new Date(Date.now() + 1000).toISOString() });
      notifications.sendToUser.mockClear();
      inviteRepo.update.mockResolvedValue({ affected: 0 });
      // Que "ya empezó" aunque falte un instante para la hora de inicio.
      saved.forEach((i) => (i.startsAt = new Date(Date.now() - 1)));

      expect(await service.notifyDue()).toBe(0);
      expect(notifications.sendToUser).not.toHaveBeenCalled();
    });

    it('rechaza un horario imposible sin guardar nada', async () => {
      await expect(
        send({ startsAt: new Date(Date.now() + 3600_000).toISOString(), endsAt: new Date(Date.now() + 1800_000).toISOString() }),
      ).rejects.toThrow('después de la hora de inicio');
      expect(inviteRepo.save).not.toHaveBeenCalled();
    });

    it('solo a los clientes elegidos', async () => {
      const result = await send({ audience: 'selected', recipientIds: ['u2'] });

      expect(result.sent).toBe(1);
      expect(notifications.sendToUser.mock.calls[0][0]).toBe('u2');
    });

    it('elegidos: exige al menos uno y que sean clientes del negocio', async () => {
      await expect(send({ audience: 'selected', recipientIds: [] })).rejects.toThrow('al menos un cliente');
      await expect(send({ audience: 'selected', recipientIds: ['u1', 'extraño'] })).rejects.toThrow('no son clientes');
      expect(inviteRepo.save).not.toHaveBeenCalled();
    });

    it('se salta a quien ya tiene ese juego pendiente', async () => {
      open = [{ userId: 'u1' }];

      const result = await send();

      expect(result).toMatchObject({ sent: 1, skipped: 1 });
      expect(inviteRepo.save.mock.calls[0][0].map((i: any) => i.userId)).toEqual(['u2']);
    });

    it('se salta a quien ya ganó el premio de ese juego', async () => {
      claimRepo.find.mockResolvedValue([{ userId: 'u2' }]);

      const result = await send();

      expect(result).toMatchObject({ sent: 1, skipped: 1 });
      expect(claimRepo.find).toHaveBeenCalledWith(
        expect.objectContaining({ where: expect.objectContaining({ campaignId: 'c-hang' }) }),
      );
    });

    it('sin clientes no hay a quién mandarlo', async () => {
      cardRepo.find.mockResolvedValue([]);

      await expect(send()).rejects.toThrow('Todavía no tienes clientes');
    });

    it('exige minijuegos aprobados y que el juego esté asignado', async () => {
      accessRepo.findOne.mockResolvedValue(null);
      await expect(send()).rejects.toThrow('todavía no tiene minijuegos');

      accessRepo.findOne.mockResolvedValue({ status: 'pending' });
      await expect(send()).rejects.toThrow('todavía no tiene minijuegos');

      accessRepo.findOne.mockResolvedValue(approved({ games: ['tictactoe'] }));
      await expect(send()).rejects.toThrow('no está asignado');
    });

    it('solo quien gestiona el negocio puede mandarlo', async () => {
      access.canManage.mockResolvedValue(false);

      await expect(send()).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('un fallo en un aviso no impide el resto', async () => {
      notifications.sendToUser.mockRejectedValueOnce(new Error('push caído'));

      await expect(send()).resolves.toMatchObject({ sent: 2, skipped: 0 });
      expect(notifications.sendToUser).toHaveBeenCalledTimes(2);
    });

    it('el dueño ve cifras y envíos', async () => {
      const past = new Date(Date.now() - 1000);
      const future = new Date(Date.now() + 1e6);
      inviteRepo.find.mockResolvedValue([
        { id: '1', game: 'hangman', status: 'finished', result: 'won', attempts: 2, user: { fullName: 'Ana' }, startsAt: past, expiresAt: future, createdAt: new Date() },
        { id: '2', game: 'flappy', status: 'sent', result: null, attempts: 1, user: { email: 'luis@mail.com' }, startsAt: past, expiresAt: future, createdAt: new Date() },
        { id: '3', game: 'tictactoe', status: 'sent', result: null, attempts: 0, user: { fullName: 'Zoe' }, startsAt: past, expiresAt: past, createdAt: new Date() },
        { id: '4', game: 'tictactoe', status: 'sent', result: null, attempts: 0, user: { fullName: 'Leo' }, startsAt: future, expiresAt: new Date(Date.now() + 2e6), createdAt: new Date() },
      ]);

      const { stats, items } = await service.listSent(owner, 'b1');

      // "Jugaron" son los que ya usaron al menos un intento.
      expect(stats).toEqual({ sent: 4, played: 2, won: 1 });
      expect(items.map((i) => i.status)).toEqual(['finished', 'sent', 'expired', 'upcoming']);
      expect(items[1]).toMatchObject({ attempts: 1, maxAttempts: MAX_GAME_ATTEMPTS });
      expect(items[0]).toMatchObject({ gameName: 'Ahorcado', userName: 'Ana' });
      expect(items[1].userName).toBe('luis@mail.com');
    });
  });

  describe('partidas', () => {
    beforeEach(() => {
      accessRepo.findOne.mockResolvedValue(approved());
    });

    describe('empezar', () => {
      it('crea el estado inicial de cada juego', async () => {
        for (const [game, check] of [
          ['hangman', (s: any) => typeof s.word === 'string' && s.guessed.length === 0],
          ['tictactoe', (s: any) => s.board.length === 9 && s.board.every((c: string) => c === '')],
          ['flappy', (s: any) => Object.keys(s).length === 0],
        ] as const) {
          const i = invite({ game });
          inviteRepo.findOne.mockResolvedValue(i);

          const view: any = await service.start('u1', 'i1');

          expect(i.status).toBe('playing');
          expect(i.attempts).toBe(1);
          expect(i.startedAt).toBeInstanceOf(Date);
          expect(check(i.state)).toBe(true);
          expect(view.status).toBe('playing');
        }
      });

      it('la vista del ahorcado no revela la palabra', async () => {
        const i = invite({ game: 'hangman' });
        inviteRepo.findOne.mockResolvedValue(i);

        const view: any = await service.start('u1', 'i1');

        expect(view.play.masked.every((c: string) => c === '_')).toBe(true);
        expect(JSON.stringify(view)).not.toContain(i.state.word);
      });

      it('retomar una partida en curso no la reinicia', async () => {
        const i = invite({ game: 'hangman', status: 'playing', state: { word: 'MESA', guessed: ['M'] }, startedAt: new Date() });
        inviteRepo.findOne.mockResolvedValue(i);

        const view: any = await service.start('u1', 'i1');

        expect(view.play.masked).toEqual(['M', '_', '_', '_']);
        expect(inviteRepo.save).not.toHaveBeenCalled();
      });

      it('un reto ajeno no existe para otro cliente', async () => {
        inviteRepo.findOne.mockResolvedValue(invite({ userId: 'otro' }));

        await expect(service.start('u1', 'i1')).rejects.toBeInstanceOf(NotFoundException);
      });

      it('no se juega un reto vencido, ni uno ya ganado, ni uno con los intentos gastados', async () => {
        inviteRepo.findOne.mockResolvedValue(invite({ expiresAt: new Date(Date.now() - 1000) }));
        await expect(service.start('u1', 'i1')).rejects.toThrow('venció');

        inviteRepo.findOne.mockResolvedValue(invite({ status: 'finished', result: 'won' }));
        await expect(service.start('u1', 'i1')).rejects.toThrow('Ya ganaste');

        inviteRepo.findOne.mockResolvedValue(invite({ status: 'finished', result: 'lost', attempts: 3 }));
        await expect(service.start('u1', 'i1')).rejects.toThrow('Ya usaste tus intentos');
      });

      it('no se juega antes de la hora de inicio', async () => {
        const startsAt = new Date(Date.now() + 3600_000);
        inviteRepo.findOne.mockResolvedValue(invite({ startsAt, expiresAt: new Date(startsAt.getTime() + 3600_000) }));

        await expect(service.start('u1', 'i1')).rejects.toThrow('Este juego empieza el');
        expect(inviteRepo.save).not.toHaveBeenCalled();
      });

      it('un Flappy empezado y abandonado hace mucho se da por perdido', async () => {
        const i = invite({ game: 'flappy', status: 'playing', attempts: 3, startedAt: new Date(Date.now() - 11 * 60 * 1000) });
        inviteRepo.findOne.mockResolvedValue(i);

        const view: any = await service.start('u1', 'i1');

        expect(view.result).toBe('lost');
        expect(view.status).toBe('finished');
      });

      it('un Flappy abandonado gasta ese intento, pero deja jugar otro si quedan', async () => {
        const i = invite({ game: 'flappy', status: 'playing', attempts: 1, startedAt: new Date(Date.now() - 11 * 60 * 1000) });
        inviteRepo.findOne.mockResolvedValue(i);

        const view: any = await service.start('u1', 'i1');

        expect(view.status).toBe('sent');
        expect(view.attemptsLeft).toBe(2);
        expect(view.lastAttempt).toBe('lost');
      });
    });

    describe('tres intentos para ganar', () => {
      const hangman = (extra: any = {}) =>
        invite({ game: 'hangman', status: 'playing', startedAt: new Date(), state: { word: 'MESA', guessed: ['B', 'C', 'D', 'F', 'G'] }, ...extra });

      it('perder el primer intento deja otro: el reto sigue abierto y sin premio', async () => {
        const i = hangman({ attempts: 1 });
        inviteRepo.findOne.mockResolvedValue(i);

        const view: any = await service.guess('u1', 'i1', 'h');

        expect(view.status).toBe('sent');
        expect(view.result).toBeNull();
        expect(view.attempts).toBe(1);
        expect(view.attemptsLeft).toBe(2);
        expect(view.lastAttempt).toBe('lost');
        expect(i.state).toBeNull();
        expect(claimRepo.save).not.toHaveBeenCalled();
      });

      it('el siguiente intento empieza una partida nueva y cuenta como el segundo', async () => {
        const i = invite({ game: 'hangman', status: 'sent', attempts: 1 });
        inviteRepo.findOne.mockResolvedValue(i);

        const view: any = await service.start('u1', 'i1');

        expect(view.status).toBe('playing');
        expect(view.attempts).toBe(2);
        expect(view.attemptsLeft).toBe(1);
        expect(view.lastAttempt).toBeNull();
        expect(i.state.guessed).toEqual([]);
      });

      it('perder el tercero termina el reto como perdido', async () => {
        inviteRepo.findOne.mockResolvedValue(hangman({ attempts: 3 }));

        const view: any = await service.guess('u1', 'i1', 'h');

        expect(view.status).toBe('finished');
        expect(view.result).toBe('lost');
        expect(view.attemptsLeft).toBe(0);
      });

      it('se puede ganar en el último intento y recibe el premio', async () => {
        inviteRepo.findOne.mockResolvedValue(
          hangman({ attempts: 3, state: { word: 'MESA', guessed: ['M', 'E', 'S'] } }),
        );

        const view: any = await service.guess('u1', 'i1', 'a');

        expect(view.result).toBe('won');
        expect(view.status).toBe('finished');
        expect(claimRepo.create).toHaveBeenCalledWith(expect.objectContaining({ campaignId: 'c-hang' }));
      });

      it('con intentos gastados no se empieza otro aunque el reto esté "listo"', async () => {
        inviteRepo.findOne.mockResolvedValue(invite({ status: 'sent', attempts: MAX_GAME_ATTEMPTS }));

        await expect(service.start('u1', 'i1')).rejects.toThrow('Ya usaste tus intentos');
      });

      it('una partida en curso no se sigue jugando después de que termina el horario', async () => {
        inviteRepo.findOne.mockResolvedValue(hangman({ attempts: 1, expiresAt: new Date(Date.now() - 1000) }));

        await expect(service.guess('u1', 'i1', 'h')).rejects.toThrow('venció');
      });
    });

    describe('ahorcado', () => {
      const playing = (state: any) =>
        invite({ game: 'hangman', status: 'playing', startedAt: new Date(), state });

      it('acertar no cuenta error', async () => {
        inviteRepo.findOne.mockResolvedValue(playing({ word: 'MESA', guessed: [] }));

        const view: any = await service.guess('u1', 'i1', 'm');

        expect(view.play.masked).toEqual(['M', '_', '_', '_']);
        expect(view.play.wrong).toBe(0);
        expect(view.status).toBe('playing');
      });

      it('completar la palabra gana y entrega la gift card', async () => {
        inviteRepo.findOne.mockResolvedValue(playing({ word: 'MESA', guessed: ['M', 'E', 'S'] }));

        const view: any = await service.guess('u1', 'i1', 'a');

        expect(view.result).toBe('won');
        expect(view.status).toBe('finished');
        expect(claimRepo.create).toHaveBeenCalledWith(
          expect.objectContaining({ campaignId: 'c-hang', userId: 'u1', status: 'active' }),
        );
        expect(claimRepo.create.mock.calls[0][0].code).toMatch(/^GFT-[2-9A-HJ-NP-Z]{6}$/);
        expect(notifications.sendToUser).toHaveBeenCalledWith(
          'u1',
          '¡Ganaste!',
          expect.stringContaining('20% de descuento'),
          { type: 'game_won', route: '/my_gifts' },
        );
        expect(notifications.sendToBusinessOwner).toHaveBeenCalledWith(
          'b1',
          '¡Un cliente ganó!',
          expect.stringContaining('Ana Paz'),
          expect.anything(),
        );
      });

      it('fallar demasiado pierde el intento, no da premio y ahora sí muestra la palabra', async () => {
        inviteRepo.findOne.mockResolvedValue(
          invite({ game: 'hangman', status: 'playing', attempts: 3, startedAt: new Date(), state: { word: 'MESA', guessed: ['B', 'C', 'D', 'F', 'G'] } }),
        );

        const view: any = await service.guess('u1', 'i1', 'h');

        expect(view.result).toBe('lost');
        expect(view.play.word).toBe('MESA');
        expect(claimRepo.save).not.toHaveBeenCalled();
      });

      it('una letra inválida o un reto de otro juego se rechazan', async () => {
        inviteRepo.findOne.mockResolvedValue(playing({ word: 'MESA', guessed: [] }));
        await expect(service.guess('u1', 'i1', '7')).rejects.toThrow('una letra');

        inviteRepo.findOne.mockResolvedValue(invite({ game: 'flappy', status: 'playing' }));
        await expect(service.guess('u1', 'i1', 'a')).rejects.toThrow('otro juego');
      });

      it('no se puede jugar sin empezar ni después de terminar', async () => {
        inviteRepo.findOne.mockResolvedValue(invite({ game: 'hangman', status: 'sent' }));
        await expect(service.guess('u1', 'i1', 'a')).rejects.toThrow('Empieza el juego');

        inviteRepo.findOne.mockResolvedValue(invite({ game: 'hangman', status: 'finished' }));
        await expect(service.guess('u1', 'i1', 'a')).rejects.toThrow('Ya jugaste');
      });
    });

    describe('tres en raya', () => {
      const playing = (board: string[]) =>
        invite({ game: 'tictactoe', status: 'playing', startedAt: new Date(), state: { board, status: 'playing', line: null } });
      const cells = (s: string) => [...s.replace(/\s/g, '')].map((c) => (c === '.' ? '' : c));

      it('una jugada de quien sigue en juego responde la computadora', async () => {
        inviteRepo.findOne.mockResolvedValue(playing(cells('... ... ...')));

        const view: any = await service.move('u1', 'i1', 0);

        expect(view.status).toBe('playing');
        expect(view.play.board[0]).toBe('X');
        expect(view.play.board.filter((c: string) => c === 'O')).toHaveLength(1);
      });

      it('completar una línea gana y entrega la gift card', async () => {
        inviteRepo.findOne.mockResolvedValue(playing(cells('XX. OO. ...')));

        const view: any = await service.move('u1', 'i1', 2);

        expect(view.result).toBe('won');
        expect(view.play.line).toEqual([0, 1, 2]);
        expect(claimRepo.create).toHaveBeenCalledWith(expect.objectContaining({ campaignId: 'c-ttt' }));
      });

      it('una casilla ocupada se rechaza y no cambia nada', async () => {
        inviteRepo.findOne.mockResolvedValue(playing(cells('X.. .O. ...')));

        await expect(service.move('u1', 'i1', 4)).rejects.toThrow('ocupada');
        expect(inviteRepo.save).not.toHaveBeenCalled();
      });
    });

    describe('flappy bird', () => {
      const playing = (msAgo: number) =>
        invite({ game: 'flappy', status: 'playing', attempts: 3, startedAt: new Date(Date.now() - msAgo), state: {} });

      it('con la meta y el tiempo que tomó de verdad, gana', async () => {
        inviteRepo.findOne.mockResolvedValue(playing(FLAPPY_TARGET * FLAPPY_MIN_MS_PER_PIPE + 3000));

        const view: any = await service.finishFlappy('u1', 'i1', { score: FLAPPY_TARGET });

        expect(view.result).toBe('won');
        expect(view.score).toBe(FLAPPY_TARGET);
        expect(claimRepo.create).toHaveBeenCalledWith(expect.objectContaining({ campaignId: 'c-flap' }));
      });

      it('un puntaje alto en pocos segundos es trampa y pierde (el reloj es del servidor)', async () => {
        inviteRepo.findOne.mockResolvedValue(playing(2000));

        const view: any = await service.finishFlappy('u1', 'i1', { score: 500 });

        expect(view.result).toBe('lost');
        expect(claimRepo.save).not.toHaveBeenCalled();
      });

      it('sin llegar a la meta pierde', async () => {
        inviteRepo.findOne.mockResolvedValue(playing(60000));

        const view: any = await service.finishFlappy('u1', 'i1', { score: 3 });

        expect(view.result).toBe('lost');
        expect(view.score).toBe(3);
      });

      it('no se puede enviar un puntaje de otro juego ni dos veces', async () => {
        inviteRepo.findOne.mockResolvedValue(invite({ game: 'hangman', status: 'playing' }));
        await expect(service.finishFlappy('u1', 'i1', { score: 99 })).rejects.toThrow('otro juego');

        inviteRepo.findOne.mockResolvedValue(invite({ game: 'flappy', status: 'finished' }));
        await expect(service.finishFlappy('u1', 'i1', { score: 99 })).rejects.toThrow('Ya jugaste');
      });
    });

    describe('el premio', () => {
      it('ganar el mismo juego otra vez no repite la gift card', async () => {
        claimRepo.findOne.mockResolvedValue({ id: 'ya', code: 'GFT-AAAAAA' });
        inviteRepo.findOne.mockResolvedValue(
          invite({ game: 'hangman', status: 'playing', startedAt: new Date(), state: { word: 'MESA', guessed: ['M', 'E', 'S'] } }),
        );

        const view: any = await service.guess('u1', 'i1', 'a');

        expect(view.result).toBe('won');
        expect(claimRepo.save).not.toHaveBeenCalled();
        expect(notifications.sendToUser).not.toHaveBeenCalled();
      });

      it('sin premio configurado se gana igual, pero no hay gift card', async () => {
        accessRepo.findOne.mockResolvedValue(approved({ prizeCampaigns: null }));
        inviteRepo.findOne.mockResolvedValue(
          invite({ game: 'hangman', status: 'playing', startedAt: new Date(), state: { word: 'MESA', guessed: ['M', 'E', 'S'] } }),
        );

        const view: any = await service.guess('u1', 'i1', 'a');

        expect(view.result).toBe('won');
        expect(claimRepo.save).not.toHaveBeenCalled();
      });

      it('la partida ganada muestra el código de su gift card', async () => {
        claimRepo.findOne.mockResolvedValue({ id: 'claim-1', code: 'GFT-ZZ9988' });
        inviteRepo.findOne.mockResolvedValue(invite({ status: 'finished', result: 'won', claimId: 'claim-1' }));

        const view: any = await service.getInvite('u1', 'i1');

        expect(view.claimCode).toBe('GFT-ZZ9988');
      });
    });

    it('mis retos: con el negocio, el premio y el estado (vencidos como "expired")', async () => {
      inviteRepo.find.mockResolvedValue([
        invite({ id: 'x1' }),
        invite({ id: 'x2', expiresAt: new Date(Date.now() - 1000) }),
        invite({ id: 'x3', status: 'finished', result: 'won' }),
        invite({ id: 'x4', startsAt: new Date(Date.now() + 3600_000), expiresAt: new Date(Date.now() + 7200_000) }),
      ]);
      accessRepo.find.mockResolvedValue([approved()]);

      const list: any[] = await service.myInvites('u1');

      expect(list.map((i) => i.status)).toEqual(['sent', 'expired', 'finished', 'upcoming']);
      expect(list[0]).toMatchObject({ attempts: 0, maxAttempts: 3, attemptsLeft: 3 });
      expect(list[2].attemptsLeft).toBe(0);
      expect(list[0]).toMatchObject({ businessId: 'b1', businessName: 'Café Aurora', prizeLabel: '20% de descuento', gameName: 'Ahorcado' });
    });

    it('sin retos no hay nada que consultar', async () => {
      expect(await service.myInvites('u1')).toEqual([]);
      expect(accessRepo.find).not.toHaveBeenCalled();
    });
  });
});
