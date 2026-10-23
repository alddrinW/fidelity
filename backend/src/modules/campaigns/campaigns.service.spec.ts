import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { CampaignsService, MAX_AUDIENCE } from './campaigns.service';
import {
  Campaign,
  CampaignBenefit,
  CampaignType,
  campaignPhase,
} from '../../database/entities/campaign.entity';
import { CampaignBusiness } from '../../database/entities/campaign-business.entity';
import {
  CampaignClaim,
  ClaimSource,
  ClaimStatus,
} from '../../database/entities/campaign-claim.entity';
import { CampaignStamp } from '../../database/entities/campaign-stamp.entity';
import { CampaignRecipient } from '../../database/entities/campaign-recipient.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Scan } from '../../database/entities/scan.entity';
import { UserRole } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { BusinessAccessService } from '../businesses/business-access.service';

const HOUR = 60 * 60 * 1000;
const inHours = (h: number) => new Date(Date.now() + h * HOUR).toISOString();

describe('campaignPhase', () => {
  const now = new Date('2026-10-14T12:00:00Z');
  const base = { startsAt: new Date('2026-10-14T10:00:00Z'), endsAt: null, cancelledAt: null };

  it('programada si todavia no empieza', () => {
    expect(campaignPhase({ ...base, startsAt: new Date('2026-10-15T00:00:00Z') }, now)).toBe('scheduled');
  });
  it('activa entre el inicio y el fin (o sin fin)', () => {
    expect(campaignPhase(base, now)).toBe('active');
    expect(campaignPhase({ ...base, endsAt: new Date('2026-10-20T00:00:00Z') }, now)).toBe('active');
  });
  it('finalizada al pasar su fin', () => {
    expect(campaignPhase({ ...base, endsAt: new Date('2026-10-14T11:00:00Z') }, now)).toBe('ended');
  });
  it('cancelada gana sobre cualquier fecha', () => {
    expect(campaignPhase({ ...base, cancelledAt: new Date() }, now)).toBe('cancelled');
  });
});

describe('CampaignsService', () => {
  let service: CampaignsService;
  let campaignRepo: any;
  let participantRepo: any;
  let claimRepo: any;
  let stampRepo: any;
  let recipientRepo: any;
  let businessRepo: any;
  let cardRepo: any;
  let scanRepo: any;
  let notifications: any;
  let access: any;

  const owner = { id: 'owner-1', role: UserRole.BUSINESS };
  const biz = (id: string, extra: any = {}) => ({ id, name: `Local ${id}`, ownerId: 'owner-1', isActive: true, ...extra });

  const activeCampaign = (extra: any = {}): any => ({
    id: 'c1',
    businessId: 'b1',
    type: CampaignType.GIFT_CARD,
    title: 'Regalo de aniversario',
    description: null,
    benefitType: CampaignBenefit.DISCOUNT_PERCENT,
    benefitValue: 20,
    benefitLabel: '20% de descuento',
    requiredStamps: null,
    requiredScans: null,
    startsAt: new Date(Date.now() - HOUR),
    endsAt: null,
    cancelledAt: null,
    notifiedAt: null,
    participants: [{ businessId: 'b1', business: { name: 'Local b1' } }],
    ...extra,
  });

  beforeEach(async () => {
    campaignRepo = {
      create: jest.fn((d) => d),
      save: jest.fn((c) => Promise.resolve({ id: 'c1', participants: [], ...c })),
      find: jest.fn().mockResolvedValue([]),
      findOne: jest.fn(),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    participantRepo = {
      create: jest.fn((d) => d),
      save: jest.fn((p) => Promise.resolve(p)),
      find: jest.fn().mockResolvedValue([]),
    };
    claimRepo = {
      create: jest.fn((d) => d),
      save: jest.fn((c) => Promise.resolve({ id: 'cl1', createdAt: new Date(), ...c })),
      find: jest.fn().mockResolvedValue([]),
      findOne: jest.fn().mockResolvedValue(null),
    };
    stampRepo = {
      create: jest.fn((d) => d),
      save: jest.fn((s) => Promise.resolve(s)),
      find: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
      exists: jest.fn().mockResolvedValue(false),
    };
    recipientRepo = {
      create: jest.fn((d) => d),
      save: jest.fn((r) => Promise.resolve(r)),
      find: jest.fn().mockResolvedValue([]),
      exists: jest.fn().mockResolvedValue(true),
    };
    businessRepo = { find: jest.fn().mockResolvedValue([biz('b1')]) };
    cardRepo = {
      find: jest.fn().mockResolvedValue([]),
      exists: jest.fn().mockResolvedValue(true),
    };
    scanRepo = { count: jest.fn().mockResolvedValue(0) };
    notifications = {
      sendToUser: jest.fn().mockResolvedValue(true),
      sendToUsers: jest.fn().mockResolvedValue(3),
    };
    access = {
      canManage: jest.fn().mockResolvedValue(true),
      canOperate: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CampaignsService,
        { provide: getRepositoryToken(Campaign), useValue: campaignRepo },
        { provide: getRepositoryToken(CampaignBusiness), useValue: participantRepo },
        { provide: getRepositoryToken(CampaignClaim), useValue: claimRepo },
        { provide: getRepositoryToken(CampaignStamp), useValue: stampRepo },
        { provide: getRepositoryToken(CampaignRecipient), useValue: recipientRepo },
        { provide: getRepositoryToken(Business), useValue: businessRepo },
        { provide: getRepositoryToken(LoyaltyCard), useValue: cardRepo },
        { provide: getRepositoryToken(Scan), useValue: scanRepo },
        { provide: NotificationsService, useValue: notifications },
        { provide: BusinessAccessService, useValue: access },
      ],
    }).compile();

    service = module.get(CampaignsService);
  });

  describe('create', () => {
    const giftDto = (extra: any = {}) => ({
      type: CampaignType.GIFT_CARD,
      title: ' Regalo de aniversario ',
      benefitType: CampaignBenefit.DISCOUNT_PERCENT,
      benefitValue: 20,
      businessIds: ['b1'],
      ...extra,
    });

    beforeEach(() => {
      // create() termina releyendo la campaña para devolver su vista
      campaignRepo.findOne.mockResolvedValue(activeCampaign());
    });

    it('crea una tarjeta de regalo con descuento y genera la etiqueta', async () => {
      await service.create(owner, giftDto() as any);

      const saved = campaignRepo.create.mock.calls[0][0];
      expect(saved).toMatchObject({
        type: CampaignType.GIFT_CARD,
        title: 'Regalo de aniversario',
        benefitType: CampaignBenefit.DISCOUNT_PERCENT,
        benefitValue: 20,
        benefitLabel: '20% de descuento',
        businessId: 'b1',
      });
      expect(participantRepo.save).toHaveBeenCalledWith([
        expect.objectContaining({ campaignId: 'c1', businessId: 'b1' }),
      ]);
    });

    it('una campaña que empieza ya avisa a los clientes sin esperar al programador', async () => {
      campaignRepo.findOne.mockResolvedValue(activeCampaign());
      campaignRepo.update.mockResolvedValue({ affected: 1 });
      cardRepo.find.mockResolvedValue([{ userId: 'u1' }, { userId: 'u2' }, { userId: 'u1' }]);

      await service.create(owner, giftDto() as any);
      await new Promise((r) => setImmediate(r));

      expect(notifications.sendToUsers).toHaveBeenCalledWith(
        ['u1', 'u2'],
        expect.stringContaining('Local b1'),
        expect.stringContaining('20% de descuento'),
        expect.objectContaining({ type: 'gift_card', campaign_id: 'c1' }),
      );
    });

    it('una campaña programada no avisa todavia', async () => {
      campaignRepo.save.mockImplementation((c: any) =>
        Promise.resolve({ id: 'c1', participants: [], ...c }),
      );

      await service.create(owner, giftDto({ startsAt: inHours(48) }) as any);
      await new Promise((r) => setImmediate(r));

      const saved = campaignRepo.create.mock.calls[0][0];
      expect(saved.startsAt.getTime()).toBeGreaterThan(Date.now() + 47 * HOUR);
      expect(notifications.sendToUsers).not.toHaveBeenCalled();
    });

    it('una fecha de inicio pasada se trata como ahora', async () => {
      await service.create(owner, giftDto({ startsAt: inHours(-48) }) as any);

      const saved = campaignRepo.create.mock.calls[0][0];
      expect(saved.startsAt.getTime()).toBeGreaterThan(Date.now() - 5000);
    });

    it('rechaza un fin anterior al inicio o ya vencido', async () => {
      await expect(
        service.create(owner, giftDto({ startsAt: inHours(48), endsAt: inHours(24) }) as any),
      ).rejects.toThrow('posterior al inicio');
      await expect(
        service.create(owner, giftDto({ endsAt: inHours(-1) }) as any),
      ).rejects.toThrow('ya pasó');
      expect(campaignRepo.save).not.toHaveBeenCalled();
    });

    it('exige el beneficio de una tarjeta de regalo', async () => {
      await expect(
        service.create(owner, giftDto({ benefitType: undefined }) as any),
      ).rejects.toBeInstanceOf(BadRequestException);
      await expect(
        service.create(owner, giftDto({ benefitValue: undefined }) as any),
      ).rejects.toThrow('porcentaje');
      await expect(
        service.create(owner, giftDto({ benefitType: CampaignBenefit.MINI_PRIZE }) as any),
      ).rejects.toThrow('mini premio');
    });

    it('un mini premio usa su descripcion como etiqueta', async () => {
      await service.create(
        owner,
        giftDto({ benefitType: CampaignBenefit.MINI_PRIZE, benefitValue: undefined, benefitLabel: ' Café pequeño ' }) as any,
      );

      expect(campaignRepo.create.mock.calls[0][0]).toMatchObject({
        benefitType: CampaignBenefit.MINI_PRIZE,
        benefitLabel: 'Café pequeño',
        benefitValue: null,
      });
    });

    it('un evento ignora cualquier beneficio', async () => {
      await service.create(owner, giftDto({ type: CampaignType.EVENT }) as any);

      expect(campaignRepo.create.mock.calls[0][0]).toMatchObject({
        type: CampaignType.EVENT,
        benefitType: null,
        benefitLabel: null,
        requiredStamps: null,
      });
    });

    describe('rutas', () => {
      const routeDto = (extra: any = {}) => ({
        type: CampaignType.ROUTE,
        title: 'Ruta del café',
        benefitLabel: 'Taza de regalo',
        businessIds: ['b1', 'b2', 'b3'],
        ...extra,
      });

      beforeEach(() => {
        businessRepo.find.mockResolvedValue([biz('b1'), biz('b2'), biz('b3')]);
      });

      it('requiere al menos 2 locales', async () => {
        businessRepo.find.mockResolvedValue([biz('b1')]);

        await expect(
          service.create(owner, routeDto({ businessIds: ['b1'] }) as any),
        ).rejects.toThrow('al menos 2 locales');
      });

      it('requiere describir el premio', async () => {
        await expect(
          service.create(owner, routeDto({ benefitLabel: ' ' }) as any),
        ).rejects.toThrow('premio de la ruta');
      });

      it('por defecto pide un sello por local', async () => {
        await service.create(owner, routeDto() as any);

        expect(campaignRepo.create.mock.calls[0][0]).toMatchObject({
          requiredStamps: 3,
          benefitLabel: 'Taza de regalo',
        });
      });

      it('no permite pedir mas sellos que locales', async () => {
        await expect(
          service.create(owner, routeDto({ requiredStamps: 4 }) as any),
        ).rejects.toThrow('no pueden superar');
      });
    });

    it('solo se crean campañas para negocios propios', async () => {
      businessRepo.find.mockResolvedValue([biz('b1', { ownerId: 'otro' })]);

      await expect(service.create(owner, giftDto() as any)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('el administrador puede crear para cualquier negocio', async () => {
      businessRepo.find.mockResolvedValue([biz('b1', { ownerId: 'otro' })]);

      await expect(
        service.create({ id: 'admin', role: UserRole.ADMIN }, giftDto() as any),
      ).resolves.toBeDefined();
    });

    it('no permite negocios inactivos ni inexistentes', async () => {
      businessRepo.find.mockResolvedValue([biz('b1', { isActive: false })]);
      await expect(service.create(owner, giftDto() as any)).rejects.toThrow('negocios activos');

      businessRepo.find.mockResolvedValue([]);
      await expect(service.create(owner, giftDto() as any)).rejects.toThrow('no existe');
    });

    it('ignora negocios repetidos', async () => {
      await service.create(owner, giftDto({ businessIds: ['b1', 'b1'] }) as any);

      expect(participantRepo.save.mock.calls[0][0]).toHaveLength(1);
    });
  });

  describe('update y cancel', () => {
    it('edita titulo y descripcion', async () => {
      const c = activeCampaign();
      campaignRepo.findOne.mockResolvedValue(c);

      await service.update('c1', owner, { title: ' Nuevo titulo ', description: ' Hola ' });

      expect(campaignRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ title: 'Nuevo titulo', description: 'Hola' }),
      );
    });

    it('la fecha de inicio solo cambia antes de empezar', async () => {
      campaignRepo.findOne.mockResolvedValue(activeCampaign());

      await expect(
        service.update('c1', owner, { startsAt: inHours(24) }),
      ).rejects.toThrow('antes de que empiece');
    });

    it('una campaña programada si puede reprogramarse', async () => {
      const c = activeCampaign({ startsAt: new Date(Date.now() + 24 * HOUR) });
      campaignRepo.findOne.mockResolvedValue(c);

      await service.update('c1', owner, { startsAt: inHours(72) });

      expect(c.startsAt.getTime()).toBeGreaterThan(Date.now() + 71 * HOUR);
    });

    it('no edita campañas terminadas o canceladas', async () => {
      campaignRepo.findOne.mockResolvedValue(activeCampaign({ cancelledAt: new Date() }));

      await expect(service.update('c1', owner, { title: 'x y z' })).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('cancela una campaña vigente', async () => {
      const c = activeCampaign();
      campaignRepo.findOne.mockResolvedValue(c);

      await service.cancel('c1', owner);

      expect(c.cancelledAt).toBeInstanceOf(Date);
    });

    it('no cancela dos veces ni una ya terminada', async () => {
      campaignRepo.findOne.mockResolvedValue(activeCampaign({ cancelledAt: new Date() }));
      await expect(service.cancel('c1', owner)).rejects.toThrow('ya estaba cancelada');

      campaignRepo.findOne.mockResolvedValue(activeCampaign({ endsAt: new Date(Date.now() - HOUR) }));
      await expect(service.cancel('c1', owner)).rejects.toThrow('ya terminó');
    });

    it('solo quien gestiona el negocio puede editar o cancelar', async () => {
      campaignRepo.findOne.mockResolvedValue(activeCampaign());
      access.canManage.mockResolvedValue(false);

      await expect(service.update('c1', owner, { title: 'abc' })).rejects.toBeInstanceOf(
        ForbiddenException,
      );
      await expect(service.cancel('c1', owner)).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('falla si la campaña no existe', async () => {
      campaignRepo.findOne.mockResolvedValue(null);

      await expect(service.cancel('c1', owner)).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('claim (tarjeta de regalo)', () => {
    beforeEach(() => {
      campaignRepo.findOne.mockResolvedValue(activeCampaign());
    });

    it('el cliente reclama la tarjeta y recibe un codigo', async () => {
      const claim = await service.claim('u1', 'c1');

      expect(claim.code).toMatch(/^GFT-[2-9A-HJ-NP-Z]{6}$/);
      expect(claim.status).toBe(ClaimStatus.ACTIVE);
    });

    it('reclamar dos veces devuelve la misma tarjeta', async () => {
      claimRepo.findOne.mockResolvedValue({ id: 'cl0', code: 'GFT-AAAAAA', status: 'active', source: 'claim', campaignId: 'c1' });

      const claim = await service.claim('u1', 'c1');

      expect(claim.code).toBe('GFT-AAAAAA');
      expect(claimRepo.save).not.toHaveBeenCalled();
    });

    it('si dos toques chocan en la base devuelve la tarjeta ya creada', async () => {
      claimRepo.save.mockRejectedValue({ code: '23505' });
      claimRepo.findOne
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({ id: 'cl0', code: 'GFT-BBBBBB', status: 'active', source: 'claim', campaignId: 'c1' });

      const claim = await service.claim('u1', 'c1');

      expect(claim.code).toBe('GFT-BBBBBB');
    });

    it('solo los clientes del local pueden reclamarla', async () => {
      cardRepo.exists.mockResolvedValue(false);

      await expect(service.claim('u1', 'c1')).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('no se reclama una campaña que no es tarjeta de regalo', async () => {
      campaignRepo.findOne.mockResolvedValue(activeCampaign({ type: CampaignType.EVENT }));

      await expect(service.claim('u1', 'c1')).rejects.toThrow('no tiene tarjeta de regalo');
    });

    it('no se reclama una campaña programada, terminada o cancelada', async () => {
      for (const extra of [
        { startsAt: new Date(Date.now() + HOUR) },
        { endsAt: new Date(Date.now() - 1000) },
        { cancelledAt: new Date() },
      ]) {
        campaignRepo.findOne.mockResolvedValue(activeCampaign(extra));
        await expect(service.claim('u1', 'c1')).rejects.toThrow('no está vigente');
      }
    });
  });

  describe('redeem', () => {
    const claimRow = (extra: any = {}) => ({
      id: 'cl1',
      code: 'GFT-ABC234',
      userId: 'u1',
      status: ClaimStatus.ACTIVE,
      campaign: activeCampaign(),
      user: { fullName: 'Luis Mora' },
      ...extra,
    });

    it('canjea el codigo (sin importar mayusculas ni espacios) y avisa al cliente', async () => {
      claimRepo.findOne.mockResolvedValue(claimRow());

      const result = await service.redeem(owner, '  gft-abc234 ');

      expect(claimRepo.findOne.mock.calls[0][0].where).toEqual({ code: 'GFT-ABC234' });
      expect(result).toMatchObject({
        status: ClaimStatus.REDEEMED,
        benefitLabel: '20% de descuento',
        userName: 'Luis Mora',
      });
      expect(claimRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ status: ClaimStatus.REDEEMED, redeemedById: 'owner-1' }),
      );
      expect(notifications.sendToUser).toHaveBeenCalledWith('u1', expect.any(String), expect.any(String), expect.anything());
    });

    it('un codigo inexistente no es valido', async () => {
      await expect(service.redeem(owner, 'XXX-000000')).rejects.toBeInstanceOf(NotFoundException);
    });

    it('un codigo ya canjeado no se canjea otra vez', async () => {
      claimRepo.findOne.mockResolvedValue(claimRow({ status: ClaimStatus.REDEEMED }));

      await expect(service.redeem(owner, 'GFT-ABC234')).rejects.toBeInstanceOf(ConflictException);
      expect(claimRepo.save).not.toHaveBeenCalled();
    });

    it('no canjea si la campaña termino o fue cancelada', async () => {
      claimRepo.findOne.mockResolvedValue(
        claimRow({ campaign: activeCampaign({ endsAt: new Date(Date.now() - 1000) }) }),
      );
      await expect(service.redeem(owner, 'GFT-ABC234')).rejects.toThrow('ya terminó');

      claimRepo.findOne.mockResolvedValue(
        claimRow({ campaign: activeCampaign({ cancelledAt: new Date() }) }),
      );
      await expect(service.redeem(owner, 'GFT-ABC234')).rejects.toThrow('cancelada');
    });

    it('solo opera quien trabaja en alguno de los locales participantes', async () => {
      claimRepo.findOne.mockResolvedValue(claimRow());
      access.canOperate.mockResolvedValue(false);

      await expect(service.redeem(owner, 'GFT-ABC234')).rejects.toBeInstanceOf(ForbiddenException);
      expect(claimRepo.save).not.toHaveBeenCalled();
    });

    it('un aprobador del local puede canjear', async () => {
      claimRepo.findOne.mockResolvedValue(claimRow());

      await service.redeem({ id: 'ap-1', role: UserRole.APPROVER }, 'GFT-ABC234');

      expect(access.canOperate).toHaveBeenCalledWith('ap-1', UserRole.APPROVER, 'b1');
    });
  });

  describe('feed', () => {
    it('sin tarjetas no hay novedades', async () => {
      cardRepo.find.mockResolvedValue([]);

      expect(await service.feed('u1')).toEqual([]);
      expect(campaignRepo.find).not.toHaveBeenCalled();
    });

    it('no incluye las campañas internas (el premio de un minijuego ya ganado)', async () => {
      cardRepo.find.mockResolvedValue([{ businessId: 'b1' }]);
      participantRepo.find.mockResolvedValue([{ campaignId: 'c1' }]);
      campaignRepo.find.mockResolvedValue([]);

      await service.feed('u1');

      // Las dos variantes de la búsqueda (con y sin fecha de fin) excluyen las ocultas.
      const where = campaignRepo.find.mock.calls[0][0].where as any[];
      expect(where).toHaveLength(2);
      for (const condition of where) expect(condition).toMatchObject({ hidden: false });
    });

    it('arma las novedades con la tarjeta y los sellos del cliente', async () => {
      cardRepo.find.mockResolvedValue([{ businessId: 'b1' }]);
      participantRepo.find.mockResolvedValue([{ campaignId: 'c1' }, { campaignId: 'c2' }]);
      campaignRepo.find.mockResolvedValue([
        activeCampaign({ id: 'c1' }),
        activeCampaign({
          id: 'c2',
          type: CampaignType.ROUTE,
          requiredStamps: 2,
          participants: [
            { businessId: 'b1', business: { name: 'A' } },
            { businessId: 'b2', business: { name: 'B' } },
          ],
        }),
      ]);
      claimRepo.find.mockResolvedValue([
        { id: 'cl1', campaignId: 'c1', code: 'GFT-AAAAAA', status: 'active', source: 'claim' },
      ]);
      stampRepo.find.mockResolvedValue([{ campaignId: 'c2', businessId: 'b1' }]);

      const feed = await service.feed('u1');

      expect(feed).toHaveLength(2);
      expect(feed[0]).toMatchObject({ id: 'c1', phase: 'active', claim: { code: 'GFT-AAAAAA' }, completed: false });
      expect(feed[1]).toMatchObject({ id: 'c2', claim: null, stampedBusinessIds: ['b1'], completed: false });
    });
  });

  describe('registerApprovedScan (rutas)', () => {
    const route = (extra: any = {}) =>
      activeCampaign({
        id: 'r1',
        type: CampaignType.ROUTE,
        title: 'Ruta del café',
        requiredStamps: 2,
        benefitLabel: 'Taza de regalo',
        participants: [{ businessId: 'b1' }, { businessId: 'b2' }],
        ...extra,
      });
    const scan = (extra: any = {}) => ({
      id: 's1',
      userId: 'u1',
      businessId: 'b1',
      qrCodeId: 'qr-1',
      scannedAt: new Date(),
      ...extra,
    });

    beforeEach(() => {
      participantRepo.find.mockResolvedValue([{ campaign: route() }]);
    });

    it('suma un sello y avisa el avance', async () => {
      stampRepo.count.mockResolvedValue(1);

      expect(await service.registerApprovedScan(scan())).toBe(1);

      expect(stampRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ campaignId: 'r1', userId: 'u1', businessId: 'b1', scanId: 's1' }),
      );
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'u1',
        expect.stringContaining('Ruta del café'),
        expect.stringContaining('1 de 2'),
        expect.anything(),
      );
      expect(claimRepo.save).not.toHaveBeenCalled();
    });

    it('al completar los sellos emite el premio de la ruta', async () => {
      stampRepo.count.mockResolvedValue(2);

      await service.registerApprovedScan(scan());

      const created = claimRepo.create.mock.calls[0][0];
      expect(created).toMatchObject({ campaignId: 'r1', userId: 'u1', source: ClaimSource.ROUTE_COMPLETE });
      expect(created.code).toMatch(/^RTA-/);
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'u1',
        expect.stringContaining('Completaste'),
        expect.stringContaining('Taza de regalo'),
        expect.anything(),
      );
    });

    it('no emite un segundo premio si ya existe', async () => {
      stampRepo.count.mockResolvedValue(3);
      claimRepo.findOne.mockResolvedValue({ id: 'cl9' });

      await service.registerApprovedScan(scan());

      expect(claimRepo.save).not.toHaveBeenCalled();
    });

    it('un local que ya dio su sello no suma otro', async () => {
      stampRepo.exists.mockResolvedValue(true);

      expect(await service.registerApprovedScan(scan())).toBe(0);
      expect(stampRepo.save).not.toHaveBeenCalled();
    });

    it('los puntos regalados a mano (sin QR) no cuentan', async () => {
      expect(await service.registerApprovedScan(scan({ qrCodeId: null }))).toBe(0);
      expect(participantRepo.find).not.toHaveBeenCalled();
    });

    it('solo cuentan las rutas vigentes al momento del escaneo', async () => {
      participantRepo.find.mockResolvedValue([
        { campaign: route({ cancelledAt: new Date() }) },
        { campaign: route({ id: 'r2', endsAt: new Date(Date.now() - HOUR) }) },
        { campaign: route({ id: 'r3', startsAt: new Date(Date.now() + HOUR) }) },
        { campaign: activeCampaign({ id: 'g1' }) }, // una tarjeta de regalo no da sellos
      ]);

      expect(await service.registerApprovedScan(scan())).toBe(0);
    });

    it('si falla el aviso igual queda el sello', async () => {
      stampRepo.count.mockResolvedValue(1);
      notifications.sendToUser.mockRejectedValue(new Error('fcm caido'));

      expect(await service.registerApprovedScan(scan())).toBe(1);
    });
  });

  describe('reto de escaneos', () => {
    const challengeDto = (extra: any = {}) => ({
      type: CampaignType.SCAN_CHALLENGE,
      title: '5 escaneos esta semana',
      benefitType: CampaignBenefit.DISCOUNT_PERCENT,
      benefitValue: 15,
      requiredScans: 5,
      businessIds: ['b1'],
      ...extra,
    });

    describe('crear', () => {
      beforeEach(() => {
        campaignRepo.findOne.mockResolvedValue(activeCampaign());
      });

      it('guarda los escaneos requeridos y el premio del reto', async () => {
        await service.create(owner, challengeDto() as any);

        expect(campaignRepo.create.mock.calls[0][0]).toMatchObject({
          type: CampaignType.SCAN_CHALLENGE,
          requiredScans: 5,
          benefitType: CampaignBenefit.DISCOUNT_PERCENT,
          benefitValue: 15,
          benefitLabel: '15% de descuento',
          requiredStamps: null,
          audience: 'all',
        });
      });

      it('un mini premio lleva su descripción', async () => {
        await service.create(
          owner,
          challengeDto({ benefitType: CampaignBenefit.MINI_PRIZE, benefitValue: undefined, benefitLabel: ' Café gratis ' }) as any,
        );

        expect(campaignRepo.create.mock.calls[0][0]).toMatchObject({
          benefitType: CampaignBenefit.MINI_PRIZE,
          benefitLabel: 'Café gratis',
        });
      });

      it('exige cuántos escaneos y el premio', async () => {
        await expect(service.create(owner, challengeDto({ requiredScans: undefined }) as any)).rejects.toThrow(
          'cuántos escaneos',
        );
        await expect(service.create(owner, challengeDto({ benefitType: undefined }) as any)).rejects.toThrow(
          'Elige el beneficio',
        );
        await expect(
          service.create(owner, challengeDto({ benefitType: CampaignBenefit.MINI_PRIZE, benefitValue: undefined }) as any),
        ).rejects.toThrow('Describe el mini premio');
        expect(campaignRepo.save).not.toHaveBeenCalled();
      });

      it('puede participar más de un local del dueño', async () => {
        businessRepo.find.mockResolvedValue([biz('b1'), biz('b2')]);

        await service.create(owner, challengeDto({ businessIds: ['b1', 'b2'] }) as any);

        expect(participantRepo.save).toHaveBeenCalled();
      });

      it('empieza y avisa como cualquier campaña', async () => {
        await service.create(owner, challengeDto() as any);
        await new Promise((r) => setImmediate(r));

        expect(campaignRepo.update).toHaveBeenCalled(); // se marca avisada antes de mandar
      });
    });

    describe('avance y premio al escanear', () => {
      const challenge = (extra: any = {}) =>
        activeCampaign({
          id: 'ch1',
          type: CampaignType.SCAN_CHALLENGE,
          title: '5 escaneos',
          requiredScans: 5,
          benefitLabel: '15% de descuento',
          startsAt: new Date(Date.now() - 3 * HOUR),
          participants: [{ businessId: 'b1' }],
          ...extra,
        });
      const scan = (extra: any = {}) => ({
        id: 's1',
        userId: 'u1',
        businessId: 'b1',
        qrCodeId: 'qr-1',
        scannedAt: new Date(),
        ...extra,
      });

      beforeEach(() => {
        participantRepo.find.mockResolvedValue([{ campaign: challenge() }]);
      });

      it('cada escaneo suma al avance y avisa cuántos lleva', async () => {
        scanRepo.count.mockResolvedValue(3);

        await service.registerApprovedScan(scan());

        expect(notifications.sendToUser).toHaveBeenCalledWith(
          'u1',
          'Reto: 5 escaneos',
          'Llevas 3 de 5 escaneos. ¡Sigue así!',
          { type: 'challenge_progress', campaign_id: 'ch1' },
        );
        expect(claimRepo.save).not.toHaveBeenCalled();
      });

      it('al llegar al número pedido entrega el premio con su código y avisa', async () => {
        scanRepo.count.mockResolvedValue(5);

        await service.registerApprovedScan(scan());

        expect(claimRepo.create).toHaveBeenCalledWith(
          expect.objectContaining({
            campaignId: 'ch1',
            userId: 'u1',
            status: ClaimStatus.ACTIVE,
            source: ClaimSource.CHALLENGE_COMPLETE,
          }),
        );
        expect(claimRepo.create.mock.calls[0][0].code).toMatch(/^RTO-[2-9A-HJ-NP-Z]{6}$/);
        expect(notifications.sendToUser).toHaveBeenCalledWith(
          'u1',
          '¡Completaste el reto 5 escaneos!',
          'Tu premio: 15% de descuento. Ábrelo en Mis regalos.',
          { type: 'challenge_completed', campaign_id: 'ch1', route: '/my_gifts' },
        );
      });

      it('si ya tenía el premio no se lo da otra vez', async () => {
        scanRepo.count.mockResolvedValue(7);
        claimRepo.findOne.mockResolvedValue({ id: 'ya' });

        await service.registerApprovedScan(scan());

        expect(claimRepo.save).not.toHaveBeenCalled();
        expect(notifications.sendToUser).not.toHaveBeenCalled();
      });

      it('dos escaneos a la vez: la restricción única evita el premio doble', async () => {
        scanRepo.count.mockResolvedValue(5);
        claimRepo.save.mockRejectedValueOnce({ code: '23505' });

        await expect(service.registerApprovedScan(scan())).resolves.toBe(0);
        expect(notifications.sendToUser).not.toHaveBeenCalled();
      });

      it('solo cuentan los escaneos reales de un QR: un punto regalado no suma', async () => {
        await service.registerApprovedScan(scan({ qrCodeId: null }));

        expect(scanRepo.count).not.toHaveBeenCalled();
        expect(notifications.sendToUser).not.toHaveBeenCalled();
      });

      it('un reto que ya terminó o está programado no suma', async () => {
        participantRepo.find.mockResolvedValue([
          { campaign: challenge({ endsAt: new Date(Date.now() - HOUR) }) },
          { campaign: challenge({ startsAt: new Date(Date.now() + HOUR) }) },
          { campaign: challenge({ cancelledAt: new Date() }) },
        ]);

        await service.registerApprovedScan(scan());

        expect(scanRepo.count).not.toHaveBeenCalled();
      });

      it('cuenta los escaneos aprobados con QR del cliente en los locales del reto, desde que empezó', async () => {
        const startsAt = new Date(Date.now() - 3 * HOUR);
        const endsAt = new Date(Date.now() + 3 * HOUR);
        participantRepo.find.mockResolvedValue([
          { campaign: challenge({ startsAt, endsAt, participants: [{ businessId: 'b1' }, { businessId: 'b2' }] }) },
        ]);
        scanRepo.count.mockResolvedValue(1);

        await service.registerApprovedScan(scan());

        const where = scanRepo.count.mock.calls[0][0].where;
        expect(where.userId).toBe('u1');
        expect(where.status).toBe('approved');
        expect(where.businessId._value).toEqual(['b1', 'b2']);
        expect(where.scannedAt._value).toEqual([startsAt, endsAt]);
      });

      it('un reto sin fin cuenta todo lo posterior al inicio', async () => {
        const startsAt = new Date(Date.now() - 3 * HOUR);
        participantRepo.find.mockResolvedValue([{ campaign: challenge({ startsAt, endsAt: null }) }]);

        await service.registerApprovedScan(scan());

        expect(scanRepo.count.mock.calls[0][0].where.scannedAt._value).toEqual(startsAt);
      });

      it('no cambia lo que devuelve para las rutas (solo cuenta sellos)', async () => {
        scanRepo.count.mockResolvedValue(2);

        expect(await service.registerApprovedScan(scan())).toBe(0);
      });

      it('un reto en otro local no se toca', async () => {
        participantRepo.find.mockResolvedValue([]);

        await service.registerApprovedScan(scan({ businessId: 'b9' }));

        expect(scanRepo.count).not.toHaveBeenCalled();
      });
    });

    describe('novedades del cliente', () => {
      it('muestra su avance en el reto y marca cuando lo completó', async () => {
        cardRepo.find.mockResolvedValue([{ businessId: 'b1' }]);
        participantRepo.find.mockResolvedValue([{ campaignId: 'ch1' }, { campaignId: 'ch2' }]);
        campaignRepo.find.mockResolvedValue([
          activeCampaign({ id: 'ch1', type: CampaignType.SCAN_CHALLENGE, requiredScans: 5 }),
          activeCampaign({ id: 'ch2', type: CampaignType.SCAN_CHALLENGE, requiredScans: 3 }),
        ]);
        claimRepo.find.mockResolvedValue([
          { id: 'cl', campaignId: 'ch2', code: 'RTO-AAAAAA', status: 'active', source: ClaimSource.CHALLENGE_COMPLETE },
        ]);
        scanRepo.count.mockResolvedValueOnce(2).mockResolvedValueOnce(3);

        const feed: any[] = await service.feed('u1');

        expect(feed[0]).toMatchObject({ id: 'ch1', requiredScans: 5, scanProgress: 2, completed: false });
        expect(feed[1]).toMatchObject({ id: 'ch2', requiredScans: 3, scanProgress: 3, completed: true });
        expect(feed[1].claim.code).toBe('RTO-AAAAAA');
      });

      it('una gift card o un evento no calculan avance', async () => {
        cardRepo.find.mockResolvedValue([{ businessId: 'b1' }]);
        participantRepo.find.mockResolvedValue([{ campaignId: 'c1' }]);
        campaignRepo.find.mockResolvedValue([activeCampaign({ id: 'c1' })]);

        const [item]: any[] = await service.feed('u1');

        expect(scanRepo.count).not.toHaveBeenCalled();
        expect(item.scanProgress).toBe(0);
      });
    });

    describe('aviso de lanzamiento', () => {
      it('dice cuántos escaneos pide y el premio', async () => {
        campaignRepo.findOne.mockResolvedValue(
          activeCampaign({
            id: 'ch1',
            type: CampaignType.SCAN_CHALLENGE,
            title: '5 escaneos',
            requiredScans: 5,
            benefitLabel: '15% de descuento',
            participants: [{ businessId: 'b1', business: { name: 'Café Aurora' } }],
          }),
        );
        cardRepo.find.mockResolvedValue([{ userId: 'u1' }]);
        campaignRepo.update.mockResolvedValue({ affected: 1 });

        await service.dispatch('ch1');

        expect(notifications.sendToUsers).toHaveBeenCalledWith(
          expect.any(Array),
          'Nuevo reto: 5 escaneos',
          'Haz 5 escaneos en Café Aurora y gana: 15% de descuento.',
          expect.objectContaining({ type: 'campaign', campaign_id: 'ch1' }),
        );
      });
    });

    it('la vista del reto incluye los escaneos requeridos', () => {
      const view = service.toView(
        activeCampaign({ type: CampaignType.SCAN_CHALLENGE, requiredScans: 4 }),
      );

      expect(view.requiredScans).toBe(4);
    });
  });

  describe('dispatch y dispatchDue', () => {
    it('avisa a la audiencia una sola vez (marca notifiedAt antes de enviar)', async () => {
      campaignRepo.findOne.mockResolvedValue(
        activeCampaign({ type: CampaignType.EVENT, description: 'Noche de música en vivo' }),
      );
      cardRepo.find.mockResolvedValue([{ userId: 'u1' }, { userId: 'u2' }]);

      const sent = await service.dispatch('c1');

      expect(sent).toBe(3);
      expect(campaignRepo.update).toHaveBeenCalledWith(
        { id: 'c1', notifiedAt: expect.anything() },
        { notifiedAt: expect.any(Date) },
      );
      expect(notifications.sendToUsers).toHaveBeenCalledWith(
        ['u1', 'u2'],
        'Regalo de aniversario',
        'Noche de música en vivo',
        expect.anything(),
      );
    });

    it('si otro proceso ya la marco, no envia de nuevo', async () => {
      campaignRepo.update.mockResolvedValue({ affected: 0 });

      expect(await service.dispatch('c1')).toBe(0);
      expect(notifications.sendToUsers).not.toHaveBeenCalled();
    });

    it('sin clientes no envia nada', async () => {
      campaignRepo.findOne.mockResolvedValue(activeCampaign());
      cardRepo.find.mockResolvedValue([]);

      expect(await service.dispatch('c1')).toBe(0);
      expect(notifications.sendToUsers).not.toHaveBeenCalled();
    });

    it('limita la audiencia por campaña', async () => {
      campaignRepo.findOne.mockResolvedValue(activeCampaign());
      cardRepo.find.mockResolvedValue(
        Array.from({ length: MAX_AUDIENCE + 10 }, (_, i) => ({ userId: `u${i}` })),
      );

      await service.dispatch('c1');

      expect(notifications.sendToUsers.mock.calls[0][0]).toHaveLength(MAX_AUDIENCE);
    });

    it('dispatchDue procesa las campañas vencidas sin avisar', async () => {
      campaignRepo.find.mockResolvedValue([{ id: 'c1' }, { id: 'c2' }]);
      campaignRepo.findOne.mockResolvedValue(activeCampaign());
      cardRepo.find.mockResolvedValue([{ userId: 'u1' }]);

      expect(await service.dispatchDue()).toBe(2);
      expect(campaignRepo.update).toHaveBeenCalledTimes(2);
    });

    it('el aviso de una ruta indica los sellos y el premio', async () => {
      campaignRepo.findOne.mockResolvedValue(
        activeCampaign({
          type: CampaignType.ROUTE,
          title: 'Ruta del café',
          requiredStamps: 3,
          benefitLabel: 'Taza de regalo',
          participants: [{ businessId: 'b1' }, { businessId: 'b2' }, { businessId: 'b3' }],
        }),
      );
      cardRepo.find.mockResolvedValue([{ userId: 'u1' }]);

      await service.dispatch('c1');

      expect(notifications.sendToUsers).toHaveBeenCalledWith(
        ['u1'],
        'Nueva ruta: Ruta del café',
        expect.stringContaining('3 locales'),
        expect.anything(),
      );
    });
  });

  describe('gift cards: entrega automática, edición y avisos', () => {
    const gift = (extra: any = {}) => activeCampaign({ audience: 'all', ...extra });

    describe('crear con audiencia', () => {
      const giftDto = (extra: any = {}) => ({
        type: CampaignType.GIFT_CARD,
        title: 'Regalo de aniversario',
        benefitType: CampaignBenefit.DISCOUNT_PERCENT,
        benefitValue: 20,
        businessIds: ['b1'],
        ...extra,
      });

      beforeEach(() => {
        campaignRepo.findOne.mockResolvedValue(gift());
      });

      it('por defecto llega a todos los clientes', async () => {
        await service.create(owner, giftDto() as any);

        expect(campaignRepo.create.mock.calls[0][0].audience).toBe('all');
        expect(recipientRepo.save).not.toHaveBeenCalled();
      });

      it('con clientes elegidos guarda a los destinatarios', async () => {
        cardRepo.find.mockResolvedValue([{ userId: 'u1' }, { userId: 'u2' }]);

        await service.create(owner, giftDto({ audience: 'selected', recipientIds: ['u1', 'u2', 'u1'] }) as any);

        expect(campaignRepo.create.mock.calls[0][0].audience).toBe('selected');
        expect(recipientRepo.save).toHaveBeenCalledWith([
          expect.objectContaining({ campaignId: 'c1', userId: 'u1' }),
          expect.objectContaining({ campaignId: 'c1', userId: 'u2' }),
        ]);
      });

      it('elegir clientes exige al menos uno', async () => {
        await expect(
          service.create(owner, giftDto({ audience: 'selected', recipientIds: [] }) as any),
        ).rejects.toThrow('al menos un cliente');
        expect(campaignRepo.save).not.toHaveBeenCalled();
      });

      it('solo se eligen personas que ya son clientes del negocio', async () => {
        cardRepo.find.mockResolvedValue([{ userId: 'u1' }]); // u2 no es cliente

        await expect(
          service.create(owner, giftDto({ audience: 'selected', recipientIds: ['u1', 'u2'] }) as any),
        ).rejects.toThrow('no son clientes');
        expect(campaignRepo.save).not.toHaveBeenCalled();
      });

      it('sin plantilla no guarda ninguna (la API no la puede pedir)', async () => {
        await service.create(owner, giftDto({ template: 'birthday' }) as any);

        expect(campaignRepo.create.mock.calls[0][0].template).toBeNull();
      });

      it('con la plantilla de cumpleaños (solo el servidor) la guarda', async () => {
        await service.create(owner, giftDto() as any, { template: 'birthday' });

        expect(campaignRepo.create.mock.calls[0][0].template).toBe('birthday');
      });

      it('la vista de la campaña incluye la plantilla', () => {
        expect(service.toView(gift({ template: 'birthday' }) as any).template).toBe('birthday');
        expect(service.toView(gift() as any).template).toBeNull();
      });

      it('un evento ignora la audiencia elegida', async () => {
        await service.create(
          owner,
          giftDto({ type: CampaignType.EVENT, audience: 'selected', recipientIds: ['u1'] }) as any,
        );

        expect(campaignRepo.create.mock.calls[0][0].audience).toBe('all');
      });
    });

    describe('entrega al empezar (dispatch)', () => {
      it('le emite su propia gift card, con código, a cada cliente y se lo avisa', async () => {
        campaignRepo.findOne.mockResolvedValue(gift());
        cardRepo.find.mockResolvedValue([{ userId: 'u1' }, { userId: 'u2' }, { userId: 'u1' }]);

        const sent = await service.dispatch('c1');

        expect(sent).toBe(3);
        const rows = claimRepo.save.mock.calls[0][0];
        expect(rows.map((r: any) => r.userId)).toEqual(['u1', 'u2']);
        for (const row of rows) {
          expect(row.code).toMatch(/^GFT-[2-9A-HJ-NP-Z]{6}$/);
          expect(row.status).toBe(ClaimStatus.ACTIVE);
        }
        expect(new Set(rows.map((r: any) => r.code)).size).toBe(2);
        expect(notifications.sendToUsers).toHaveBeenCalledWith(
          ['u1', 'u2'],
          expect.stringContaining('te regaló una gift card'),
          expect.stringContaining('Mis regalos'),
          { type: 'gift_card', campaign_id: 'c1', route: '/my_gifts' },
        );
      });

      it('la gift card de cumpleaños avisa que vale solo ese día', async () => {
        campaignRepo.findOne.mockResolvedValue(gift({ template: 'birthday' }));
        cardRepo.find.mockResolvedValue([{ userId: 'u1' }]);

        await service.dispatch('c1');

        expect(notifications.sendToUsers).toHaveBeenCalledWith(
          ['u1'],
          expect.stringContaining('te regaló una gift card de cumpleaños'),
          expect.stringContaining('Vale solo hoy'),
          { type: 'gift_card', campaign_id: 'c1', route: '/my_gifts' },
        );
      });

      it('no repite la gift card a quien ya la tiene', async () => {
        campaignRepo.findOne.mockResolvedValue(gift());
        cardRepo.find.mockResolvedValue([{ userId: 'u1' }, { userId: 'u2' }]);
        claimRepo.find.mockResolvedValue([{ userId: 'u1' }]);

        await service.dispatch('c1');

        expect(claimRepo.save.mock.calls[0][0].map((r: any) => r.userId)).toEqual(['u2']);
        expect(notifications.sendToUsers.mock.calls[0][0]).toEqual(['u2']);
      });

      it('con clientes elegidos solo les llega a ellos', async () => {
        campaignRepo.findOne.mockResolvedValue(gift({ audience: 'selected' }));
        recipientRepo.find.mockResolvedValue([{ userId: 'u7' }, { userId: 'u8' }]);
        cardRepo.find.mockResolvedValue([{ userId: 'u1' }, { userId: 'u2' }, { userId: 'u7' }]);

        await service.dispatch('c1');

        expect(claimRepo.save.mock.calls[0][0].map((r: any) => r.userId)).toEqual(['u7', 'u8']);
        expect(notifications.sendToUsers.mock.calls[0][0]).toEqual(['u7', 'u8']);
      });

      it('si un lote choca en la base, las emite una por una y sigue', async () => {
        campaignRepo.findOne.mockResolvedValue(gift());
        cardRepo.find.mockResolvedValue([{ userId: 'u1' }, { userId: 'u2' }]);
        claimRepo.save
          .mockRejectedValueOnce(new Error('lote'))
          .mockRejectedValueOnce({ code: '23505' }) // u1 ya la tenía
          .mockImplementationOnce((row: any) => Promise.resolve(row)); // u2

        await service.dispatch('c1');

        expect(notifications.sendToUsers.mock.calls[0][0]).toEqual(['u2']);
      });

      it('sin ninguna entrega nueva no avisa a nadie', async () => {
        campaignRepo.findOne.mockResolvedValue(gift());
        cardRepo.find.mockResolvedValue([{ userId: 'u1' }]);
        claimRepo.find.mockResolvedValue([{ userId: 'u1' }]);

        expect(await service.dispatch('c1')).toBe(0);
        expect(notifications.sendToUsers).not.toHaveBeenCalled();
      });
    });

    describe('reclamar una gift card de clientes elegidos', () => {
      it('quien no fue elegido no puede reclamarla', async () => {
        campaignRepo.findOne.mockResolvedValue(gift({ audience: 'selected' }));
        recipientRepo.exists.mockResolvedValue(false);

        await expect(service.claim('u1', 'c1')).rejects.toBeInstanceOf(ForbiddenException);
      });

      it('quien fue elegido sí', async () => {
        campaignRepo.findOne.mockResolvedValue(gift({ audience: 'selected' }));
        recipientRepo.exists.mockResolvedValue(true);

        const claim = await service.claim('u1', 'c1');

        expect(claim.code).toMatch(/^GFT-/);
      });
    });

    describe('editar la gift card', () => {
      it('cambiar el descuento regenera el texto y avisa a quienes ya la tienen', async () => {
        const c = gift();
        campaignRepo.findOne.mockResolvedValue(c);
        claimRepo.find.mockResolvedValue([{ userId: 'u1' }, { userId: 'u2' }]);

        await service.update('c1', owner, { benefitValue: 30 });

        expect(c.benefitValue).toBe(30);
        expect(c.benefitLabel).toBe('30% de descuento');
        expect(notifications.sendToUsers).toHaveBeenCalledWith(
          ['u1', 'u2'],
          'Tu gift card cambió',
          expect.stringContaining('30% de descuento'),
          expect.objectContaining({ type: 'gift_card_updated' }),
        );
      });

      it('un texto propio del descuento se respeta', async () => {
        const c = gift();
        campaignRepo.findOne.mockResolvedValue(c);

        await service.update('c1', owner, { benefitValue: 15, benefitLabel: ' 15% en todo el menú ' });

        expect(c.benefitLabel).toBe('15% en todo el menú');
      });

      it('un mini premio se edita con su descripción', async () => {
        const c = gift({ benefitType: CampaignBenefit.MINI_PRIZE, benefitValue: null, benefitLabel: 'Café' });
        campaignRepo.findOne.mockResolvedValue(c);

        await service.update('c1', owner, { benefitLabel: ' Café grande ' });

        expect(c.benefitLabel).toBe('Café grande');
        await expect(service.update('c1', owner, { benefitValue: 10 })).rejects.toThrow('no lleva porcentaje');
        await expect(service.update('c1', owner, { benefitLabel: '  ' })).rejects.toThrow('Describe el mini premio');
      });

      it('solo las gift cards tienen beneficio editable', async () => {
        campaignRepo.findOne.mockResolvedValue(gift({ type: CampaignType.EVENT }));

        await expect(service.update('c1', owner, { benefitLabel: 'x' })).rejects.toThrow('Solo las gift cards');
      });

      it('cambiar solo el título no molesta a los clientes', async () => {
        campaignRepo.findOne.mockResolvedValue(gift());

        await service.update('c1', owner, { title: 'Nuevo nombre' });

        expect(notifications.sendToUsers).not.toHaveBeenCalled();
      });

      it('cambiar la fecha de fin también les avisa', async () => {
        campaignRepo.findOne.mockResolvedValue(gift());
        claimRepo.find.mockResolvedValue([{ userId: 'u1' }]);

        await service.update('c1', owner, { endsAt: inHours(72) });

        expect(notifications.sendToUsers).toHaveBeenCalled();
      });

      it('si falla el aviso, la edición igual se guarda', async () => {
        campaignRepo.findOne.mockResolvedValue(gift());
        claimRepo.find.mockResolvedValue([{ userId: 'u1' }]);
        notifications.sendToUsers.mockRejectedValue(new Error('push caido'));

        await expect(service.update('c1', owner, { benefitValue: 40 })).resolves.toBeDefined();
        expect(campaignRepo.save).toHaveBeenCalled();
      });
    });

    describe('cancelar la gift card', () => {
      it('avisa a quienes la tenían sin canjear', async () => {
        campaignRepo.findOne.mockResolvedValue(gift());
        claimRepo.find.mockResolvedValue([{ userId: 'u1' }]);

        await service.cancel('c1', owner);

        expect(claimRepo.find).toHaveBeenCalledWith(
          expect.objectContaining({ where: { campaignId: 'c1', status: ClaimStatus.ACTIVE } }),
        );
        expect(notifications.sendToUsers).toHaveBeenCalledWith(
          ['u1'],
          'Gift card cancelada',
          expect.stringContaining('Regalo de aniversario'),
          expect.objectContaining({ type: 'gift_card_cancelled' }),
        );
      });

      it('cancelar un evento no avisa a nadie', async () => {
        campaignRepo.findOne.mockResolvedValue(gift({ type: CampaignType.EVENT }));

        await service.cancel('c1', owner);

        expect(notifications.sendToUsers).not.toHaveBeenCalled();
      });
    });

    describe('clientes para elegir', () => {
      const card = (id: string, fullName: string | null, email: string) => ({
        userId: id,
        user: { id, fullName, email },
      });

      it('lista sin repetidos y ordenados por nombre', async () => {
        businessRepo.find.mockResolvedValue([biz('b1'), biz('b2')]);
        cardRepo.find.mockResolvedValue([
          card('u2', 'Zoe Mora', 'zoe@mail.com'),
          card('u1', 'Ana Paz', 'ana@mail.com'),
          card('u2', 'Zoe Mora', 'zoe@mail.com'),
        ]);

        const list = await service.customersFor(owner, ['b1', 'b2']);

        expect(list.map((c) => c.id)).toEqual(['u1', 'u2']);
      });

      it('busca por nombre o correo', async () => {
        businessRepo.find.mockResolvedValue([biz('b1')]);
        cardRepo.find.mockResolvedValue([card('u1', 'Ana Paz', 'ana@mail.com'), card('u2', 'Luis', 'luis@mail.com')]);

        expect((await service.customersFor(owner, ['b1'], 'LUIS')).map((c) => c.id)).toEqual(['u2']);
        expect((await service.customersFor(owner, ['b1'], 'paz')).map((c) => c.id)).toEqual(['u1']);
      });

      it('solo muestra los clientes de negocios propios', async () => {
        businessRepo.find.mockResolvedValue([biz('b1', { ownerId: 'otro' })]);

        await expect(service.customersFor(owner, ['b1'])).rejects.toBeInstanceOf(ForbiddenException);
        expect(cardRepo.find).not.toHaveBeenCalled();
      });

      it('sin negocios no hay clientes y uno inexistente es un error', async () => {
        expect(await service.customersFor(owner, [])).toEqual([]);

        businessRepo.find.mockResolvedValue([]);
        await expect(service.customersFor(owner, ['nope'])).rejects.toBeInstanceOf(BadRequestException);
      });
    });
  });

  describe('listMine', () => {
    it('un dueño sin negocios no tiene campañas', async () => {
      businessRepo.find.mockResolvedValue([]);

      expect(await service.listMine(owner)).toEqual([]);
    });

    it('no lista las campañas internas (los premios de los minijuegos)', async () => {
      businessRepo.find.mockResolvedValue([{ id: 'b1' }]);
      participantRepo.find.mockResolvedValue([{ campaignId: 'c1' }]);
      campaignRepo.find.mockResolvedValue([]);

      await service.listMine(owner);
      await service.listMine({ id: 'admin-1', role: UserRole.ADMIN });

      for (const [options] of campaignRepo.find.mock.calls) {
        expect(options.where).toMatchObject({ hidden: false });
      }
    });

    it('incluye contadores de tarjetas, canjes y participantes', async () => {
      businessRepo.find.mockResolvedValue([{ id: 'b1' }]);
      participantRepo.find.mockResolvedValue([{ campaignId: 'c1' }]);
      campaignRepo.find.mockResolvedValue([activeCampaign()]);
      claimRepo.find.mockResolvedValue([
        { campaignId: 'c1', status: 'active' },
        { campaignId: 'c1', status: 'redeemed' },
      ]);
      stampRepo.find.mockResolvedValue([
        { campaignId: 'c1', userId: 'u1' },
        { campaignId: 'c1', userId: 'u1' },
        { campaignId: 'c1', userId: 'u2' },
      ]);

      const [campaign] = await service.listMine(owner);

      expect(campaign.stats).toEqual({ claims: 2, redeemed: 1, participants: 2, recipients: 0 });
      expect(campaign.phase).toBe('active');
    });

    it('cuenta a los clientes elegidos de una gift card y muestra su audiencia', async () => {
      businessRepo.find.mockResolvedValue([{ id: 'b1' }]);
      participantRepo.find.mockResolvedValue([{ campaignId: 'c1' }]);
      campaignRepo.find.mockResolvedValue([activeCampaign({ audience: 'selected' })]);
      recipientRepo.find.mockResolvedValue([{ campaignId: 'c1' }, { campaignId: 'c1' }, { campaignId: 'otra' }]);

      const [campaign] = await service.listMine(owner);

      expect(campaign.stats.recipients).toBe(2);
      expect(campaign.audience).toBe('selected');
    });
  });
});
