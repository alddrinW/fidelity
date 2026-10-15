import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { BusinessesService, DEFAULT_CATEGORIES } from './businesses.service';
import { Business } from '../../database/entities/business.entity';
import { BusinessCategory } from '../../database/entities/business-category.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Scan } from '../../database/entities/scan.entity';
import { Reward } from '../../database/entities/reward.entity';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import { BusinessAccessService } from './business-access.service';
import { BusinessMember } from '../../database/entities/business-member.entity';

describe('BusinessesService - categorias base', () => {
  let service: BusinessesService;
  let categoryRepo: any;

  beforeEach(async () => {
    categoryRepo = {
      count: jest.fn(),
      create: jest.fn((items) => items),
      save: jest.fn((items) => Promise.resolve(items)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BusinessesService,
        { provide: getRepositoryToken(BusinessCategory), useValue: categoryRepo },
        { provide: getRepositoryToken(Business), useValue: {} },
        { provide: getRepositoryToken(LoyaltyCard), useValue: {} },
        { provide: getRepositoryToken(Scan), useValue: {} },
        { provide: getRepositoryToken(Reward), useValue: {} },
        { provide: getRepositoryToken(Profile), useValue: {} },
        { provide: NotificationsService, useValue: {} },
        { provide: PaymentsService, useValue: {} },
        { provide: BusinessAccessService, useValue: {} },
        { provide: getRepositoryToken(BusinessMember), useValue: {} },
      ],
    }).compile();

    service = module.get(BusinessesService);
  });

  it('crea las categorias base cuando la tabla esta vacia', async () => {
    categoryRepo.count.mockResolvedValue(0);

    const created = await service.seedDefaultCategories();

    expect(created).toBe(DEFAULT_CATEGORIES.length);
    expect(categoryRepo.save).toHaveBeenCalledTimes(1);
    const saved = categoryRepo.save.mock.calls[0][0];
    expect(saved.map((c: any) => c.name)).toEqual(DEFAULT_CATEGORIES.map((c) => c.name));
  });

  it('no toca nada si ya existen categorias', async () => {
    categoryRepo.count.mockResolvedValue(3);

    expect(await service.seedDefaultCategories()).toBe(0);
    expect(categoryRepo.save).not.toHaveBeenCalled();
  });

  it('no impide el arranque si la siembra falla', async () => {
    categoryRepo.count.mockRejectedValue(new Error('db caida'));

    await expect(service.onModuleInit()).resolves.toBeUndefined();
    expect(categoryRepo.save).not.toHaveBeenCalled();
  });

  it('las categorias base tienen nombres unicos', () => {
    const names = DEFAULT_CATEGORIES.map((c) => c.name);
    expect(new Set(names).size).toBe(names.length);
  });
});

describe('BusinessesService - activacion por pago', () => {
  let service: BusinessesService;
  let businessRepo: any;
  let profileRepo: any;
  let notifications: any;
  let payments: any;

  beforeEach(async () => {
    payments = {
      createOrder: jest.fn().mockResolvedValue({ id: 'p1', reference: 'FID-ABC234', status: 'pending' }),
      settleOpenForBusiness: jest.fn().mockResolvedValue(1),
    };
    businessRepo = {
      create: jest.fn((data) => ({ id: 'b1', ...data })),
      save: jest.fn((b) => Promise.resolve(b)),
      findOne: jest.fn(),
    };
    profileRepo = {
      findOne: jest.fn().mockResolvedValue({ id: 'u1', role: 'business', fullName: 'Ana' }),
      save: jest.fn(),
    };
    notifications = {
      broadcastToAdmins: jest.fn().mockResolvedValue(undefined),
      sendToBusinessOwner: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BusinessesService,
        { provide: getRepositoryToken(BusinessCategory), useValue: {} },
        { provide: getRepositoryToken(Business), useValue: businessRepo },
        { provide: getRepositoryToken(LoyaltyCard), useValue: {} },
        { provide: getRepositoryToken(Scan), useValue: {} },
        { provide: getRepositoryToken(Reward), useValue: {} },
        { provide: getRepositoryToken(Profile), useValue: profileRepo },
        { provide: NotificationsService, useValue: notifications },
        { provide: PaymentsService, useValue: payments },
        { provide: BusinessAccessService, useValue: {} },
        { provide: getRepositoryToken(BusinessMember), useValue: {} },
      ],
    }).compile();

    service = module.get(BusinessesService);
  });

  it('un negocio nuevo nace inactivo aunque el cliente envie isActive=true', async () => {
    const saved = await service.createBusiness('u1', {
      name: 'Cafe Aurora',
      isActive: true,
    } as any);

    expect(saved.isActive).toBe(false);
    expect(businessRepo.create.mock.calls[0][0].isActive).toBe(false);
  });

  it('al crear el negocio se genera su orden de pago', async () => {
    const saved: any = await service.createBusiness('u1', { name: 'Cafe Aurora' } as any);

    expect(payments.createOrder).toHaveBeenCalledWith(expect.objectContaining({ id: 'b1' }), 'registration');
    expect(saved.payment.reference).toBe('FID-ABC234');
  });

  it('activar a mano cierra las ordenes de pago abiertas', async () => {
    businessRepo.findOne.mockResolvedValue({ id: 'b1', name: 'Cafe', isActive: false });

    await service.toggleStatus('b1', true, 'admin' as any, 'admin-1');

    expect(payments.settleOpenForBusiness).toHaveBeenCalledWith('b1', 'admin-1');
  });

  it('desactivar no toca las ordenes de pago', async () => {
    businessRepo.findOne.mockResolvedValue({ id: 'b1', name: 'Cafe', isActive: true });

    await service.toggleStatus('b1', false, 'admin' as any, 'admin-1');

    expect(payments.settleOpenForBusiness).not.toHaveBeenCalled();
  });

  it('solo un administrador puede activar un negocio', async () => {
    await expect(service.toggleStatus('b1', true, 'business' as any)).rejects.toThrow();
    expect(businessRepo.save).not.toHaveBeenCalled();
  });

  it('al activar la cuenta se avisa al dueño', async () => {
    businessRepo.findOne.mockResolvedValue({ id: 'b1', name: 'Cafe', isActive: false });

    const result = await service.toggleStatus('b1', true, 'admin' as any);

    expect(result.isActive).toBe(true);
    expect(notifications.sendToBusinessOwner).toHaveBeenCalledWith(
      'b1',
      expect.any(String),
      expect.stringContaining('Cafe'),
      expect.anything(),
    );
  });

  it('desactivar o reactivar uno ya activo no notifica', async () => {
    businessRepo.findOne.mockResolvedValue({ id: 'b1', name: 'Cafe', isActive: true });

    await service.toggleStatus('b1', true, 'admin' as any);
    await service.toggleStatus('b1', false, 'admin' as any);

    expect(notifications.sendToBusinessOwner).not.toHaveBeenCalled();
  });

  it('si falla la notificacion la activacion se mantiene', async () => {
    businessRepo.findOne.mockResolvedValue({ id: 'b1', name: 'Cafe', isActive: false });
    notifications.sendToBusinessOwner.mockRejectedValue(new Error('fcm caido'));

    const result = await service.toggleStatus('b1', true, 'admin' as any);

    expect(result.isActive).toBe(true);
  });
});

describe('BusinessesService - sucursales y matriz', () => {
  let service: BusinessesService;
  let businessRepo: any;
  let cardRepo: any;
  let scanRepo: any;
  let memberRepo: any;
  let payments: any;
  let access: any;

  const qb = (rows: any[]) => {
    const builder: any = {};
    for (const m of ['select', 'addSelect', 'where', 'andWhere', 'groupBy', 'addGroupBy']) {
      builder[m] = jest.fn().mockReturnValue(builder);
    }
    builder.getRawMany = jest.fn().mockResolvedValue(rows);
    return builder;
  };

  beforeEach(async () => {
    businessRepo = {
      create: jest.fn((data) => ({ id: 'b2', ...data })),
      save: jest.fn((b) => Promise.resolve(b)),
      findOne: jest.fn(),
      find: jest.fn(),
    };
    cardRepo = { createQueryBuilder: jest.fn() };
    scanRepo = { createQueryBuilder: jest.fn() };
    memberRepo = { createQueryBuilder: jest.fn() };
    payments = {
      createOrder: jest.fn().mockResolvedValue({ id: 'p1', status: 'pending' }),
      settleOpenForBusiness: jest.fn(),
    };
    access = { businessIdsForMember: jest.fn().mockResolvedValue([]) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BusinessesService,
        { provide: getRepositoryToken(BusinessCategory), useValue: {} },
        { provide: getRepositoryToken(Business), useValue: businessRepo },
        { provide: getRepositoryToken(LoyaltyCard), useValue: cardRepo },
        { provide: getRepositoryToken(Scan), useValue: scanRepo },
        { provide: getRepositoryToken(Reward), useValue: {} },
        {
          provide: getRepositoryToken(Profile),
          useValue: { findOne: jest.fn().mockResolvedValue({ id: 'u1', role: 'business', fullName: 'Ana' }) },
        },
        {
          provide: NotificationsService,
          useValue: { broadcastToAdmins: jest.fn().mockResolvedValue(undefined) },
        },
        { provide: PaymentsService, useValue: payments },
        { provide: BusinessAccessService, useValue: access },
        { provide: getRepositoryToken(BusinessMember), useValue: memberRepo },
      ],
    }).compile();

    service = module.get(BusinessesService);
  });

  describe('createBusiness como sucursal', () => {
    it('una sucursal del mismo dueño genera una orden de tipo sucursal', async () => {
      businessRepo.findOne.mockResolvedValue({ id: 'b1', ownerId: 'u1', parentId: null });

      const saved: any = await service.createBusiness('u1', { name: 'Cafe Norte', parentId: 'b1' } as any);

      expect(saved.parentId).toBe('b1');
      expect(saved.isActive).toBe(false);
      expect(payments.createOrder).toHaveBeenCalledWith(expect.objectContaining({ id: 'b2' }), 'branch');
    });

    it('un negocio sin padre es un registro normal', async () => {
      await service.createBusiness('u1', { name: 'Cafe Aurora' } as any);

      expect(payments.createOrder).toHaveBeenCalledWith(expect.anything(), 'registration');
    });

    it('no acepta como principal el negocio de otro dueño', async () => {
      businessRepo.findOne.mockResolvedValue({ id: 'b1', ownerId: 'otro', parentId: null });

      await expect(
        service.createBusiness('u1', { name: 'Cafe Norte', parentId: 'b1' } as any),
      ).rejects.toThrow('El negocio principal no existe o no es tuyo');
      expect(businessRepo.save).not.toHaveBeenCalled();
    });

    it('no acepta un negocio principal inexistente', async () => {
      businessRepo.findOne.mockResolvedValue(null);

      await expect(
        service.createBusiness('u1', { name: 'Cafe Norte', parentId: 'b1' } as any),
      ).rejects.toThrow();
    });

    it('una sucursal no puede tener sucursales propias', async () => {
      businessRepo.findOne.mockResolvedValue({ id: 'b1', ownerId: 'u1', parentId: 'raiz' });

      await expect(
        service.createBusiness('u1', { name: 'Cafe Norte', parentId: 'b1' } as any),
      ).rejects.toThrow('Una sucursal no puede tener sus propias sucursales');
    });
  });

  describe('findForUser', () => {
    it('un dueño ve sus propios negocios', async () => {
      businessRepo.find.mockResolvedValue([{ id: 'b1' }]);

      await service.findForUser('u1', 'business' as any);

      expect(businessRepo.find).toHaveBeenCalledWith(expect.objectContaining({ where: { ownerId: 'u1' } }));
    });

    it('un aprobador ve solo los negocios donde fue asignado', async () => {
      access.businessIdsForMember.mockResolvedValue(['b1', 'b2']);
      businessRepo.find.mockResolvedValue([{ id: 'b1' }, { id: 'b2' }]);

      const result = await service.findForUser('ap-1', 'approver' as any);

      expect(result).toHaveLength(2);
      expect(businessRepo.find.mock.calls[0][0].where.id._value).toEqual(['b1', 'b2']);
    });

    it('un aprobador sin negocios recibe una lista vacia', async () => {
      expect(await service.findForUser('ap-1', 'approver' as any)).toEqual([]);
      expect(businessRepo.find).not.toHaveBeenCalled();
    });
  });

  describe('getOverview', () => {
    it('devuelve vacio si el dueño no tiene negocios', async () => {
      businessRepo.find.mockResolvedValue([]);

      expect(await service.getOverview('u1')).toEqual([]);
    });

    it('arma las cifras de cada negocio y sucursal', async () => {
      businessRepo.find.mockResolvedValue([
        { id: 'b1', name: 'Cafe Aurora', logoUrl: null, parentId: null, isActive: true },
        { id: 'b2', name: 'Cafe Norte', logoUrl: null, parentId: 'b1', isActive: false },
      ]);
      cardRepo.createQueryBuilder.mockReturnValue(qb([{ businessId: 'b1', n: '12' }]));
      scanRepo.createQueryBuilder
        .mockReturnValueOnce(
          qb([
            { businessId: 'b1', status: 'approved', n: '30' },
            { businessId: 'b1', status: 'pending', n: '2' },
            { businessId: 'b1', status: 'rejected', n: '1' },
          ]),
        )
        .mockReturnValueOnce(qb([{ businessId: 'b1', n: '4' }]));
      memberRepo.createQueryBuilder.mockReturnValue(qb([{ businessId: 'b1', n: '2' }]));

      const overview = await service.getOverview('u1');

      expect(overview).toEqual([
        {
          id: 'b1', name: 'Cafe Aurora', logoUrl: null, parentId: null, isActive: true,
          customers: 12, scansToday: 4, scansTotal: 33, pendingScans: 2, approvers: 2,
        },
        {
          id: 'b2', name: 'Cafe Norte', logoUrl: null, parentId: 'b1', isActive: false,
          customers: 0, scansToday: 0, scansTotal: 0, pendingScans: 0, approvers: 0,
        },
      ]);
    });
  });
});

describe('BusinessesService - datos publicos', () => {
  let service: BusinessesService;
  let businessRepo: any;

  const stored = (overrides: any = {}): any => ({
    id: 'b1',
    ownerId: 'owner-1',
    name: 'Cafe Aurora',
    description: 'Cafeteria',
    taxId: '1790012345001',
    phone: '0991234567',
    isActive: true,
    pointsRequired: 10,
    categoryRef: { id: 1, name: 'Cafeterias' },
    owner: { id: 'owner-1', email: 'ana@mail.com', phone: '0987654321', fcmToken: 'tok-secret' },
    loyaltyCards: [{ id: 'c1', user: { id: 'u1', email: 'cliente@mail.com', fcmToken: 'tok-cliente' } }],
    ...overrides,
  });

  beforeEach(async () => {
    businessRepo = {
      find: jest.fn().mockResolvedValue([stored()]),
      findOne: jest.fn().mockResolvedValue(stored()),
    };
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BusinessesService,
        { provide: getRepositoryToken(BusinessCategory), useValue: {} },
        { provide: getRepositoryToken(Business), useValue: businessRepo },
        { provide: getRepositoryToken(LoyaltyCard), useValue: {} },
        { provide: getRepositoryToken(Scan), useValue: {} },
        { provide: getRepositoryToken(Reward), useValue: {} },
        { provide: getRepositoryToken(Profile), useValue: {} },
        { provide: NotificationsService, useValue: {} },
        { provide: PaymentsService, useValue: {} },
        { provide: BusinessAccessService, useValue: {} },
        { provide: getRepositoryToken(BusinessMember), useValue: {} },
      ],
    }).compile();
    service = module.get(BusinessesService);
  });

  describe('listFor', () => {
    it('un usuario normal solo ve negocios activos y sin datos privados', async () => {
      const [business] = (await service.listFor(UserRole.CLIENT, false)) as any[];

      expect(businessRepo.find).toHaveBeenCalledWith(
        expect.objectContaining({ where: { isActive: true } }),
      );
      expect(business.name).toBe('Cafe Aurora');
      expect(business.categoryRef.name).toBe('Cafeterias');
      expect(business.owner).toBeUndefined();
      expect(business.loyaltyCards).toBeUndefined();
      expect(business.taxId).toBeUndefined();
      expect(business.phone).toBeUndefined();
      expect(JSON.stringify(business)).not.toContain('tok-');
      expect(JSON.stringify(business)).not.toContain('@mail.com');
    });

    it('pedir todos (all=true) está prohibido para quien no es administrador', async () => {
      for (const role of [UserRole.CLIENT, UserRole.BUSINESS, UserRole.APPROVER]) {
        await expect(service.listFor(role, true)).rejects.toBeInstanceOf(ForbiddenException);
      }
      expect(businessRepo.find).not.toHaveBeenCalled();
    });
  });

  describe('findByIdFor', () => {
    it('otro usuario recibe solo los datos publicos', async () => {
      const business: any = await service.findByIdFor('b1', 'otro', UserRole.CLIENT);

      expect(business.name).toBe('Cafe Aurora');
      expect(business.owner).toBeUndefined();
      expect(business.taxId).toBeUndefined();
      expect(JSON.stringify(business)).not.toContain('ana@mail.com');
    });

    it('el dueño ve su negocio completo, sin el token de notificaciones', async () => {
      const business: any = await service.findByIdFor('b1', 'owner-1', UserRole.BUSINESS);

      expect(business.taxId).toBe('1790012345001');
      expect(business.owner.email).toBe('ana@mail.com');
      expect(business.owner.fcmToken).toBeUndefined();
    });

    it('el administrador ve todo, sin tokens de notificaciones', async () => {
      const business: any = await service.findByIdFor('b1', 'admin-1', UserRole.ADMIN);

      expect(business.taxId).toBe('1790012345001');
      expect(business.owner.fcmToken).toBeUndefined();
    });

    it('un negocio inexistente es un 404', async () => {
      businessRepo.findOne.mockResolvedValue(null);

      await expect(service.findByIdFor('nope', 'u', UserRole.CLIENT)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });
});
