import { BadRequestException, ConflictException, ForbiddenException } from '@nestjs/common';
import { UserRole } from '../../database/entities/profile.entity';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { fakeSettings } from '../settings/settings.testing';
import { BirthdaysService } from './birthdays.service';

const owner = { id: 'owner-1', role: UserRole.BUSINESS };
const admin = { id: 'admin-1', role: UserRole.ADMIN };

// 22/10/2026 a las 10:00 en Ecuador.
const NOW = new Date('2026-10-22T15:00:00Z');

const business = (extra: any = {}) => ({ id: 'b1', name: 'Café Aurora', ownerId: 'owner-1', isActive: true, ...extra });
const person = (id: string, birthDate: string | null, extra: any = {}) => ({
  id,
  email: `${id}@mail.com`,
  fullName: `Persona ${id}`,
  avatarUrl: null,
  birthDate,
  ...extra,
});
const card = (userId: string, user: any, extra: any = {}) => ({ userId, businessId: 'b1', user, business: business(), ...extra });

describe('BirthdaysService', () => {
  let service: BirthdaysService;
  let profileRepo: any;
  let cardRepo: any;
  let businessRepo: any;
  let noticeRepo: any;
  let notifications: any;
  let campaigns: any;
  let access: any;
  let settings: ReturnType<typeof fakeSettings>;
  let profileQuery: any;
  let insertQuery: any;
  let insertedRows: any[];
  let claimResult: any;

  beforeEach(() => {
    jest.useFakeTimers({
      now: NOW,
      doNotFake: ['nextTick', 'setImmediate', 'setTimeout', 'setInterval', 'clearTimeout', 'clearInterval', 'clearImmediate', 'queueMicrotask', 'performance', 'hrtime'],
    });
    profileQuery = {
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue([]),
    };
    profileRepo = { createQueryBuilder: jest.fn(() => profileQuery) };
    cardRepo = { find: jest.fn().mockResolvedValue([]), findOne: jest.fn().mockResolvedValue(null) };
    businessRepo = {
      find: jest.fn().mockResolvedValue([business()]),
      findOne: jest.fn().mockResolvedValue(business()),
    };
    insertedRows = [];
    claimResult = { raw: [{ id: 'n1' }] };
    insertQuery = {
      insert: jest.fn().mockReturnThis(),
      into: jest.fn().mockReturnThis(),
      values: jest.fn((v) => {
        insertedRows.push(v);
        return insertQuery;
      }),
      orIgnore: jest.fn().mockReturnThis(),
      execute: jest.fn(async () => claimResult),
    };
    noticeRepo = {
      createQueryBuilder: jest.fn(() => insertQuery),
      find: jest.fn().mockResolvedValue([]),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    notifications = { sendToBusinessOwner: jest.fn().mockResolvedValue(true) };
    campaigns = { create: jest.fn().mockResolvedValue({ id: 'camp-1' }) };
    access = { canManage: jest.fn().mockResolvedValue(true) };
    settings = fakeSettings();
    service = new BirthdaysService(
      profileRepo,
      cardRepo,
      businessRepo,
      noticeRepo,
      notifications,
      campaigns,
      access,
      settings as any,
    );
  });

  afterEach(() => jest.useRealTimers());

  describe('aviso diario al dueño', () => {
    beforeEach(() => {
      profileQuery.getMany.mockResolvedValue([person('u1', '1995-10-22')]);
      cardRepo.find.mockResolvedValue([card('u1', null)]);
    });

    it('avisa al dueño de que su cliente cumple años hoy, con el enlace a Cumpleaños', async () => {
      expect(await service.notifyDue(NOW)).toBe(1);

      expect(notifications.sendToBusinessOwner).toHaveBeenCalledWith(
        'b1',
        'Hoy cumple años Persona u1',
        'Persona u1 es cliente de Café Aurora. Regálale una gift card para celebrarlo.',
        { type: 'birthday', route: '/birthdays', business_id: 'b1', user_id: 'u1' },
      );
      // Queda apuntado para no avisar dos veces el mismo año.
      expect(insertedRows).toEqual([{ businessId: 'b1', userId: 'u1', year: 2026, notifiedAt: NOW }]);
    });

    it('busca por mes y día de hoy (hora de Ecuador), sin mirar el año de nacimiento', async () => {
      await service.notifyDue(NOW);

      const params = profileQuery.andWhere.mock.calls.map((c: any[]) => c[1]).find(Boolean);
      expect(params).toEqual({ m0: 10, d0: 22 });
    });

    it('no avisa antes de la hora que fijó el administrador', async () => {
      settings.get.mockImplementation(fakeSettings({ [SETTING_KEYS.birthdayNoticeHour]: 11 }).get);

      expect(await service.notifyDue(NOW)).toBe(0);
      expect(profileRepo.createQueryBuilder).not.toHaveBeenCalled();
    });

    it('a la hora exacta ya avisa', async () => {
      settings.get.mockImplementation(fakeSettings({ [SETTING_KEYS.birthdayNoticeHour]: 10 }).get);

      expect(await service.notifyDue(NOW)).toBe(1);
    });

    it('si ya se avisó este año, no avisa otra vez', async () => {
      claimResult = { raw: [] };

      expect(await service.notifyDue(NOW)).toBe(0);
      expect(notifications.sendToBusinessOwner).not.toHaveBeenCalled();
    });

    it('sin nadie de cumpleaños no hace nada más', async () => {
      profileQuery.getMany.mockResolvedValue([]);

      expect(await service.notifyDue(NOW)).toBe(0);
      expect(cardRepo.find).not.toHaveBeenCalled();
    });

    it('un cliente con tarjeta en varios locales avisa a cada dueño', async () => {
      cardRepo.find.mockResolvedValue([
        card('u1', null),
        card('u1', null, { businessId: 'b2', business: business({ id: 'b2', name: 'Pizzería Sol' }) }),
      ]);

      expect(await service.notifyDue(NOW)).toBe(2);
      expect(notifications.sendToBusinessOwner).toHaveBeenCalledWith('b2', expect.any(String), expect.stringContaining('Pizzería Sol'), expect.any(Object));
    });

    it('un local inactivo no recibe el aviso', async () => {
      cardRepo.find.mockResolvedValue([card('u1', null, { business: business({ isActive: false }) })]);

      expect(await service.notifyDue(NOW)).toBe(0);
    });

    it('el 28 de febrero en año no bisiesto también cuenta a quienes nacieron un 29', async () => {
      const feb28 = new Date('2026-02-28T15:00:00Z');

      await service.notifyDue(feb28);

      const params = profileQuery.andWhere.mock.calls.map((c: any[]) => c[1]).find(Boolean);
      expect(params).toEqual({ m0: 2, d0: 28, m1: 2, d1: 29 });
    });

    it('un fallo al avisar a uno no detiene a los demás', async () => {
      profileQuery.getMany.mockResolvedValue([person('u1', '1995-10-22'), person('u2', '1990-10-22')]);
      cardRepo.find.mockResolvedValue([card('u1', null), card('u2', null)]);
      notifications.sendToBusinessOwner.mockRejectedValueOnce(new Error('fcm caído'));

      expect(await service.notifyDue(NOW)).toBe(1);
    });
  });

  describe('lista del dueño', () => {
    const cards = () => [
      card('hoy', person('hoy', '1990-10-22')),
      card('pronto', person('pronto', '1991-10-25')),
      card('lejos', person('lejos', '1992-04-01')),
      card('ayer', person('ayer', '1993-10-21')),
      card('antiguo', person('antiguo', '1994-10-10')),
      card('sinfecha', person('sinfecha', null)),
    ];

    it('muestra hoy y los próximos, del más cercano al más lejano, y deja fuera al resto', async () => {
      cardRepo.find.mockResolvedValue(cards());

      const { items, upcomingDays } = await service.upcoming(owner);

      expect(upcomingDays).toBe(7);
      // Los que ya pasaron no aparecen: la gift card de cumpleaños vale solo ese día.
      expect(items.map((i) => i.userId)).toEqual(['hoy', 'pronto']);
      expect(items.map((i) => i.daysUntil)).toEqual([0, 3]);
      expect(items[0]).toMatchObject({ isToday: true, month: 10, day: 22, businessName: 'Café Aurora', gifted: false });
    });

    it('nunca devuelve el año de nacimiento ni la edad', async () => {
      cardRepo.find.mockResolvedValue(cards());

      const { items } = await service.upcoming(owner);

      const text = JSON.stringify(items);
      expect(text).not.toContain('1990');
      expect(text).not.toContain('birthDate');
      expect(text).not.toMatch(/"age"/);
    });

    it('el plazo lo fija el administrador', async () => {
      settings.get.mockImplementation(fakeSettings({ [SETTING_KEYS.birthdayUpcomingDays]: 1 }).get);
      cardRepo.find.mockResolvedValue(cards());

      const { items } = await service.upcoming(owner);

      expect(items.map((i) => i.userId)).toEqual(['hoy']);
    });

    it('marca a quien ya recibió su regalo este año', async () => {
      cardRepo.find.mockResolvedValue(cards());
      noticeRepo.find.mockResolvedValue([
        { businessId: 'b1', userId: 'hoy', year: 2026, giftedAt: new Date('2026-10-22T14:00:00Z') },
        // El regalo del año pasado no cuenta.
        { businessId: 'b1', userId: 'pronto', year: 2025, giftedAt: new Date('2025-10-25T14:00:00Z') },
      ]);

      const { items } = await service.upcoming(owner);

      expect(items.find((i) => i.userId === 'hoy')?.gifted).toBe(true);
      expect(items.find((i) => i.userId === 'pronto')?.gifted).toBe(false);
    });

    it('cruza el fin de año: el 2 de enero se ve desde el 30 de diciembre', async () => {
      jest.setSystemTime(new Date('2026-12-30T15:00:00Z'));
      cardRepo.find.mockResolvedValue([card('ene', person('ene', '1990-01-02'))]);
      noticeRepo.find.mockResolvedValue([{ businessId: 'b1', userId: 'ene', year: 2027, giftedAt: new Date() }]);

      const { items } = await service.upcoming(owner);

      expect(items).toHaveLength(1);
      expect(items[0]).toMatchObject({ daysUntil: 3, gifted: true });
    });

    it('sin businessId usa los negocios activos del dueño; para otro negocio pide permiso', async () => {
      await service.upcoming(owner);
      expect(businessRepo.find).toHaveBeenCalledWith({ where: { ownerId: 'owner-1', isActive: true } });

      access.canManage.mockResolvedValue(false);
      await expect(service.upcoming(owner, 'b9')).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('un administrador debe indicar el negocio', async () => {
      expect(await service.upcoming(admin)).toEqual({ upcomingDays: 7, items: [] });
      expect(cardRepo.find).not.toHaveBeenCalled();
    });

    it('sin clientes con fecha devuelve la lista vacía', async () => {
      cardRepo.find.mockResolvedValue([card('x', person('x', null))]);

      expect((await service.upcoming(owner)).items).toEqual([]);
    });
  });

  describe('regalar una gift card (plantilla de cumpleaños)', () => {
    const dto = (extra: any = {}) => ({
      businessId: 'b1',
      userId: 'u1',
      benefitType: 'discount_percent',
      benefitValue: 15,
      ...extra,
    });

    beforeEach(() => {
      cardRepo.findOne.mockResolvedValue(card('u1', person('u1', '1995-10-22', { fullName: 'Ana María Pérez' })));
    });

    it('crea una gift card con la plantilla de cumpleaños, dirigida solo a ese cliente', async () => {
      await service.gift(owner, dto() as any);

      const [requester, created, options] = campaigns.create.mock.calls[0];
      expect(requester).toBe(owner);
      expect(options).toEqual({ template: 'birthday' });
      expect(created).toMatchObject({
        type: 'gift_card',
        // El texto de la plantilla ya viene puesto.
        title: 'Feliz cumpleaños, Ana',
        description: 'Un regalo de Café Aurora por tu cumpleaños. Vale solo ese día.',
        businessIds: ['b1'],
        audience: 'selected',
        recipientIds: ['u1'],
        benefitType: 'discount_percent',
        benefitValue: 15,
      });
    });

    it('vale solo el día del cumpleaños: por defecto desde la hora del aviso hasta el final del día (Ecuador)', async () => {
      const result = await service.gift(owner, dto() as any);

      const created = campaigns.create.mock.calls[0][1];
      // 22/10 a las 8:00 en Ecuador = 13:00 UTC; ya pasó, así que empieza ahora.
      expect(created.startsAt).toBe('2026-10-22T13:00:00.000Z');
      expect(created.endsAt).toBe('2026-10-23T04:59:59.000Z');
      expect(result.startsAt).toEqual(NOW);
      expect(result.endsAt).toEqual(new Date('2026-10-23T04:59:59.000Z'));
      expect(result.campaignId).toBe('camp-1');
    });

    it('el dueño elige las horas', async () => {
      await service.gift(owner, dto({ startTime: '12:00', endTime: '20:30' }) as any);

      const created = campaigns.create.mock.calls[0][1];
      expect(created.startsAt).toBe('2026-10-22T17:00:00.000Z');
      expect(created.endsAt).toBe('2026-10-23T01:30:00.000Z');
    });

    it('si el cumpleaños es otro día, queda programada para ese día a la hora elegida', async () => {
      cardRepo.findOne.mockResolvedValue(card('u1', person('u1', '1995-10-25')));

      const result = await service.gift(owner, dto({ startTime: '09:30', endTime: '22:00' }) as any);

      const created = campaigns.create.mock.calls[0][1];
      expect(created.startsAt).toBe('2026-10-25T14:30:00.000Z');
      expect(created.endsAt).toBe('2026-10-26T03:00:00.000Z');
      expect(result.startsAt).toEqual(new Date('2026-10-25T14:30:00.000Z'));
    });

    it('la hora de inicio por defecto es la que fijó el administrador para el aviso', async () => {
      settings.get.mockImplementation(fakeSettings({ [SETTING_KEYS.birthdayNoticeHour]: 9 }).get);
      cardRepo.findOne.mockResolvedValue(card('u1', person('u1', '1995-10-25')));

      await service.gift(owner, dto() as any);

      expect(campaigns.create.mock.calls[0][1].startsAt).toBe('2026-10-25T14:00:00.000Z');
    });

    it('el 29 de febrero se regala el 28 en año no bisiesto', async () => {
      jest.setSystemTime(new Date('2026-02-26T15:00:00Z'));
      cardRepo.findOne.mockResolvedValue(card('u1', person('u1', '2000-02-29')));

      await service.gift(owner, dto({ startTime: '10:00' }) as any);

      expect(campaigns.create.mock.calls[0][1].startsAt).toBe('2026-02-28T15:00:00.000Z');
    });

    it('apunta el regalo (para no repetirlo) y guarda la campaña creada', async () => {
      await service.gift(owner, dto() as any);

      expect(noticeRepo.update).toHaveBeenCalledWith(
        { businessId: 'b1', userId: 'u1', year: 2026, giftedAt: expect.anything() },
        { giftedAt: NOW },
      );
      expect(noticeRepo.update).toHaveBeenLastCalledWith(
        { businessId: 'b1', userId: 'u1', year: 2026 },
        { giftCampaignId: 'camp-1' },
      );
    });

    it('un mini premio lleva su descripción', async () => {
      await service.gift(owner, dto({ benefitType: 'mini_prize', benefitValue: undefined, benefitLabel: 'Un postre gratis' }) as any);

      expect(campaigns.create.mock.calls[0][1]).toMatchObject({ benefitType: 'mini_prize', benefitLabel: 'Un postre gratis' });
    });

    it('no se regala dos veces por el mismo cumpleaños', async () => {
      noticeRepo.update.mockResolvedValueOnce({ affected: 0 });

      await expect(service.gift(owner, dto() as any)).rejects.toBeInstanceOf(ConflictException);
      expect(campaigns.create).not.toHaveBeenCalled();
    });

    it('si no se pudo crear la gift card, libera el regalo para intentarlo de nuevo', async () => {
      campaigns.create.mockRejectedValue(new BadRequestException('Describe el mini premio'));

      await expect(service.gift(owner, dto() as any)).rejects.toThrow('Describe el mini premio');
      expect(noticeRepo.update).toHaveBeenLastCalledWith({ businessId: 'b1', userId: 'u1', year: 2026 }, { giftedAt: null });
    });

    it('las horas deben tener sentido: el fin después del inicio y todavía por venir', async () => {
      await expect(service.gift(owner, dto({ startTime: '15:00', endTime: '14:00' }) as any)).rejects.toThrow('después de la hora de inicio');
      // Son las 10:00 en Ecuador: terminar a las 9:00 ya pasó.
      await expect(service.gift(owner, dto({ startTime: '07:00', endTime: '09:00' }) as any)).rejects.toThrow('ya pasó');
      expect(campaigns.create).not.toHaveBeenCalled();
    });

    it('solo hoy o dentro del plazo: no se regala si ya pasó ni si falta mucho', async () => {
      cardRepo.findOne.mockResolvedValue(card('u1', person('u1', '1995-10-21')));
      await expect(service.gift(owner, dto() as any)).rejects.toThrow('ya pasó');

      cardRepo.findOne.mockResolvedValue(card('u1', person('u1', '1995-12-25')));
      await expect(service.gift(owner, dto() as any)).rejects.toThrow('hasta 7 días antes');
      expect(campaigns.create).not.toHaveBeenCalled();
    });

    it('rechaza a quien no es cliente del local o no compartió su fecha', async () => {
      cardRepo.findOne.mockResolvedValue(null);
      await expect(service.gift(owner, dto() as any)).rejects.toThrow('no tiene tarjeta');

      cardRepo.findOne.mockResolvedValue(card('u1', person('u1', null)));
      await expect(service.gift(owner, dto() as any)).rejects.toThrow('no compartió');
    });

    it('solo el dueño del negocio, y con el negocio activo', async () => {
      access.canManage.mockResolvedValue(false);
      await expect(service.gift(owner, dto() as any)).rejects.toBeInstanceOf(ForbiddenException);

      access.canManage.mockResolvedValue(true);
      businessRepo.findOne.mockResolvedValue(business({ isActive: false }));
      await expect(service.gift(owner, dto() as any)).rejects.toThrow('activo');
    });
  });
});
