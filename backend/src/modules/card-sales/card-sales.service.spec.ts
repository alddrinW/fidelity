import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Business } from '../../database/entities/business.entity';
import { Campaign, CampaignBenefit, CampaignType } from '../../database/entities/campaign.entity';
import {
  CampaignClaim,
  ClaimSource,
  ClaimStatus,
} from '../../database/entities/campaign-claim.entity';
import {
  CardPurchase,
  CardPurchaseMethod,
  CardPurchaseStatus,
} from '../../database/entities/card-purchase.entity';
import { UserRole } from '../../database/entities/profile.entity';
import { CampaignsService } from '../campaigns/campaigns.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import { PayphoneService } from '../payments/payphone.service';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { SettingsService } from '../settings/settings.service';
import { fakeSettings } from '../settings/settings.testing';
import { CARD_SALES_AREA, CardSalesService, usd } from './card-sales.service';

const HOUR = 60 * 60 * 1000;

describe('usd', () => {
  it('muestra los centavos como dólares', () => {
    expect(usd(25)).toBe('$0.25');
    expect(usd(100)).toBe('$1.00');
    expect(usd(1234)).toBe('$12.34');
  });
});

describe('CardSalesService', () => {
  let service: CardSalesService;
  let purchaseRepo: any;
  let campaignRepo: any;
  let claimRepo: any;
  let businessRepo: any;
  let campaigns: any;
  let payphone: any;
  let payments: any;
  let notifications: any;
  let settings: any;
  let manager: any;
  let qb: any;
  let rawRows: any[];

  const offer = (extra: any = {}): any => ({
    id: 'c1',
    businessId: 'b1',
    type: CampaignType.GIFT_CARD,
    title: 'Café por 25 centavos',
    benefitType: CampaignBenefit.MINI_PRIZE,
    benefitLabel: 'Café pequeño',
    priceCents: 25,
    stock: 3,
    cardValidDays: 30,
    startsAt: new Date(Date.now() - HOUR),
    endsAt: null,
    cancelledAt: null,
    participants: [{ businessId: 'b1', business: { id: 'b1', name: 'Café Aurora', isActive: true, ownerId: 'owner-1' } }],
    ...extra,
  });

  const purchase = (extra: any = {}): any => ({
    id: 'p1',
    campaignId: 'c1',
    userId: 'u1',
    businessId: 'b1',
    amountCents: 25,
    commissionCents: 3,
    status: CardPurchaseStatus.PENDING,
    method: CardPurchaseMethod.PAYPHONE,
    reference: 'TJ-ABC234',
    gatewayClientTxId: 'TJ-ABC234-X7K2',
    gatewayPayUrl: 'https://pay.payphonetodoesposible.com/pay/1',
    reservedUntil: new Date(Date.now() + HOUR),
    campaign: offer(),
    user: { fullName: 'Luis Mora' },
    ...extra,
  });

  beforeEach(async () => {
    rawRows = [];
    qb = {};
    for (const m of ['select', 'addSelect', 'where', 'andWhere', 'groupBy', 'innerJoin', 'setLock']) {
      qb[m] = jest.fn().mockReturnValue(qb);
    }
    qb.getRawMany = jest.fn(async () => rawRows);
    qb.getMany = jest.fn().mockResolvedValue([]);

    manager = {
      findOne: jest.fn(async (entity: any) => {
        if (entity === Campaign) return offer();
        if (entity === Business) return { id: 'b1', name: 'Café Aurora', isActive: true, ownerId: 'owner-1' };
        return null;
      }),
      exists: jest.fn().mockResolvedValue(false),
      find: jest.fn().mockResolvedValue([]),
      create: jest.fn((_e: any, d: any) => d),
      save: jest.fn(async (x: any) => (Array.isArray(x) ? x : { id: 'p1', ...x })),
      getRepository: jest.fn(() => ({ createQueryBuilder: jest.fn(() => qb) })),
    };
    purchaseRepo = {
      findOne: jest.fn(),
      find: jest.fn().mockResolvedValue([]),
      create: jest.fn((d: any) => d),
      save: jest.fn(async (x: any) => x),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
      exists: jest.fn().mockResolvedValue(true),
      count: jest.fn().mockResolvedValue(0),
      createQueryBuilder: jest.fn(() => qb),
      manager: { transaction: jest.fn(async (cb: any) => cb(manager)) },
    };
    campaignRepo = { find: jest.fn().mockResolvedValue([]) };
    claimRepo = {
      find: jest.fn().mockResolvedValue([]),
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((d: any) => d),
      save: jest.fn(async (c: any) => ({ id: 'cl1', ...c })),
    };
    businessRepo = { find: jest.fn().mockResolvedValue([{ id: 'b1' }]), findOne: jest.fn() };
    campaigns = { toView: jest.fn((c: any) => ({ id: c.id, title: c.title, priceCents: c.priceCents, stock: c.stock })) };
    payphone = {
      isConfigured: jest.fn().mockReturnValue(true),
      isPayphoneUrl: jest.fn().mockReturnValue(true),
      prepare: jest.fn().mockResolvedValue({ payWithCard: 'https://pay.payphonetodoesposible.com/pay/1' }),
      launchUrl: jest.fn((tx: string, area: string) => `https://api.test/${area}/pay/${tx}`),
      confirm: jest.fn(),
    };
    payments = {
      publicBankAccounts: jest.fn().mockResolvedValue([
        { bank: 'Banco Pichincha', accountNumber: '2200112233', accountType: 'Ahorros', holder: 'Fidelity S.A.', taxId: '1790012345001' },
      ]),
    };
    notifications = {
      sendToUser: jest.fn().mockResolvedValue(true),
      broadcastToAdmins: jest.fn().mockResolvedValue(undefined),
    };
    settings = fakeSettings({ [SETTING_KEYS.paidCardsEnabled]: 1 });

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CardSalesService,
        { provide: getRepositoryToken(CardPurchase), useValue: purchaseRepo },
        { provide: getRepositoryToken(Campaign), useValue: campaignRepo },
        { provide: getRepositoryToken(CampaignClaim), useValue: claimRepo },
        { provide: getRepositoryToken(Business), useValue: businessRepo },
        { provide: CampaignsService, useValue: campaigns },
        { provide: PayphoneService, useValue: payphone },
        { provide: PaymentsService, useValue: payments },
        { provide: SettingsService, useValue: settings },
        { provide: NotificationsService, useValue: notifications },
      ],
    }).compile();
    service = module.get(CardSalesService);
  });

  describe('rules', () => {
    it('devuelve lo que fijó el administrador, con los precios en centavos', async () => {
      settings.get.mockImplementation(async (key: string) => {
        const values: Record<string, number> = {
          [SETTING_KEYS.paidCardsEnabled]: 1,
          [SETTING_KEYS.paidCardsCommissionPercent]: 12,
          [SETTING_KEYS.paidCardsMinPrice]: 0.25,
          [SETTING_KEYS.paidCardsMaxPrice]: 25,
        };
        return values[key];
      });

      expect(await service.rules()).toEqual({
        enabled: true,
        commissionPercent: 12,
        minPriceCents: 25,
        maxPriceCents: 2500,
        cardEnabled: true,
        transferEnabled: false,
        bankAccounts: [],
      });
    });

    it('dice con qué se puede pagar: PayPhone y/o transferencia (si hay cuentas y está encendida)', async () => {
      settings.get.mockImplementation(async (key: string) => (key === SETTING_KEYS.paidCardsTransferEnabled ? 1 : 1));
      expect(await service.rules()).toMatchObject({ cardEnabled: true, transferEnabled: true });

      // Sin cuentas bancarias no hay transferencia.
      payments.publicBankAccounts.mockResolvedValue([]);
      expect((await service.rules()).transferEnabled).toBe(false);

      // Con la transferencia apagada, tampoco.
      payments.publicBankAccounts.mockResolvedValue([{ accountNumber: '1' }]);
      settings.get.mockImplementation(async (key: string) => (key === SETTING_KEYS.paidCardsTransferEnabled ? 0 : 1));
      expect((await service.rules()).transferEnabled).toBe(false);

      // Sin PayPhone configurado, solo transferencia.
      payphone.isConfigured.mockReturnValue(false);
      settings.get.mockResolvedValue(1);
      const rules = await service.rules();
      expect(rules).toMatchObject({ cardEnabled: false, transferEnabled: true });
      // Y trae las cuentas donde transferir.
      expect(rules.bankAccounts).toEqual([{ accountNumber: '1' }]);
    });

    it('apagada por defecto', async () => {
      settings.get.mockImplementation(async (key: string) => (key === SETTING_KEYS.paidCardsEnabled ? 0 : 5));

      expect((await service.rules()).enabled).toBe(false);
    });
  });

  describe('offersFor (lo que ve el cliente)', () => {
    it('con la venta apagada no hay ofertas', async () => {
      settings.get.mockResolvedValue(0);

      expect(await service.offersFor('u1')).toEqual([]);
      expect(campaignRepo.find).not.toHaveBeenCalled();
    });

    it('muestra las ofertas con los cupos que quedan', async () => {
      campaignRepo.find.mockResolvedValue([offer()]);
      rawRows = [{ campaignId: 'c1', n: '1' }];

      const [first] = await service.offersFor('u1');

      expect(first).toMatchObject({ id: 'c1', priceCents: 25, stockLeft: 2, claim: null });
    });

    it('lo agotado ya no se ofrece, salvo a quien ya la compró', async () => {
      campaignRepo.find.mockResolvedValue([offer(), offer({ id: 'c2' })]);
      rawRows = [
        { campaignId: 'c1', n: '3' },
        { campaignId: 'c2', n: '3' },
      ];
      claimRepo.find.mockResolvedValue([
        { campaignId: 'c2', id: 'cl9', code: 'GFT-AAAAAA', status: ClaimStatus.ACTIVE, expiresAt: null },
      ]);

      const offers = await service.offersFor('u1');

      expect(offers.map((o) => o.id)).toEqual(['c2']);
      expect(offers[0].claim).toMatchObject({ code: 'GFT-AAAAAA' });
    });

    it('no ofrece una tarjeta de un local desactivado', async () => {
      campaignRepo.find.mockResolvedValue([
        offer({ participants: [{ businessId: 'b1', business: { isActive: false } }] }),
      ]);

      expect(await service.offersFor('u1')).toEqual([]);
    });
  });

  describe('startPurchase', () => {
    it('reserva el cupo, calcula la comisión y devuelve la página de pago', async () => {
      const result = await service.startPurchase('u1', 'c1', 'luis@correo.com');

      const saved = manager.create.mock.calls[0][1];
      expect(saved).toMatchObject({
        campaignId: 'c1',
        userId: 'u1',
        businessId: 'b1',
        amountCents: 25,
        // 10% de 25 centavos = 2.5, redondeado a 3
        commissionCents: 3,
        status: CardPurchaseStatus.PENDING,
      });
      expect(saved.reference).toMatch(/^TJ-[A-Z0-9]{6}$/);
      expect(saved.gatewayClientTxId).toMatch(/^TJ-[A-Z0-9]{6}-[A-Z0-9]{4}$/);
      expect(saved.reservedUntil.getTime()).toBeGreaterThan(Date.now());

      expect(payphone.prepare).toHaveBeenCalledWith(
        expect.objectContaining({ amountCents: 25, email: 'luis@correo.com', area: CARD_SALES_AREA }),
      );
      expect(result.payUrl).toContain(`/${CARD_SALES_AREA}/pay/`);
      expect(result.reference).toBe(saved.reference);
    });

    it('usa la comisión que fijó el administrador', async () => {
      settings.get.mockImplementation(async (key: string) =>
        key === SETTING_KEYS.paidCardsCommissionPercent ? 20 : 1,
      );
      manager.findOne.mockImplementation(async (entity: any) =>
        entity === Campaign ? offer({ priceCents: 100 }) : { id: 'b1', isActive: true },
      );

      await service.startPurchase('u1', 'c1');

      expect(manager.create.mock.calls[0][1]).toMatchObject({ amountCents: 100, commissionCents: 20 });
    });

    it('bloquea la oferta mientras cuenta los cupos', async () => {
      await service.startPurchase('u1', 'c1');

      expect(manager.findOne).toHaveBeenCalledWith(
        Campaign,
        expect.objectContaining({ lock: { mode: 'pessimistic_write' } }),
      );
    });

    it('no hay pago con tarjeta si PayPhone no está configurado', async () => {
      payphone.isConfigured.mockReturnValue(false);

      await expect(service.startPurchase('u1', 'c1')).rejects.toThrow('no está disponible');
    });

    it('con la venta apagada no se puede comprar', async () => {
      settings.get.mockResolvedValue(0);

      await expect(service.startPurchase('u1', 'c1')).rejects.toThrow('no está disponible');
      expect(payphone.prepare).not.toHaveBeenCalled();
    });

    it('una campaña sin precio no se compra', async () => {
      manager.findOne.mockImplementation(async (entity: any) =>
        entity === Campaign ? offer({ priceCents: null }) : null,
      );

      await expect(service.startPurchase('u1', 'c1')).rejects.toBeInstanceOf(NotFoundException);
    });

    it('una oferta que ya terminó o está programada no se compra', async () => {
      manager.findOne.mockImplementation(async (entity: any) =>
        entity === Campaign ? offer({ endsAt: new Date(Date.now() - HOUR) }) : null,
      );

      await expect(service.startPurchase('u1', 'c1')).rejects.toThrow('ya no está vigente');
    });

    it('un local desactivado no vende', async () => {
      manager.findOne.mockImplementation(async (entity: any) =>
        entity === Campaign ? offer() : { id: 'b1', isActive: false },
      );

      await expect(service.startPurchase('u1', 'c1')).rejects.toThrow('no está disponible');
    });

    it('quien ya tiene la tarjeta no la compra otra vez', async () => {
      manager.exists.mockResolvedValue(true);

      await expect(service.startPurchase('u1', 'c1')).rejects.toBeInstanceOf(ConflictException);
      expect(payphone.prepare).not.toHaveBeenCalled();
    });

    it('con todos los cupos vendidos o reservados dice que se agotó', async () => {
      rawRows = [{ campaignId: 'c1', n: '3' }];

      await expect(service.startPurchase('u1', 'c1')).rejects.toThrow('Se agotaron');
      expect(payphone.prepare).not.toHaveBeenCalled();
    });

    it('quien volvió sin pagar recupera su propio cupo reservado', async () => {
      rawRows = [{ campaignId: 'c1', n: '3' }];
      manager.find.mockResolvedValue([purchase({ id: 'old' })]);

      await service.startPurchase('u1', 'c1');

      expect(manager.save).toHaveBeenCalledWith(
        expect.objectContaining({ id: 'old', status: CardPurchaseStatus.FAILED }),
      );
      expect(payphone.prepare).toHaveBeenCalled();
    });
  });

  describe('pago por transferencia', () => {
    const open = (extra: any = {}) =>
      purchase({ method: CardPurchaseMethod.TRANSFER, reservedUntil: new Date(Date.now() + 6 * HOUR), ...extra });

    beforeEach(() => {
      // La transferencia encendida (por defecto) y con cuentas.
      settings.get.mockResolvedValue(1);
    });

    describe('startPurchase con transferencia', () => {
      it('reserva el cupo por 12 horas y devuelve las cuentas y la referencia, sin tocar PayPhone', async () => {
        const result: any = await service.startPurchase('u1', 'c1', 'luis@test.com', 'transfer');

        const created = manager.create.mock.calls[0][1];
        expect(created.method).toBe(CardPurchaseMethod.TRANSFER);
        expect(created.status).toBe(CardPurchaseStatus.PENDING);
        const hours = (created.reservedUntil.getTime() - Date.now()) / HOUR;
        expect(hours).toBeGreaterThan(11.9);
        expect(hours).toBeLessThan(12.1);
        expect(payphone.prepare).not.toHaveBeenCalled();
        expect(result).toMatchObject({ method: 'transfer', amountCents: 25 });
        expect(result.reference).toMatch(/^TJ-/);
        expect(result.bankAccounts).toEqual([expect.objectContaining({ accountNumber: '2200112233' })]);
      });

      it('funciona aunque PayPhone no esté configurado', async () => {
        payphone.isConfigured.mockReturnValue(false);

        await expect(service.startPurchase('u1', 'c1', null, 'transfer')).resolves.toMatchObject({ method: 'transfer' });
      });

      it('sin cuentas bancarias o con la transferencia apagada, no se puede', async () => {
        payments.publicBankAccounts.mockResolvedValue([]);
        await expect(service.startPurchase('u1', 'c1', null, 'transfer')).rejects.toThrow(/transferencia no está disponible/);

        payments.publicBankAccounts.mockResolvedValue([{ accountNumber: '1' }]);
        settings.get.mockImplementation(async (key: string) => (key === SETTING_KEYS.paidCardsTransferEnabled ? 0 : 1));
        await expect(service.startPurchase('u1', 'c1', null, 'transfer')).rejects.toThrow(/transferencia no está disponible/);
      });

      it('con un comprobante ya en revisión no se empieza otra compra de la misma tarjeta', async () => {
        manager.exists.mockImplementation(async (entity: any, opts: any) => opts?.where?.status === CardPurchaseStatus.IN_REVIEW);

        await expect(service.startPurchase('u1', 'c1', null, 'transfer')).rejects.toThrow(ConflictException);
      });

      it('empezar otra vez reemplaza la compra pendiente anterior', async () => {
        const old = open({ id: 'old' });
        manager.find.mockResolvedValue([old]);

        await service.startPurchase('u1', 'c1', null, 'transfer');

        expect(old.status).toBe(CardPurchaseStatus.FAILED);
      });
    });

    describe('getRedirect', () => {
      it('una compra por transferencia no tiene página de PayPhone', async () => {
        purchaseRepo.findOne.mockResolvedValue(open());

        expect(await service.getRedirect('TJ-ABC234-X7K2')).toBeNull();
      });
    });

    describe('submitProof (el cliente sube el comprobante)', () => {
      const proof = { proofUrl: 'data:image/png;base64,AAAA', note: '  Transferencia 123456  ' };

      it('pasa la compra a "en revisión", guarda el comprobante y avisa a los administradores', async () => {
        purchaseRepo.findOne.mockResolvedValue(open());

        const result = await service.submitProof('u1', 'p1', proof);

        expect(purchaseRepo.update).toHaveBeenCalledWith(
          { id: 'p1', status: CardPurchaseStatus.PENDING },
          expect.objectContaining({
            status: CardPurchaseStatus.IN_REVIEW,
            proofUrl: proof.proofUrl,
            transferNote: 'Transferencia 123456',
            reportedAt: expect.any(Date),
          }),
        );
        expect(result).toEqual({ id: 'p1', status: CardPurchaseStatus.IN_REVIEW, reference: 'TJ-ABC234' });
        expect(notifications.broadcastToAdmins).toHaveBeenCalledWith(
          'Comprobante de tarjeta por revisar',
          expect.stringContaining('TJ-ABC234'),
          '/admin_card_reviews',
        );
      });

      it('solo el comprador puede subirlo, y solo de una compra por transferencia', async () => {
        purchaseRepo.findOne.mockResolvedValue(open({ userId: 'otro' }));
        await expect(service.submitProof('u1', 'p1', proof)).rejects.toThrow(NotFoundException);

        purchaseRepo.findOne.mockResolvedValue(purchase()); // PayPhone
        await expect(service.submitProof('u1', 'p1', proof)).rejects.toThrow(NotFoundException);

        purchaseRepo.findOne.mockResolvedValue(null);
        await expect(service.submitProof('u1', 'p1', proof)).rejects.toThrow(NotFoundException);
      });

      it('con la reserva vencida hay que empezar de nuevo', async () => {
        purchaseRepo.findOne.mockResolvedValue(open({ reservedUntil: new Date(Date.now() - 1000) }));

        await expect(service.submitProof('u1', 'p1', proof)).rejects.toThrow(/reserva .* venció/);
        expect(purchaseRepo.update).not.toHaveBeenCalled();
      });

      it('ya en revisión, pagada o rechazada: no admite otro comprobante', async () => {
        purchaseRepo.findOne.mockResolvedValue(open({ status: CardPurchaseStatus.IN_REVIEW }));
        await expect(service.submitProof('u1', 'p1', proof)).rejects.toThrow(ConflictException);

        purchaseRepo.findOne.mockResolvedValue(open({ status: CardPurchaseStatus.REJECTED }));
        await expect(service.submitProof('u1', 'p1', proof)).rejects.toThrow(/Empieza de nuevo/);

        purchaseRepo.findOne.mockResolvedValue(open({ status: CardPurchaseStatus.PAID }));
        await expect(service.submitProof('u1', 'p1', proof)).rejects.toThrow(BadRequestException);
      });

      it('dos toques seguidos no lo envían dos veces', async () => {
        purchaseRepo.findOne.mockResolvedValue(open());
        purchaseRepo.update.mockResolvedValue({ affected: 0 });

        await expect(service.submitProof('u1', 'p1', proof)).rejects.toThrow(ConflictException);
        expect(notifications.broadcastToAdmins).not.toHaveBeenCalled();
      });

      it('sin foto no se envía', async () => {
        purchaseRepo.findOne.mockResolvedValue(open());

        await expect(service.submitProof('u1', 'p1', { proofUrl: '' })).rejects.toThrow(/comprobante/);
      });

      it('un aviso que falla no deshace el envío', async () => {
        purchaseRepo.findOne.mockResolvedValue(open());
        notifications.broadcastToAdmins.mockRejectedValue(new Error('sin red'));

        await expect(service.submitProof('u1', 'p1', proof)).resolves.toMatchObject({ status: CardPurchaseStatus.IN_REVIEW });
      });
    });

    describe('offersFor con una transferencia en curso', () => {
      beforeEach(() => {
        campaignRepo.find.mockResolvedValue([offer()]);
        rawRows = [{ campaignId: 'c1', n: '3' }]; // agotada para los demás
      });

      it('muestra al cliente su compra en revisión aunque la oferta se haya agotado', async () => {
        purchaseRepo.find.mockResolvedValue([open({ status: CardPurchaseStatus.IN_REVIEW })]);

        const [first] = await service.offersFor('u1');

        expect(first.stockLeft).toBe(0);
        expect(first.purchase).toMatchObject({ id: 'p1', status: 'in_review', reference: 'TJ-ABC234', reservedUntil: null });
      });

      it('esperando el comprobante: trae hasta cuándo se guarda el cupo', async () => {
        rawRows = [];
        const pending = open();
        purchaseRepo.find.mockResolvedValue([pending]);

        const [first] = await service.offersFor('u1');

        expect(first.purchase).toMatchObject({ status: 'pending', reservedUntil: pending.reservedUntil });
      });

      it('una reserva vencida ya no se muestra', async () => {
        rawRows = [];
        purchaseRepo.find.mockResolvedValue([open({ reservedUntil: new Date(Date.now() - 1000) })]);

        const [first] = await service.offersFor('u1');

        expect(first.purchase).toBeNull();
      });

      it('rechazada: trae el motivo para que el cliente lo corrija', async () => {
        rawRows = [];
        purchaseRepo.find.mockResolvedValue([open({ status: CardPurchaseStatus.REJECTED, reviewNote: 'El monto no coincide' })]);

        const [first] = await service.offersFor('u1');

        expect(first.purchase).toMatchObject({ status: 'rejected', reviewNote: 'El monto no coincide' });
      });

      it('con la tarjeta ya entregada no queda ninguna compra en curso (aunque haya un rechazo antiguo)', async () => {
        rawRows = [];
        claimRepo.find.mockResolvedValue([{ id: 'cl1', campaignId: 'c1', code: 'GFT-ABC234', status: 'active', expiresAt: new Date() }]);
        purchaseRepo.find.mockResolvedValue([open({ status: CardPurchaseStatus.REJECTED, reviewNote: 'antiguo' })]);

        const [first] = await service.offersFor('u1');

        expect(first.claim).toMatchObject({ code: 'GFT-ABC234' });
        expect(first.purchase).toBeNull();
      });

      it('la compra en revisión guarda su cupo', async () => {
        await service.offersFor('u1');

        const sold = qb.andWhere.mock.calls.find((c: any[]) => /IN \(:\.\.\.sold\)/.test(c[0]));
        expect(sold[1].sold).toEqual(expect.arrayContaining([CardPurchaseStatus.IN_REVIEW]));
      });
    });

    describe('administrador: revisar comprobantes', () => {
      it('lista los comprobantes por revisar, del más antiguo al más nuevo', async () => {
        purchaseRepo.find.mockResolvedValue([
          open({
            status: CardPurchaseStatus.IN_REVIEW,
            proofUrl: 'data:image/png;base64,AAAA',
            transferNote: 'Transf. 99',
            reportedAt: new Date('2026-10-27T10:00:00Z'),
            user: { fullName: 'Luis Mora', email: 'luis@test.com' },
            business: { name: 'Café Aurora' },
          }),
        ]);

        const list = await service.reviews();

        expect(purchaseRepo.find).toHaveBeenCalledWith(
          expect.objectContaining({
            where: { status: CardPurchaseStatus.IN_REVIEW, method: CardPurchaseMethod.TRANSFER },
            order: { reportedAt: 'ASC' },
          }),
        );
        expect(list).toEqual([
          expect.objectContaining({
            id: 'p1',
            reference: 'TJ-ABC234',
            amountCents: 25,
            title: 'Café pequeño',
            buyer: 'Luis Mora',
            buyerEmail: 'luis@test.com',
            businessName: 'Café Aurora',
            proofUrl: 'data:image/png;base64,AAAA',
            note: 'Transf. 99',
          }),
        ]);
      });

      describe('approve', () => {
        const inReview = () =>
          open({
            status: CardPurchaseStatus.IN_REVIEW,
            user: { fullName: 'Luis Mora' },
          });

        it('entrega la tarjeta con su código y su vencimiento, y avisa a las dos partes', async () => {
          const p = inReview();
          purchaseRepo.findOne.mockResolvedValue(p);

          const result = await service.approve('p1', 'admin-1');

          expect(purchaseRepo.update).toHaveBeenCalledWith(
            expect.objectContaining({ id: 'p1', status: CardPurchaseStatus.IN_REVIEW }),
            expect.objectContaining({ reviewedById: 'admin-1' }),
          );
          expect(p.status).toBe(CardPurchaseStatus.PAID);
          expect(p.claimId).toBe('cl1');
          expect(p.paidAt).toBeInstanceOf(Date);
          expect(claimRepo.save).toHaveBeenCalledTimes(1);
          expect(claimRepo.create.mock.calls[0][0]).toMatchObject({ source: ClaimSource.PURCHASE, userId: 'u1', campaignId: 'c1' });
          expect(notifications.sendToUser).toHaveBeenCalledWith('u1', 'Compra aprobada', expect.any(String), expect.anything());
          expect(notifications.sendToUser).toHaveBeenCalledWith('owner-1', 'Vendiste una tarjeta', expect.any(String), expect.anything());
          expect(result).toMatchObject({ id: 'p1', outcome: 'approved' });
        });

        it('dos administradores a la vez: solo uno la entrega', async () => {
          purchaseRepo.update.mockResolvedValue({ affected: 0 });
          purchaseRepo.exists.mockResolvedValue(true);

          await expect(service.approve('p1', 'admin-2')).rejects.toThrow(/ya fue revisado/);
          expect(claimRepo.save).not.toHaveBeenCalled();
        });

        it('una compra que no existe da 404', async () => {
          purchaseRepo.update.mockResolvedValue({ affected: 0 });
          purchaseRepo.exists.mockResolvedValue(false);

          await expect(service.approve('nada', 'admin-1')).rejects.toThrow(NotFoundException);
        });

        it('si algo falla al entregar, se puede volver a intentar', async () => {
          purchaseRepo.findOne.mockResolvedValue(inReview());
          claimRepo.save.mockRejectedValue(new Error('base caída'));

          await expect(service.approve('p1', 'admin-1')).rejects.toThrow('base caída');

          expect(purchaseRepo.update).toHaveBeenLastCalledWith({ id: 'p1' }, { reviewedAt: null, reviewedById: null });
        });

        it('si el cliente ya tenía la tarjeta, queda por devolver y se avisa', async () => {
          const p = inReview();
          purchaseRepo.findOne.mockResolvedValue(p);
          claimRepo.findOne.mockResolvedValue({ id: 'ya' });

          await service.approve('p1', 'admin-1');

          expect(p.status).toBe(CardPurchaseStatus.REFUND_DUE);
          expect(claimRepo.save).not.toHaveBeenCalled();
          expect(notifications.broadcastToAdmins).toHaveBeenCalled();
        });
      });

      describe('reject', () => {
        it('libera el cupo, guarda el motivo y se lo dice al cliente', async () => {
          purchaseRepo.findOne.mockResolvedValue(open({ status: CardPurchaseStatus.IN_REVIEW }));

          const result = await service.reject('p1', 'admin-1', '  El monto no coincide  ');

          expect(purchaseRepo.update).toHaveBeenCalledWith(
            expect.objectContaining({ id: 'p1', status: CardPurchaseStatus.IN_REVIEW }),
            expect.objectContaining({
              status: CardPurchaseStatus.REJECTED,
              reviewNote: 'El monto no coincide',
              reviewedById: 'admin-1',
            }),
          );
          expect(notifications.sendToUser).toHaveBeenCalledWith(
            'u1',
            'Comprobante no aceptado',
            expect.stringContaining('El monto no coincide'),
            expect.objectContaining({ type: 'card_transfer_rejected' }),
          );
          expect(result).toEqual({ id: 'p1', status: CardPurchaseStatus.REJECTED });
          expect(claimRepo.save).not.toHaveBeenCalled();
        });

        it('pide el motivo', async () => {
          await expect(service.reject('p1', 'admin-1', '   ')).rejects.toThrow(/motivo/);
          expect(purchaseRepo.update).not.toHaveBeenCalled();
        });

        it('si ya se revisó, avisa; si no existe, 404', async () => {
          purchaseRepo.findOne.mockResolvedValue(open({ status: CardPurchaseStatus.IN_REVIEW }));
          purchaseRepo.update.mockResolvedValue({ affected: 0 });
          await expect(service.reject('p1', 'admin-1', 'motivo')).rejects.toThrow(/ya fue revisado/);

          purchaseRepo.findOne.mockResolvedValue(null);
          await expect(service.reject('nada', 'admin-1', 'motivo')).rejects.toThrow(NotFoundException);
        });
      });

      it('cuenta los comprobantes por revisar', async () => {
        purchaseRepo.count.mockResolvedValue(4);

        expect(await service.countReviews()).toBe(4);
      });
    });

    describe('confirm con una compra por transferencia', () => {
      it('no se confirma con PayPhone', async () => {
        purchaseRepo.findOne.mockResolvedValue(open());

        const result = await service.confirm(1, 'TJ-ABC234-X7K2');

        expect(result.outcome).toBe('failed');
        expect(payphone.confirm).not.toHaveBeenCalled();
      });
    });
  });

  describe('getRedirect', () => {
    it('lleva a la página de PayPhone de una compra pendiente', async () => {
      purchaseRepo.findOne.mockResolvedValue(purchase());

      expect(await service.getRedirect('TJ-ABC234-X7K2')).toBe('https://pay.payphonetodoesposible.com/pay/1');
    });

    it('no redirige si la compra no existe, ya se pagó o la dirección no es de PayPhone', async () => {
      purchaseRepo.findOne.mockResolvedValue(null);
      expect(await service.getRedirect('x')).toBeNull();

      purchaseRepo.findOne.mockResolvedValue(purchase({ status: CardPurchaseStatus.PAID }));
      expect(await service.getRedirect('x')).toBeNull();

      purchaseRepo.findOne.mockResolvedValue(purchase());
      payphone.isPayphoneUrl.mockReturnValue(false);
      expect(await service.getRedirect('x')).toBeNull();
    });
  });

  describe('confirm (el cliente vuelve de PayPhone)', () => {
    const approved = (extra: any = {}) => ({
      statusCode: 3,
      clientTransactionId: 'TJ-ABC234-X7K2',
      amount: 25,
      transactionId: 998877,
      authorizationCode: 'AUT123',
      ...extra,
    });

    beforeEach(() => {
      purchaseRepo.findOne.mockResolvedValue(purchase());
      payphone.confirm.mockResolvedValue(approved());
    });

    it('cobro aprobado: entrega la tarjeta con su código y su vencimiento, y avisa a las dos partes', async () => {
      const result = await service.confirm(5, 'TJ-ABC234-X7K2');

      expect(result).toEqual({ outcome: 'approved', reference: 'TJ-ABC234' });
      const claim = claimRepo.create.mock.calls[0][0];
      expect(claim).toMatchObject({
        campaignId: 'c1',
        userId: 'u1',
        status: ClaimStatus.ACTIVE,
        source: ClaimSource.PURCHASE,
      });
      expect(claim.code).toMatch(/^GFT-/);
      // Vale 30 días desde hoy.
      const days = (claim.expiresAt.getTime() - Date.now()) / (24 * HOUR);
      expect(days).toBeGreaterThan(29.9);
      expect(days).toBeLessThan(30.1);

      expect(purchaseRepo.save).toHaveBeenLastCalledWith(
        expect.objectContaining({
          status: CardPurchaseStatus.PAID,
          claimId: 'cl1',
          gatewayTransactionId: '998877',
          gatewayAuthCode: 'AUT123',
        }),
      );
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'u1',
        'Compra aprobada',
        expect.stringContaining('Mis regalos'),
        expect.objectContaining({ type: 'card_purchased' }),
      );
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'owner-1',
        'Vendiste una tarjeta',
        expect.stringContaining('$0.22'),
        expect.objectContaining({ type: 'card_sold' }),
      );
    });

    it('recargar la página de retorno no entrega otra tarjeta ni vuelve a cobrar', async () => {
      purchaseRepo.findOne.mockResolvedValue(purchase({ status: CardPurchaseStatus.PAID }));

      const result = await service.confirm(5, 'TJ-ABC234-X7K2');

      expect(result.outcome).toBe('approved');
      expect(payphone.confirm).not.toHaveBeenCalled();
      expect(claimRepo.save).not.toHaveBeenCalled();
    });

    it('cobro cancelado: no entrega nada y libera el cupo', async () => {
      payphone.confirm.mockResolvedValue(approved({ statusCode: 2 }));

      const result = await service.confirm(5, 'TJ-ABC234-X7K2');

      expect(result.outcome).toBe('cancelled');
      expect(claimRepo.save).not.toHaveBeenCalled();
      expect(purchaseRepo.save).toHaveBeenCalledWith(expect.objectContaining({ status: CardPurchaseStatus.FAILED }));
    });

    it('un cobro por otro monto no entrega la tarjeta', async () => {
      payphone.confirm.mockResolvedValue(approved({ amount: 1 }));

      const result = await service.confirm(5, 'TJ-ABC234-X7K2');

      expect(result.outcome).toBe('failed');
      expect(claimRepo.save).not.toHaveBeenCalled();
    });

    it('un cobro de otra transacción no entrega la tarjeta', async () => {
      payphone.confirm.mockResolvedValue(approved({ clientTransactionId: 'OTRA-0000' }));

      expect((await service.confirm(5, 'TJ-ABC234-X7K2')).outcome).toBe('failed');
      expect(claimRepo.save).not.toHaveBeenCalled();
    });

    it('una compra que no existe no se confirma', async () => {
      purchaseRepo.findOne.mockResolvedValue(null);

      await expect(service.confirm(5, 'nada')).rejects.toBeInstanceOf(NotFoundException);
    });

    it('si ya tenía la tarjeta (pagó dos veces), la segunda queda por devolver y se avisa al administrador', async () => {
      claimRepo.findOne.mockResolvedValue({ id: 'ya-tiene' });

      const result = await service.confirm(5, 'TJ-ABC234-X7K2');

      expect(result.outcome).toBe('approved');
      expect(claimRepo.save).not.toHaveBeenCalled();
      expect(purchaseRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ status: CardPurchaseStatus.REFUND_DUE }),
      );
      expect(notifications.broadcastToAdmins).toHaveBeenCalled();
    });

    it('un aviso que falla no deshace la compra', async () => {
      notifications.sendToUser.mockRejectedValue(new Error('fcm caido'));

      await expect(service.confirm(5, 'TJ-ABC234-X7K2')).resolves.toMatchObject({ outcome: 'approved' });
    });
  });

  describe('mySales (lo vendido por el local)', () => {
    const sale = (id: string, claimStatus: ClaimStatus | null, extra: any = {}) =>
      purchase({
        id,
        status: CardPurchaseStatus.PAID,
        paidAt: new Date(),
        claim: claimStatus ? { status: claimStatus } : null,
        settledAt: null,
        ...extra,
      });

    it('un dueño sin locales no tiene ventas', async () => {
      businessRepo.find.mockResolvedValue([]);

      expect(await service.mySales({ id: 'o1', role: UserRole.BUSINESS })).toMatchObject({ sold: 0, netCents: 0, recent: [] });
    });

    it('separa lo cobrable (canjeado), lo ya pagado y lo que espera ser canjeado', async () => {
      purchaseRepo.find.mockResolvedValue([
        sale('a', ClaimStatus.REDEEMED),
        sale('b', ClaimStatus.REDEEMED, { settledAt: new Date() }),
        sale('c', ClaimStatus.ACTIVE),
        sale('d', ClaimStatus.ACTIVE, { status: CardPurchaseStatus.REFUND_DUE }),
      ]);

      const result = await service.mySales({ id: 'owner-1', role: UserRole.BUSINESS });

      // Cada una: 25 centavos, 3 de comisión, 22 netos. La por devolver no cuenta.
      expect(result).toMatchObject({
        sold: 3,
        grossCents: 75,
        commissionCents: 9,
        netCents: 66,
        redeemed: 2,
        payableCents: 22,
        paidOutCents: 22,
        pendingCents: 22,
      });
      expect(result.recent).toHaveLength(3);
      expect(result.recent[0]).toMatchObject({ amountCents: 25, netCents: 22, buyer: 'Luis Mora' });
    });

    it('solo mira los locales del dueño', async () => {
      purchaseRepo.find.mockResolvedValue([]);
      await service.mySales({ id: 'owner-1', role: UserRole.BUSINESS });

      expect(businessRepo.find.mock.calls[0][0].where).toEqual({ ownerId: 'owner-1' });
    });

    it('el administrador ve todos los locales', async () => {
      purchaseRepo.find.mockResolvedValue([]);
      await service.mySales({ id: 'admin-1', role: UserRole.ADMIN });

      expect(businessRepo.find.mock.calls[0][0].where).toEqual({});
    });
  });

  describe('pagos a los locales (administrador)', () => {
    it('lista lo que se le debe a cada local por las tarjetas canjeadas, de mayor a menor', async () => {
      rawRows = [
        { businessId: 'b1', cards: '2', netCents: '44' },
        { businessId: 'b2', cards: '5', netCents: '110' },
      ];
      businessRepo.find.mockResolvedValue([
        { id: 'b1', name: 'Café Aurora', owner: { fullName: 'Ana', email: 'ana@x.com' } },
        { id: 'b2', name: 'Pizzería Sol', owner: { fullName: 'Beto', email: 'beto@x.com' } },
      ]);

      const { payouts, refunds } = await service.payouts();

      expect(payouts.map((p) => p.businessName)).toEqual(['Pizzería Sol', 'Café Aurora']);
      expect(payouts[0]).toMatchObject({ cards: 5, netCents: 110, ownerEmail: 'beto@x.com' });
      expect(refunds).toEqual([]);
    });

    it('sin nada por pagar no consulta locales', async () => {
      const { payouts } = await service.payouts();

      expect(payouts).toEqual([]);
      expect(businessRepo.find).not.toHaveBeenCalled();
    });

    it('lista las compras por devolver', async () => {
      purchaseRepo.find.mockResolvedValue([
        purchase({ status: CardPurchaseStatus.REFUND_DUE, paidAt: new Date(), user: { fullName: 'Luis', email: 'l@x.com' }, business: { name: 'Café Aurora' } }),
      ]);

      const { refunds } = await service.payouts();

      expect(refunds[0]).toMatchObject({ reference: 'TJ-ABC234', amountCents: 25, buyer: 'Luis', businessName: 'Café Aurora' });
    });

    it('registrar el pago marca las ventas, anota la referencia y avisa al dueño', async () => {
      const due = [purchase({ status: CardPurchaseStatus.PAID }), purchase({ id: 'p2', status: CardPurchaseStatus.PAID })];
      qb.getMany.mockResolvedValue(due);

      const result = await service.settle('b1', 'admin-1', ' Transferencia 123 ');

      expect(result).toEqual({ settled: 2, amountCents: 44 });
      expect(due.every((p: any) => p.settledAt instanceof Date && p.settledById === 'admin-1')).toBe(true);
      expect(due[0].settlementNote).toBe('Transferencia 123');
      expect(manager.save).toHaveBeenCalledWith(due);
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'owner-1',
        expect.stringContaining('pagamos'),
        expect.stringContaining('$0.44'),
        expect.anything(),
      );
    });

    it('no se paga dos veces: sin tarjetas canjeadas por pagar, avisa', async () => {
      qb.getMany.mockResolvedValue([]);

      await expect(service.settle('b1', 'admin-1')).rejects.toBeInstanceOf(BadRequestException);
      expect(manager.save).not.toHaveBeenCalled();
    });

    it('solo se cuentan las canjeadas y aún sin pagar', async () => {
      qb.getMany.mockResolvedValue([purchase()]);
      await service.settle('b1', 'admin-1');

      const filters = qb.andWhere.mock.calls.map((c: any[]) => c[0]).join(' ');
      expect(filters).toContain('settled_at IS NULL');
      expect(filters).toContain('c.status = :redeemed');
    });

    it('marcar una devolución como hecha', async () => {
      const row = purchase({ status: CardPurchaseStatus.REFUND_DUE });
      purchaseRepo.findOne.mockResolvedValue(row);

      await service.markRefunded('p1', 'admin-1', 'Reversado en PayPhone');

      expect(row.status).toBe(CardPurchaseStatus.FAILED);
      expect(row.settlementNote).toBe('Devuelta: Reversado en PayPhone');
    });

    it('no se puede "devolver" una compra que no está por devolver', async () => {
      purchaseRepo.findOne.mockResolvedValue(purchase({ status: CardPurchaseStatus.PAID }));

      await expect(service.markRefunded('p1', 'admin-1')).rejects.toBeInstanceOf(BadRequestException);
      purchaseRepo.findOne.mockResolvedValue(null);
      await expect(service.markRefunded('p1', 'admin-1')).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
