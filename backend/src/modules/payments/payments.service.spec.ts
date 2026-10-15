import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import {
  Payment,
  PaymentConcept,
  PaymentMethod,
  PaymentStatus,
} from '../../database/entities/payment.entity';
import { NotificationsService } from '../notifications/notifications.service';

describe('PaymentsService', () => {
  let service: PaymentsService;
  let paymentRepo: any;
  let manager: any;
  let notifications: any;

  const payment = (overrides: Partial<Payment> = {}): any => ({
    id: 'p1',
    businessId: 'b1',
    ownerId: 'owner-1',
    status: PaymentStatus.PENDING,
    reference: 'FID-ABC234',
    receiptNumber: null,
    business: { id: 'b1', name: 'Cafe Aurora' },
    ...overrides,
  });

  beforeEach(async () => {
    manager = {
      save: jest.fn((_entity, p) => Promise.resolve(p)),
      update: jest.fn().mockResolvedValue(undefined),
    };
    paymentRepo = {
      create: jest.fn((data) => data),
      save: jest.fn((p) => Promise.resolve(p)),
      find: jest.fn(),
      findOne: jest.fn(),
      count: jest.fn(),
      manager: { transaction: jest.fn((cb) => cb(manager)), findOne: jest.fn() },
    };
    notifications = {
      broadcastToAdmins: jest.fn().mockResolvedValue(undefined),
      sendToBusinessOwner: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentsService,
        { provide: getRepositoryToken(Payment), useValue: paymentRepo },
        {
          provide: ConfigService,
          useValue: {
            get: (key: string) =>
              ({
                'payments.registrationFee': 25,
                'payments.branchFee': 12,
                'payments.currency': 'USD',
                'payments.bankAccounts': [
                  {
                    name: 'Banco de Loja',
                    accountNumber: '2900000001',
                    accountType: 'Cuenta de ahorros',
                    holder: 'Titular Uno',
                    taxId: '1100000001',
                  },
                  {
                    name: 'Banco Pichincha',
                    accountNumber: '2200000002',
                    accountType: '',
                    holder: 'Titular Dos',
                    taxId: '1100000002',
                  },
                ],
                'payments.cardPaymentUrl': 'https://pay.example.com/c?ref={reference}&amount={amount}',
              })[key],
          },
        },
        { provide: NotificationsService, useValue: notifications },
      ],
    }).compile();

    service = module.get(PaymentsService);
  });

  describe('getPlan', () => {
    it('incluye todas las cuentas bancarias y el enlace de la pasarela', () => {
      const plan = service.getPlan();

      expect(plan.bankAccounts).toHaveLength(2);
      expect(plan.bankAccounts[0]).toEqual({
        bank: 'Banco de Loja',
        accountNumber: '2900000001',
        accountType: 'Cuenta de ahorros',
        holder: 'Titular Uno',
        taxId: '1100000001',
      });
      // Un dato vacío se informa como nulo.
      expect(plan.bankAccounts[1].accountType).toBeNull();
      expect(plan.cardPaymentUrl).toContain('{reference}');
    });
  });

  describe('createOrder', () => {
    it('crea una orden pendiente con el precio del registro y una referencia', async () => {
      const order = await service.createOrder({ id: 'b1', ownerId: 'owner-1' });

      expect(order.status).toBe(PaymentStatus.PENDING);
      expect(order.amount).toBe(25);
      expect(order.concept).toBe(PaymentConcept.REGISTRATION);
      expect(order.reference).toMatch(/^FID-[2-9A-HJ-NP-Z]{6}$/);
    });

    it('una sucursal usa el precio de sucursal', async () => {
      const order = await service.createOrder(
        { id: 'b2', ownerId: 'owner-1' },
        PaymentConcept.BRANCH,
      );

      expect(order.amount).toBe(12);
    });
  });

  describe('listAll y getOne (administrador)', () => {
    const full = (): any =>
      payment(<any>{
        proofUrl: 'data:image/png;base64,AAAA',
        business: { id: 'b1', name: 'Cafe Aurora', logoUrl: 'data:image/png;base64,BBBB', categoryRef: { name: 'Cafeterias' } },
        owner: { id: 'owner-1', email: 'ana@mail.com', avatarUrl: 'data:image/png;base64,CCCC' },
      });

    it('el listado no envia las imagenes pero indica si hay comprobante', async () => {
      paymentRepo.find.mockResolvedValue([full(), payment()]);

      const [withProof, withoutProof] = await service.listAll();

      expect(withProof.hasProof).toBe(true);
      expect(withProof.proofUrl).toBeUndefined();
      expect(withProof.business.logoUrl).toBeUndefined();
      expect(withProof.owner.avatarUrl).toBeUndefined();
      // Los datos que si se muestran siguen ahi.
      expect(withProof.business.name).toBe('Cafe Aurora');
      expect(withProof.business.categoryRef.name).toBe('Cafeterias');
      expect(withProof.owner.email).toBe('ana@mail.com');
      expect(withoutProof.hasProof).toBe(false);
      expect(paymentRepo.find.mock.calls[0][0].relations).toContain('business.categoryRef');
    });

    it('el detalle incluye comprobante, logo y foto del dueño', async () => {
      paymentRepo.findOne.mockResolvedValue(full());

      const detail = await service.getOne('p1');

      expect(detail.proofUrl).toBe('data:image/png;base64,AAAA');
      expect(detail.hasProof).toBe(true);
      expect(detail.business.logoUrl).toBe('data:image/png;base64,BBBB');
      expect(detail.owner.avatarUrl).toBe('data:image/png;base64,CCCC');
    });

    it('falla si el pago no existe', async () => {
      paymentRepo.findOne.mockResolvedValue(null);

      await expect(service.getOne('p1')).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('ensureOrder', () => {
    const inactive = { id: 'b1', ownerId: 'owner-1', isActive: false };

    it('devuelve la orden vigente sin crear otra', async () => {
      paymentRepo.manager.findOne.mockResolvedValue(inactive);
      paymentRepo.findOne.mockResolvedValue(payment());

      const order = await service.ensureOrder('b1', 'owner-1');

      expect(order.id).toBe('p1');
      expect(paymentRepo.create).not.toHaveBeenCalled();
    });

    it('crea la orden de un negocio antiguo que no tenia', async () => {
      paymentRepo.manager.findOne.mockResolvedValue(inactive);
      paymentRepo.findOne.mockResolvedValue(null);

      const order = await service.ensureOrder('b1', 'owner-1');

      expect(order.status).toBe(PaymentStatus.PENDING);
      expect(order.businessId).toBe('b1');
    });

    it('no sirve para negocios de otro dueño', async () => {
      paymentRepo.manager.findOne.mockResolvedValue({ ...inactive, ownerId: 'otro' });

      await expect(service.ensureOrder('b1', 'owner-1')).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('no crea orden para un negocio ya activo', async () => {
      paymentRepo.manager.findOne.mockResolvedValue({ ...inactive, isActive: true });

      await expect(service.ensureOrder('b1', 'owner-1')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });
  });

  describe('report', () => {
    const dto = {
      method: PaymentMethod.TRANSFER,
      note: ' Transf. 8842 ',
      proofUrl: 'data:image/png;base64,iVBORw0KGgo=',
    };

    it('pasa a reportado y avisa a los administradores', async () => {
      paymentRepo.findOne.mockResolvedValue(payment());

      const result = await service.report('p1', 'owner-1', dto);

      expect(result.status).toBe(PaymentStatus.REPORTED);
      expect(result.note).toBe('Transf. 8842');
      expect(result.reportedAt).toBeInstanceOf(Date);
      expect(notifications.broadcastToAdmins).toHaveBeenCalled();
    });

    it('una transferencia o un deposito exigen la foto del comprobante', async () => {
      paymentRepo.findOne.mockResolvedValue(payment());

      await expect(
        service.report('p1', 'owner-1', { method: PaymentMethod.TRANSFER, note: '8842' }),
      ).rejects.toThrow('foto del comprobante');
      await expect(
        service.report('p1', 'owner-1', { method: PaymentMethod.DEPOSIT }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(paymentRepo.save).not.toHaveBeenCalled();
    });

    it('el pago con tarjeta se reporta sin comprobante', async () => {
      paymentRepo.findOne.mockResolvedValue(payment());

      const result = await service.report('p1', 'owner-1', {
        method: PaymentMethod.CARD,
        note: 'Operacion 5521',
      });

      expect(result.status).toBe(PaymentStatus.REPORTED);
      expect(result.method).toBe(PaymentMethod.CARD);
      expect(result.proofUrl).toBeNull();
    });

    it('un pago rechazado se puede reportar de nuevo y limpia el motivo', async () => {
      paymentRepo.findOne.mockResolvedValue(
        payment({ status: PaymentStatus.REJECTED, adminNote: 'No vemos el deposito' }),
      );

      const result = await service.report('p1', 'owner-1', dto);

      expect(result.status).toBe(PaymentStatus.REPORTED);
      expect(result.adminNote).toBeNull();
    });

    it('no permite reportar el pago de otro dueño', async () => {
      paymentRepo.findOne.mockResolvedValue(payment({ ownerId: 'otro' }));

      await expect(service.report('p1', 'owner-1', dto)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it.each([PaymentStatus.PAID, PaymentStatus.REPORTED])(
      'no permite reportar un pago en estado %s',
      async (status) => {
        paymentRepo.findOne.mockResolvedValue(payment({ status }));

        await expect(service.report('p1', 'owner-1', dto)).rejects.toBeInstanceOf(
          BadRequestException,
        );
      },
    );

    it('falla si el pago no existe', async () => {
      paymentRepo.findOne.mockResolvedValue(null);

      await expect(service.report('p1', 'owner-1', dto)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('si falla la notificacion igual queda reportado', async () => {
      paymentRepo.findOne.mockResolvedValue(payment());
      notifications.broadcastToAdmins.mockRejectedValue(new Error('fcm caido'));

      const result = await service.report('p1', 'owner-1', dto);

      expect(result.status).toBe(PaymentStatus.REPORTED);
    });
  });

  describe('validate', () => {
    it('marca el pago como pagado, emite comprobante y activa el negocio', async () => {
      paymentRepo.findOne.mockResolvedValue(payment({ status: PaymentStatus.REPORTED }));

      const result = await service.validate('p1', 'admin-1');

      expect(result.status).toBe(PaymentStatus.PAID);
      expect(result.validatedById).toBe('admin-1');
      expect(result.receiptNumber).toMatch(/^FID-R-\d{8}-[2-9A-HJ-NP-Z]{6}$/);
      expect(manager.update).toHaveBeenCalledWith(expect.anything(), { id: 'b1' }, { isActive: true });
      expect(notifications.sendToBusinessOwner).toHaveBeenCalledWith(
        'b1',
        expect.any(String),
        expect.stringContaining(result.receiptNumber),
        expect.anything(),
      );
    });

    it('se puede validar una orden que el dueño aun no reporto', async () => {
      paymentRepo.findOne.mockResolvedValue(payment({ status: PaymentStatus.PENDING }));

      const result = await service.validate('p1', 'admin-1');

      expect(result.status).toBe(PaymentStatus.PAID);
    });

    it('no valida dos veces el mismo pago', async () => {
      paymentRepo.findOne.mockResolvedValue(payment({ status: PaymentStatus.PAID }));

      await expect(service.validate('p1', 'admin-1')).rejects.toBeInstanceOf(BadRequestException);
      expect(manager.update).not.toHaveBeenCalled();
    });

    it('si la transaccion falla no se notifica', async () => {
      paymentRepo.findOne.mockResolvedValue(payment());
      paymentRepo.manager.transaction.mockRejectedValue(new Error('db caida'));

      await expect(service.validate('p1', 'admin-1')).rejects.toThrow('db caida');
      expect(notifications.sendToBusinessOwner).not.toHaveBeenCalled();
    });
  });

  describe('reject', () => {
    it('guarda el motivo y avisa al dueño', async () => {
      paymentRepo.findOne.mockResolvedValue(payment({ status: PaymentStatus.REPORTED }));

      const result = await service.reject('p1', '  No vemos el deposito ');

      expect(result.status).toBe(PaymentStatus.REJECTED);
      expect(result.adminNote).toBe('No vemos el deposito');
      expect(notifications.sendToBusinessOwner).toHaveBeenCalled();
    });

    it('no rechaza un pago ya validado', async () => {
      paymentRepo.findOne.mockResolvedValue(payment({ status: PaymentStatus.PAID }));

      await expect(service.reject('p1', 'x')).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('settleOpenForBusiness', () => {
    it('cierra las ordenes abiertas con comprobante', async () => {
      const open = [payment(), payment({ id: 'p2', status: PaymentStatus.REPORTED })];
      paymentRepo.find.mockResolvedValue(open);

      const settled = await service.settleOpenForBusiness('b1', 'admin-1');

      expect(settled).toBe(2);
      expect(open.every((p) => p.status === PaymentStatus.PAID && p.receiptNumber)).toBe(true);
      expect(paymentRepo.save).toHaveBeenCalledWith(open);
    });

    it('no guarda nada si no hay ordenes abiertas', async () => {
      paymentRepo.find.mockResolvedValue([]);

      expect(await service.settleOpenForBusiness('b1', 'admin-1')).toBe(0);
      expect(paymentRepo.save).not.toHaveBeenCalled();
    });
  });
});
