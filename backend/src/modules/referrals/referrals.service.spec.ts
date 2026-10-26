import { BadRequestException, ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { UserRole } from '../../database/entities/profile.entity';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { fakeSettings } from '../settings/settings.testing';
import { newReferralCode, normalizeReferralCode, ReferralsService } from './referrals.service';

const person = (id: string, name: string | null, extra: any = {}) => ({
  id,
  fullName: name,
  email: `${id}@mail.com`,
  role: UserRole.CLIENT,
  referralCode: null,
  referralBalance: 0,
  referralGroupsPaid: 0,
  ...extra,
});
const business = (id: string, name: string, extra: any = {}) => ({
  id,
  name,
  isActive: true,
  referralEnabled: true,
  logoUrl: null,
  category: 'Cafetería',
  categoryRef: { name: 'Cafeterías' },
  address: 'Av. Loja',
  rewardDescription: 'Café gratis',
  pointsRequired: 10,
  ...extra,
});

describe('códigos de amigo', () => {
  it('tienen el formato AMG- y 6 caracteres fáciles de dictar', () => {
    for (let i = 0; i < 200; i++) {
      expect(newReferralCode()).toMatch(/^AMG-[2-9A-HJ-NP-Z]{6}$/);
    }
  });

  it('son distintos cada vez', () => {
    expect(new Set(Array.from({ length: 100 }, newReferralCode)).size).toBe(100);
  });

  it('se aceptan con o sin guion, en minúsculas y con espacios', () => {
    expect(normalizeReferralCode('amg-abc234')).toBe('AMG-ABC234');
    expect(normalizeReferralCode(' AMG ABC234 ')).toBe('AMG-ABC234');
    expect(normalizeReferralCode('amgabc234')).toBe('AMG-ABC234');
  });

  it('lo que no es un texto da vacío', () => {
    expect(normalizeReferralCode(undefined)).toBe('');
    expect(normalizeReferralCode(123 as any)).toBe('');
  });
});

describe('ReferralsService (invitar amigos a la app)', () => {
  let businessRepo: any;
  let profileRepo: any;
  let referralRepo: any;
  let useRepo: any;
  let scanRepo: any;
  let loyaltyCards: any;
  let notifications: any;
  let settings: ReturnType<typeof fakeSettings>;
  let config: any;
  let updateBuilder: any;
  let service: ReferralsService;
  let realScans: number;
  let users: Record<string, any>;

  const set = (values: Record<string, number>) => settings.get.mockImplementation(fakeSettings(values).get);

  beforeEach(() => {
    realScans = 1;
    users = { ana: person('ana', 'Ana Pérez', { referralCode: 'AMG-ABC234' }), luis: person('luis', 'Luis Mora') };
    businessRepo = {
      find: jest.fn().mockResolvedValue([business('b1', 'Café Aurora'), business('b2', 'Pizzería Sol')]),
      findOne: jest.fn().mockResolvedValue(business('b1', 'Café Aurora')),
      count: jest.fn().mockResolvedValue(2),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
      createQueryBuilder: jest.fn(),
    };
    updateBuilder = {
      update: jest.fn().mockReturnThis(),
      set: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    profileRepo = {
      findOne: jest.fn(async ({ where }: any) => {
        if (where.referralCode) return Object.values(users).find((u: any) => u.referralCode === where.referralCode) ?? null;
        return users[where.id] ?? null;
      }),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
      increment: jest.fn().mockResolvedValue({ affected: 1 }),
      createQueryBuilder: jest.fn(() => updateBuilder),
    };
    referralRepo = {
      count: jest.fn().mockResolvedValue(0),
      findOne: jest.fn().mockResolvedValue(null),
      save: jest.fn(async (r) => ({ id: 'r-new', ...r })),
      create: jest.fn((r) => r),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    useRepo = { save: jest.fn(async (r) => r), create: jest.fn((r) => r) };
    scanRepo = {
      count: jest.fn().mockResolvedValue(0),
      createQueryBuilder: jest.fn(() => {
        const q: any = {
          where: jest.fn().mockReturnThis(),
          andWhere: jest.fn().mockReturnThis(),
          getCount: jest.fn(async () => realScans),
        };
        return q;
      }),
    };
    loyaltyCards = {
      cardsOf: jest.fn().mockResolvedValue([{ businessId: 'b1', currentPoints: 4 }]),
      grantBonusPoints: jest.fn().mockResolvedValue({ cardId: 'card-1', currentPoints: 5, newRewards: 0 }),
    };
    notifications = { sendToUser: jest.fn().mockResolvedValue(true) };
    settings = fakeSettings();
    config = { get: jest.fn((k: string) => ({ 'referrals.publicApiUrl': 'https://api.fidelity.test', apiPrefix: 'api/v1' } as any)[k]) };
    service = new ReferralsService(
      businessRepo,
      profileRepo,
      referralRepo,
      useRepo,
      scanRepo,
      loyaltyCards,
      notifications,
      settings as any,
      config,
    );
  });

  describe('lo que fija el administrador', () => {
    it('por defecto: 3 amigos, 1 punto solo para quien invita y cuentan al registrarse', async () => {
      expect(await service.rules()).toEqual({
        referrerPoints: 1,
        friendPoints: 0,
        maxFriends: 20,
        friendsRequired: 3,
        trigger: 'registration',
        enabled: true,
      });
    });

    it('con 0 y 0 queda apagado; con que uno sea mayor que 0 sigue encendido', async () => {
      set({ [SETTING_KEYS.referralReferrerPoints]: 0, [SETTING_KEYS.referralFriendPoints]: 0 });
      expect((await service.rules()).enabled).toBe(false);

      set({ [SETTING_KEYS.referralReferrerPoints]: 0, [SETTING_KEYS.referralFriendPoints]: 1 });
      expect((await service.rules()).enabled).toBe(true);
    });

    it('el administrador cambia cuántos amigos y cuándo cuentan', async () => {
      set({ [SETTING_KEYS.referralFriendsRequired]: 5, [SETTING_KEYS.referralTrigger]: 1 });

      expect(await service.rules()).toMatchObject({ friendsRequired: 5, trigger: 'first_scan' });
    });
  });

  describe('el enlace', () => {
    it('apunta a la página de invitación del backend', () => {
      expect(service.inviteLink('AMG-ABC234')).toBe('https://api.fidelity.test/api/v1/invite/AMG-ABC234');
    });

    it('sin dirección pública no hay enlace (solo el código)', () => {
      config.get.mockImplementation((k: string) => (k === 'apiPrefix' ? 'api/v1' : ''));

      expect(service.inviteLink('AMG-ABC234')).toBeNull();
    });
  });

  describe('mi código y mis puntos', () => {
    it('devuelve el código, el enlace, el saldo y cuántos amigos ya vinieron', async () => {
      users.ana.referralBalance = 2;
      users.ana.referralGroupsPaid = 1;
      referralRepo.count.mockImplementation(async ({ where }: any) => (where.countedAt ? 4 : where.status === 'rewarded' ? 2 : 5));

      const info = await service.me('ana');

      expect(info).toMatchObject({
        enabled: true,
        code: 'AMG-ABC234',
        link: 'https://api.fidelity.test/api/v1/invite/AMG-ABC234',
        referrerPoints: 1,
        friendPoints: 0,
        friendsRequired: 3,
        trigger: 'registration',
        invited: 5,
        rewarded: 2,
        counted: 4,
        groupsPaid: 1,
        balance: 2,
        eligibleLocals: 2,
        referredBy: null,
      });
    });

    it('la primera vez crea el código (es de la persona, no de un local)', async () => {
      users.luis.referralCode = null;
      profileRepo.findOne
        .mockResolvedValueOnce(users.luis) // me()
        .mockResolvedValueOnce({ ...users.luis, referralCode: 'AMG-NUEVO2' }); // ensureCode

      const info = await service.me('luis');

      expect(profileRepo.update).toHaveBeenCalledWith(
        { id: 'luis', referralCode: expect.anything() },
        { referralCode: expect.stringMatching(/^AMG-/) },
      );
      expect(info.code).toBe('AMG-NUEVO2');
    });

    it('si el código ya lo tenía otra persona, prueba con otro', async () => {
      users.luis.referralCode = null;
      profileRepo.findOne
        .mockResolvedValueOnce(users.luis)
        .mockResolvedValueOnce({ ...users.luis, referralCode: 'AMG-OTRO22' });
      profileRepo.update.mockRejectedValueOnce(new Error('duplicate key')).mockResolvedValueOnce({ affected: 1 });

      const info = await service.me('luis');

      expect(profileRepo.update).toHaveBeenCalledTimes(2);
      expect(info.code).toBe('AMG-OTRO22');
    });

    it('apagado no ofrece código ni enlace', async () => {
      set({ [SETTING_KEYS.referralReferrerPoints]: 0, [SETTING_KEYS.referralFriendPoints]: 0 });

      expect(await service.me('ana')).toMatchObject({ enabled: false, code: null, link: null });
    });

    it('si llegó invitado, dice de parte de quién', async () => {
      users.luis.referralCode = 'AMG-LUIS22';
      referralRepo.findOne.mockResolvedValue({
        status: 'pending',
        friendPoints: 0,
        referrer: { fullName: 'Ana Pérez', email: 'ana@mail.com' },
      });

      expect((await service.me('luis')).referredBy).toEqual({ name: 'Ana Pérez', status: 'pending', points: 0 });
    });

    it('un usuario que no existe se rechaza', async () => {
      await expect(service.me('nadie')).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('los locales donde se usan los puntos', () => {
    it('solo los activos que el administrador marcó, con los puntos que ya lleva ahí', async () => {
      const locals = await service.eligibleLocals('luis');

      expect(businessRepo.find).toHaveBeenCalledWith(
        expect.objectContaining({ where: { isActive: true, referralEnabled: true } }),
      );
      expect(locals).toEqual([
        expect.objectContaining({ id: 'b1', name: 'Café Aurora', category: 'Cafeterías', pointsRequired: 10, currentPoints: 4 }),
        expect.objectContaining({ id: 'b2', name: 'Pizzería Sol', currentPoints: null }),
      ]);
    });

    it('sin locales participantes devuelve la lista vacía', async () => {
      businessRepo.find.mockResolvedValue([]);

      expect(await service.eligibleLocals('luis')).toEqual([]);
      expect(loyaltyCards.cardsOf).not.toHaveBeenCalled();
    });
  });

  describe('usar los puntos en el local elegido', () => {
    it('los descuenta del saldo y los suma a la tarjeta de ese local', async () => {
      users.luis.referralBalance = 3;
      profileRepo.findOne.mockImplementation(async () => ({ ...users.luis, referralBalance: 2 }));

      const result = await service.use('luis', 'b1', 1);

      expect(updateBuilder.where).toHaveBeenCalledWith('id = :userId AND referral_balance >= :amount', { userId: 'luis', amount: 1 });
      expect(loyaltyCards.grantBonusPoints).toHaveBeenCalledWith('luis', 'b1', 1);
      expect(useRepo.save).toHaveBeenCalledWith({ userId: 'luis', businessId: 'b1', points: 1 });
      expect(result).toMatchObject({
        businessName: 'Café Aurora',
        used: 1,
        balance: 2,
        currentPoints: 5,
        newRewards: 0,
        loyaltyCardId: 'card-1',
      });
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'luis',
        'Puntos de invitación usados',
        'Sumaste 1 punto en Café Aurora.',
        expect.objectContaining({ type: 'referral', business_id: 'b1' }),
      );
    });

    it('puede usar varios puntos de una vez', async () => {
      await service.use('luis', 'b1', 3);

      expect(loyaltyCards.grantBonusPoints).toHaveBeenCalledWith('luis', 'b1', 3);
      expect(notifications.sendToUser).toHaveBeenCalledWith('luis', expect.any(String), 'Sumaste 3 puntos en Café Aurora.', expect.any(Object));
    });

    it('si con ellos completa su premio, también se lo avisa', async () => {
      loyaltyCards.grantBonusPoints.mockResolvedValue({ cardId: 'card-1', currentPoints: 0, newRewards: 1 });

      await service.use('luis', 'b1', 1);

      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'luis',
        'Premio alcanzado',
        'Has ganado premio en Café Aurora, acercate a retirar.',
        expect.objectContaining({ route: '/reward' }),
      );
    });

    it('sin saldo suficiente no suma nada', async () => {
      updateBuilder.execute.mockResolvedValue({ affected: 0 });

      await expect(service.use('luis', 'b1', 2)).rejects.toThrow('No tienes tantos puntos');
      expect(loyaltyCards.grantBonusPoints).not.toHaveBeenCalled();
      expect(useRepo.save).not.toHaveBeenCalled();
    });

    it('si no se pudo sumar a la tarjeta, devuelve los puntos al saldo', async () => {
      loyaltyCards.grantBonusPoints.mockRejectedValue(new Error('db caída'));

      await expect(service.use('luis', 'b1', 2)).rejects.toThrow('db caída');
      expect(profileRepo.increment).toHaveBeenCalledWith({ id: 'luis' }, 'referralBalance', 2);
      expect(useRepo.save).not.toHaveBeenCalled();
    });

    it('solo en locales activos que el administrador marcó como participantes', async () => {
      businessRepo.findOne.mockResolvedValue(business('b3', 'Local normal', { referralEnabled: false }));
      await expect(service.use('luis', 'b3', 1)).rejects.toThrow('no participa');

      businessRepo.findOne.mockResolvedValue(business('b4', 'Cerrado', { isActive: false }));
      await expect(service.use('luis', 'b4', 1)).rejects.toThrow('no participa');

      businessRepo.findOne.mockResolvedValue(null);
      await expect(service.use('luis', 'nada', 1)).rejects.toBeInstanceOf(NotFoundException);
      expect(updateBuilder.execute).not.toHaveBeenCalled();
    });

    it('la cantidad debe ser un entero de 1 o más', async () => {
      await expect(service.use('luis', 'b1', 0)).rejects.toBeInstanceOf(BadRequestException);
      await expect(service.use('luis', 'b1', 1.5)).rejects.toBeInstanceOf(BadRequestException);
    });

    it('un fallo al avisar no deshace el uso', async () => {
      notifications.sendToUser.mockRejectedValue(new Error('fcm caído'));

      await expect(service.use('luis', 'b1', 1)).resolves.toMatchObject({ used: 1 });
    });
  });

  describe('revisar un código', () => {
    it('uno bueno devuelve a quien lo creó', async () => {
      const { inviter } = await service.validateCode('amg-abc234', 'luis');

      expect(inviter.id).toBe('ana');
    });

    it('uno que no existe, vacío o con basura se rechaza', async () => {
      await expect(service.validateCode('AMG-ZZZZZZ')).rejects.toThrow('no existe');
      await expect(service.validateCode('')).rejects.toThrow('no existe');
    });

    it('no se puede usar el propio código', async () => {
      await expect(service.validateCode('AMG-ABC234', 'ana')).rejects.toThrow('propio código');
    });

    it('con las invitaciones apagadas lo rechaza', async () => {
      set({ [SETTING_KEYS.referralReferrerPoints]: 0, [SETTING_KEYS.referralFriendPoints]: 0 });

      await expect(service.validateCode('AMG-ABC234')).rejects.toThrow('no hay invitaciones');
    });

    it('un código que ya trajo el máximo de amigos se rechaza (el máximo lo fija el administrador)', async () => {
      referralRepo.count.mockResolvedValue(20);
      await expect(service.validateCode('AMG-ABC234')).rejects.toThrow('límite');

      set({ [SETTING_KEYS.referralMaxFriends]: 25 });
      await expect(service.validateCode('AMG-ABC234')).resolves.toBeDefined();
    });
  });

  describe('el amigo usa el código', () => {
    /** Cuántos amigos ya cuentan para Ana cuando se consulta (incluido el que acaba de registrarse). */
    const counted = (n: number) =>
      referralRepo.count.mockImplementation(async ({ where }: any) => (where.countedAt ? n : 0));

    it('queda invitado y cuenta enseguida: se le avisa a quien invitó cómo va', async () => {
      counted(1);

      const result = await service.redeem('luis', 'amg-abc234');

      expect(referralRepo.save).toHaveBeenCalledWith({ referrerId: 'ana', refereeId: 'luis', status: 'pending' });
      expect(result).toEqual({ friendPoints: 0, referrerName: 'Ana Pérez' });
      expect(referralRepo.update).toHaveBeenCalledWith({ id: 'r-new', countedAt: expect.anything() }, { countedAt: expect.any(Date) });
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'ana',
        'Luis Mora se unió con tu código',
        'Van 1 de 3 amigos. Cuando se unan 3, ganas 1 punto.',
        expect.objectContaining({ type: 'referral', route: '/referral' }),
      );
      // Todavía no completa el grupo: no gana nada.
      expect(profileRepo.update).not.toHaveBeenCalled();
      expect(profileRepo.increment).not.toHaveBeenCalled();
    });

    it('el segundo amigo: van 2 de 3', async () => {
      counted(2);

      await service.redeem('luis', 'AMG-ABC234');

      expect(notifications.sendToUser).toHaveBeenCalledWith('ana', expect.any(String), 'Van 2 de 3 amigos. Cuando se unan 3, ganas 1 punto.', expect.anything());
      expect(profileRepo.increment).not.toHaveBeenCalled();
    });

    it('el tercer amigo completa el grupo: gana el punto solo quien invita', async () => {
      counted(3);

      await service.redeem('luis', 'AMG-ABC234');

      // Marca el grupo como pagado (comparando el valor anterior) y le suma el punto al saldo.
      expect(profileRepo.update).toHaveBeenCalledWith({ id: 'ana', referralGroupsPaid: 0 }, { referralGroupsPaid: 1 });
      expect(profileRepo.increment).toHaveBeenCalledTimes(1);
      expect(profileRepo.increment).toHaveBeenCalledWith({ id: 'ana' }, 'referralBalance', 1);
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'ana',
        '¡Se unieron 3 amigos!',
        'Ganaste 1 punto de invitación. Elige en qué local usarlos.',
        expect.objectContaining({ route: '/referral' }),
      );
      // El amigo no recibe nada.
      expect(profileRepo.increment).not.toHaveBeenCalledWith({ id: 'luis' }, 'referralBalance', expect.anything());
    });

    it('el grupo siguiente (6 amigos) paga otra vez, pero el 4.º y el 5.º no', async () => {
      users.ana.referralGroupsPaid = 1;
      counted(4);
      await service.redeem('luis', 'AMG-ABC234');
      expect(profileRepo.increment).not.toHaveBeenCalled();

      counted(6);
      await service.redeem('luis', 'AMG-ABC234');
      expect(profileRepo.update).toHaveBeenCalledWith({ id: 'ana', referralGroupsPaid: 1 }, { referralGroupsPaid: 2 });
      expect(profileRepo.increment).toHaveBeenCalledWith({ id: 'ana' }, 'referralBalance', 1);
    });

    it('con los puntos y la cantidad de amigos que fije el administrador', async () => {
      set({ [SETTING_KEYS.referralFriendsRequired]: 2, [SETTING_KEYS.referralReferrerPoints]: 3 });
      counted(2);

      await service.redeem('luis', 'AMG-ABC234');

      expect(profileRepo.increment).toHaveBeenCalledWith({ id: 'ana' }, 'referralBalance', 3);
      expect(notifications.sendToUser).toHaveBeenCalledWith('ana', '¡Se unieron 2 amigos!', 'Ganaste 3 puntos de invitación. Elige en qué local usarlos.', expect.anything());
    });

    it('si el grupo ya se pagó antes (otro proceso), no se paga dos veces', async () => {
      counted(3);
      profileRepo.update.mockResolvedValue({ affected: 0 });

      await service.redeem('luis', 'AMG-ABC234');

      expect(profileRepo.increment).not.toHaveBeenCalled();
      expect(notifications.sendToUser).not.toHaveBeenCalled();
    });

    it('si por un ajuste ya se debían varios grupos, se pagan todos juntos', async () => {
      // 6 amigos contados y solo 1 grupo pagado de antes, con 3 por grupo: se debe 1 más. Con 2 por grupo, 2 más.
      users.ana.referralGroupsPaid = 1;
      set({ [SETTING_KEYS.referralFriendsRequired]: 2 });
      counted(6);

      await service.redeem('luis', 'AMG-ABC234');

      expect(profileRepo.update).toHaveBeenCalledWith({ id: 'ana', referralGroupsPaid: 1 }, { referralGroupsPaid: 3 });
      expect(profileRepo.increment).toHaveBeenCalledWith({ id: 'ana' }, 'referralBalance', 2);
    });

    it('con 0 puntos para quien invita no hay pago, pero se le cuenta cómo va', async () => {
      set({ [SETTING_KEYS.referralReferrerPoints]: 0, [SETTING_KEYS.referralFriendPoints]: 1 });
      counted(3);

      await service.redeem('luis', 'AMG-ABC234');

      expect(profileRepo.increment).not.toHaveBeenCalled();
      expect(notifications.sendToUser).toHaveBeenCalledWith('ana', expect.any(String), 'Van 3 de 3 amigos.', expect.anything());
    });

    it('si se configura "primer escaneo", al registrarse todavía no cuenta', async () => {
      set({ [SETTING_KEYS.referralTrigger]: 1 });
      counted(0);

      await service.redeem('luis', 'AMG-ABC234');

      expect(referralRepo.save).toHaveBeenCalled();
      expect(referralRepo.update).not.toHaveBeenCalled();
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'ana',
        'Luis Mora se unió con tu código',
        'Cuando haga su primer escaneo, contará para tu punto.',
        expect.anything(),
      );
    });

    it('solo una vez en la vida', async () => {
      referralRepo.findOne.mockResolvedValue({ id: 'r0' });

      await expect(service.redeem('luis', 'AMG-ABC234')).rejects.toBeInstanceOf(ConflictException);
      expect(referralRepo.save).not.toHaveBeenCalled();
    });

    it('solo para gente nueva: quien ya tiene escaneos aprobados no puede', async () => {
      scanRepo.count.mockResolvedValue(2);

      await expect(service.redeem('luis', 'AMG-ABC234')).rejects.toThrow('Ya usas Fidelity');
      expect(referralRepo.save).not.toHaveBeenCalled();
    });

    it('solo los clientes (no dueños, aprobadores ni administradores)', async () => {
      users.dueno = person('dueno', 'Dueño', { role: UserRole.BUSINESS });

      await expect(service.redeem('dueno', 'AMG-ABC234')).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('un usuario que no existe, o un código que no sirve, se rechaza', async () => {
      await expect(service.redeem('nadie', 'AMG-ABC234')).rejects.toBeInstanceOf(NotFoundException);
      await expect(service.redeem('luis', 'AMG-ZZZZZZ')).rejects.toBeInstanceOf(BadRequestException);
    });

    it('si falla el aviso, igual queda invitado y el punto se le suma', async () => {
      counted(3);
      notifications.sendToUser.mockRejectedValue(new Error('fcm caído'));

      await expect(service.redeem('luis', 'AMG-ABC234')).resolves.toMatchObject({ referrerName: 'Ana Pérez' });
      expect(profileRepo.increment).toHaveBeenCalledWith({ id: 'ana' }, 'referralBalance', 1);
    });
  });

  describe('el primer escaneo aprobado del amigo', () => {
    const pending = () => referralRepo.findOne.mockResolvedValue({ id: 'r1', referrerId: 'ana', refereeId: 'luis' });

    it('por defecto no da puntos al amigo (el punto es solo de quien invita) y no cuenta otra vez', async () => {
      pending();

      expect(await service.onScanApproved('luis')).toBe(true);

      expect(referralRepo.update).toHaveBeenCalledWith(
        { id: 'r1', status: 'pending' },
        expect.objectContaining({ status: 'rewarded', friendPoints: 0 }),
      );
      expect(profileRepo.increment).not.toHaveBeenCalled();
      expect(notifications.sendToUser).not.toHaveBeenCalled();
      // El amigo ya contó al registrarse: no se vuelve a contar.
      expect(referralRepo.update).toHaveBeenCalledTimes(1);
    });

    it('si el administrador le da puntos al amigo, los recibe con su primer escaneo', async () => {
      set({ [SETTING_KEYS.referralFriendPoints]: 2 });
      pending();

      await service.onScanApproved('luis');

      expect(profileRepo.increment).toHaveBeenCalledWith({ id: 'luis' }, 'referralBalance', 2);
      expect(profileRepo.increment).not.toHaveBeenCalledWith({ id: 'ana' }, 'referralBalance', expect.anything());
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'luis',
        '¡Ganaste 2 puntos de invitación!',
        'Por tu primer escaneo, invitado por Ana Pérez. Elige en qué local usarlos.',
        expect.objectContaining({ route: '/referral' }),
      );
    });

    it('con "primer escaneo" configurado, es ahora cuando el amigo cuenta para quien invita', async () => {
      set({ [SETTING_KEYS.referralTrigger]: 1 });
      referralRepo.count.mockImplementation(async ({ where }: any) => (where.countedAt ? 3 : 0));
      pending();

      await service.onScanApproved('luis');

      expect(referralRepo.update).toHaveBeenCalledWith({ id: 'r1', countedAt: expect.anything() }, { countedAt: expect.any(Date) });
      expect(profileRepo.increment).toHaveBeenCalledWith({ id: 'ana' }, 'referralBalance', 1);
      expect(notifications.sendToUser).toHaveBeenCalledWith('ana', '¡Se unieron 3 amigos!', expect.any(String), expect.any(Object));
    });

    it('con "primer escaneo" y el grupo incompleto, le cuenta cómo va', async () => {
      set({ [SETTING_KEYS.referralTrigger]: 1 });
      referralRepo.count.mockImplementation(async ({ where }: any) => (where.countedAt ? 2 : 0));
      pending();

      await service.onScanApproved('luis');

      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'ana',
        'Luis Mora ya hizo su primer escaneo',
        'Van 2 de 3 amigos. Cuando se unan 3, ganas 1 punto.',
        expect.any(Object),
      );
      expect(profileRepo.increment).not.toHaveBeenCalled();
    });

    it('sin invitación pendiente no hace nada', async () => {
      expect(await service.onScanApproved('luis')).toBe(false);
      expect(profileRepo.increment).not.toHaveBeenCalled();
    });

    it('si todavía no tiene un escaneo real aprobado, no cuenta', async () => {
      pending();
      realScans = 0;

      expect(await service.onScanApproved('luis')).toBe(false);
      expect(referralRepo.update).not.toHaveBeenCalled();
    });

    it('solo una vez: si otra aprobación ya lo procesó, no repite', async () => {
      set({ [SETTING_KEYS.referralFriendPoints]: 1 });
      pending();
      referralRepo.update.mockResolvedValue({ affected: 0 });

      expect(await service.onScanApproved('luis')).toBe(false);
      expect(profileRepo.increment).not.toHaveBeenCalled();
      expect(notifications.sendToUser).not.toHaveBeenCalled();
    });

    it('un fallo al avisar no deshace el pago', async () => {
      set({ [SETTING_KEYS.referralFriendPoints]: 1 });
      pending();
      notifications.sendToUser.mockRejectedValue(new Error('fcm caído'));

      await expect(service.onScanApproved('luis')).resolves.toBe(true);
      expect(profileRepo.increment).toHaveBeenCalledWith({ id: 'luis' }, 'referralBalance', 1);
    });
  });

  describe('el administrador elige los locales', () => {
    it('lista los activos con su marca y se puede buscar por nombre', async () => {
      businessRepo.find.mockResolvedValue([
        business('b1', 'Café Aurora', { referralEnabled: true }),
        business('b2', 'Pizzería Sol', { referralEnabled: false }),
      ]);

      const all = await service.adminBusinesses();
      expect(all.map((b) => [b.name, b.enabled])).toEqual([['Café Aurora', true], ['Pizzería Sol', false]]);
      expect(businessRepo.find).toHaveBeenCalledWith(expect.objectContaining({ where: { isActive: true } }));

      expect((await service.adminBusinesses('piz')).map((b) => b.name)).toEqual(['Pizzería Sol']);
    });

    it('marca o desmarca un local', async () => {
      expect(await service.setBusinessEnabled('b1', true)).toEqual({ id: 'b1', enabled: true });
      expect(businessRepo.update).toHaveBeenCalledWith({ id: 'b1' }, { referralEnabled: true });

      businessRepo.update.mockResolvedValue({ affected: 0 });
      await expect(service.setBusinessEnabled('nada', true)).rejects.toBeInstanceOf(NotFoundException);
    });

    it('marca varios de una vez (solo los activos)', async () => {
      const q: any = {
        update: jest.fn().mockReturnThis(),
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        execute: jest.fn().mockResolvedValue({ affected: 2 }),
      };
      businessRepo.createQueryBuilder.mockReturnValue(q);

      expect(await service.setManyEnabled(['b1', 'b2'], true)).toEqual({ updated: 2 });
      expect(q.where).toHaveBeenCalledWith('id IN (:...ids) AND is_active = true', { ids: ['b1', 'b2'] });
      expect(await service.setManyEnabled([], true)).toEqual({ updated: 0 });
    });
  });
});
