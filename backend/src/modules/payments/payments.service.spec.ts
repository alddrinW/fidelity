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
import { PayphoneService } from './payphone.service';
import { Business } from '../../database/entities/business.entity';
import { AppSetting } from '../../database/entities/app-setting.entity';

describe('PaymentsService', () => {
  let service: PaymentsService;
  let paymentRepo: any;
  let manager: any;
  let notifications: any;
  let payphone: any;
  let settingRepo: any;

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
    settingRepo = {
      find: jest.fn().mockResolvedValue([]),
      create: jest.fn((data) => data),
      save: jest.fn((entries) => Promise.resolve(entries)),
    };
    payphone = {
      isConfigured: jest.fn().mockReturnValue(true),
      prepare: jest.fn().mockResolvedValue({
        paymentId: 77,
        payWithCard: 'https://pay.payphone/card/77',
        payWithPayPhone: 'https://pay.payphone/app/77',
      }),
      confirm: jest.fn(),
      launchUrl: jest.fn((id: string) => `https://api.test/pay/${id}`),
      isPayphoneUrl: jest.fn((url: string) => !!url && url.startsWith('https://pay.payphone/')),
    };
    notifications = {
      broadcastToAdmins: jest.fn().mockResolvedValue(undefined),
      sendToBusinessOwner: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentsService,
        { provide: getRepositoryToken(Payment), useValue: paymentRepo },
        { provide: getRepositoryToken(AppSetting), useValue: settingRepo },
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
              })[key],
          },
        },
        { provide: NotificationsService, useValue: notifications },
        { provide: PayphoneService, useValue: payphone },
      ],
    }).compile();

    service = module.get(PaymentsService);
  });

  describe('getPlan', () => {
    it('incluye todas las cuentas bancarias y si hay pago con tarjeta', async () => {
      const plan = await service.getPlan();

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
      expect(plan.cardEnabled).toBe(true);
    });

    it('sin PayPhone configurado no se ofrece la tarjeta', async () => {
      payphone.isConfigured.mockReturnValue(false);

      expect((await service.getPlan()).cardEnabled).toBe(false);
    });

    it('sin precios guardados usa los de la configuración', async () => {
      const plan = await service.getPlan();

      expect(plan.registrationFee).toBe(25);
      expect(plan.branchFee).toBe(12);
    });

    it('los precios que fijó el administrador mandan sobre la configuración', async () => {
      settingRepo.find.mockResolvedValue([
        { key: 'registration_fee', value: '35.5' },
        { key: 'branch_fee', value: 'basura' },
      ]);

      const plan = await service.getPlan();

      expect(plan.registrationFee).toBe(35.5);
      // Un valor guardado que no sirve se ignora.
      expect(plan.branchFee).toBe(12);
    });
  });

  describe('updatePrices', () => {
    it('guarda los precios y devuelve el plan', async () => {
      settingRepo.find.mockResolvedValue([{ key: 'registration_fee', value: '40' }]);

      const plan = await service.updatePrices({ registrationFee: 40, branchFee: 15 });

      expect(settingRepo.save).toHaveBeenCalledWith([
        { key: 'registration_fee', value: '40' },
        { key: 'branch_fee', value: '15' },
      ]);
      expect(plan.registrationFee).toBe(40);
    });

    it('permite cambiar solo uno', async () => {
      await service.updatePrices({ branchFee: 9.99 });

      expect(settingRepo.save).toHaveBeenCalledWith([{ key: 'branch_fee', value: '9.99' }]);
    });

    it('exige al menos un precio', async () => {
      await expect(service.updatePrices({})).rejects.toBeInstanceOf(BadRequestException);
      expect(settingRepo.save).not.toHaveBeenCalled();
    });
  });

  describe('createOrder', () => {
    it('una orden nueva usa el precio que fijó el administrador', async () => {
      settingRepo.find.mockResolvedValue([{ key: 'registration_fee', value: '40' }]);

      const order = await service.createOrder({ id: 'b1', ownerId: 'owner-1' });

      expect(order.amount).toBe(40);
    });

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

  describe('pago con tarjeta (PayPhone)', () => {
    const open = (overrides: any = {}) =>
      payment({ amount: 25, owner: { email: 'ana@mail.com' }, ...overrides });
    const approved = (overrides: any = {}) => ({
      statusCode: 3,
      transactionStatus: 'Approved',
      transactionId: 9001,
      clientTransactionId: 'FID-ABC234-X7K2',
      authorizationCode: 'A1B2C3',
      amount: 2500,
      cardBrand: 'Visa',
      lastDigits: '4242',
      ...overrides,
    });

    describe('startCardPayment', () => {
      it('prepara el cobro en centavos y guarda el identificador del intento', async () => {
        paymentRepo.findOne.mockResolvedValue(open());

        const result = await service.startCardPayment('p1', 'owner-1');

        const args = payphone.prepare.mock.calls[0][0];
        // La app abre la pasarela propia (que redirige a PayPhone), no PayPhone directo.
        expect(result).toEqual({ payUrl: `https://api.test/pay/${args.clientTransactionId}` });
        expect(args.amountCents).toBe(2500);
        expect(args.clientTransactionId).toMatch(/^FID-ABC234-[2-9A-HJ-NP-Z]{4}$/);
        expect(args.clientTransactionId.length).toBeLessThanOrEqual(15);
        expect(args.email).toBe('ana@mail.com');
        expect(paymentRepo.save).toHaveBeenCalledWith(
          expect.objectContaining({
            gatewayClientTxId: args.clientTransactionId,
            gatewayPayUrl: 'https://pay.payphone/card/77',
          }),
        );
      });

      it('falla si PayPhone no está configurado', async () => {
        payphone.isConfigured.mockReturnValue(false);

        await expect(service.startCardPayment('p1', 'owner-1')).rejects.toBeInstanceOf(
          BadRequestException,
        );
        expect(payphone.prepare).not.toHaveBeenCalled();
      });

      it('no sirve para pagos de otro dueño', async () => {
        paymentRepo.findOne.mockResolvedValue(open({ ownerId: 'otro' }));

        await expect(service.startCardPayment('p1', 'owner-1')).rejects.toBeInstanceOf(
          ForbiddenException,
        );
      });

      it('no se puede pagar de nuevo un pago reportado o validado', async () => {
        for (const status of [PaymentStatus.REPORTED, PaymentStatus.PAID]) {
          paymentRepo.findOne.mockResolvedValue(open({ status }));
          await expect(service.startCardPayment('p1', 'owner-1')).rejects.toBeInstanceOf(
            BadRequestException,
          );
        }
        expect(payphone.prepare).not.toHaveBeenCalled();
      });
    });

    describe('getCardRedirect', () => {
      const attempt = (overrides: any = {}) =>
        open({
          gatewayClientTxId: 'FID-ABC234-X7K2',
          gatewayPayUrl: 'https://pay.payphone/card/77',
          ...overrides,
        });

      it('devuelve la página de PayPhone del intento', async () => {
        paymentRepo.findOne.mockResolvedValue(attempt());

        expect(await service.getCardRedirect('FID-ABC234-X7K2')).toBe('https://pay.payphone/card/77');
      });

      it('un intento desconocido no redirige', async () => {
        paymentRepo.findOne.mockResolvedValue(null);

        expect(await service.getCardRedirect('NOPE')).toBeNull();
      });

      it('un pago ya reportado o validado no vuelve a abrir PayPhone', async () => {
        for (const status of [PaymentStatus.REPORTED, PaymentStatus.PAID]) {
          paymentRepo.findOne.mockResolvedValue(attempt({ status }));
          expect(await service.getCardRedirect('FID-ABC234-X7K2')).toBeNull();
        }
      });

      it('una dirección que no es de PayPhone nunca se usa como destino', async () => {
        paymentRepo.findOne.mockResolvedValue(attempt({ gatewayPayUrl: 'https://evil.example.com/x' }));

        expect(await service.getCardRedirect('FID-ABC234-X7K2')).toBeNull();
      });
    });

    describe('confirmCardPayment', () => {
      it('un cobro aprobado valida el pago y activa la cuenta sin administrador', async () => {
        paymentRepo.findOne.mockResolvedValue(open({ gatewayClientTxId: 'FID-ABC234-X7K2' }));
        payphone.confirm.mockResolvedValue(approved());

        const result = await service.confirmCardPayment(9001, 'FID-ABC234-X7K2');

        expect(result).toEqual({ outcome: 'approved', reference: 'FID-ABC234' });
        expect(payphone.confirm).toHaveBeenCalledWith(9001, 'FID-ABC234-X7K2');
        const saved = manager.save.mock.calls[0][1];
        expect(saved.status).toBe(PaymentStatus.PAID);
        expect(saved.validatedById).toBeNull();
        expect(saved.receiptNumber).toMatch(/^FID-R-/);
        expect(saved.method).toBe(PaymentMethod.CARD);
        expect(manager.update).toHaveBeenCalledWith(Business, { id: 'b1' }, { isActive: true });
        expect(notifications.sendToBusinessOwner).toHaveBeenCalled();
        expect(saved.gatewayTransactionId).toBe('9001');
        expect(saved.gatewayAuthCode).toBe('A1B2C3');
        expect(saved.note).toBe('PayPhone · aut. A1B2C3 · trans. 9001 · Visa •••• 4242');
        expect(notifications.broadcastToAdmins).toHaveBeenCalled();
      });

      it('un cobro cancelado no cambia el pago', async () => {
        paymentRepo.findOne.mockResolvedValue(open({ gatewayClientTxId: 'FID-ABC234-X7K2' }));
        payphone.confirm.mockResolvedValue(approved({ statusCode: 2, transactionStatus: 'Canceled' }));

        const result = await service.confirmCardPayment(9001, 'FID-ABC234-X7K2');

        expect(result.outcome).toBe('cancelled');
        expect(manager.save).not.toHaveBeenCalled();
        expect(manager.update).not.toHaveBeenCalled();
      });

      it('un monto distinto al de la orden no se acepta', async () => {
        paymentRepo.findOne.mockResolvedValue(open({ gatewayClientTxId: 'FID-ABC234-X7K2' }));
        payphone.confirm.mockResolvedValue(approved({ amount: 100 }));

        const result = await service.confirmCardPayment(9001, 'FID-ABC234-X7K2');

        expect(result.outcome).toBe('failed');
        expect(manager.save).not.toHaveBeenCalled();
        expect(manager.update).not.toHaveBeenCalled();
      });

      it('un identificador de cliente distinto al enviado no se acepta', async () => {
        paymentRepo.findOne.mockResolvedValue(open({ gatewayClientTxId: 'FID-ABC234-X7K2' }));
        payphone.confirm.mockResolvedValue(approved({ clientTransactionId: 'OTRO' }));

        expect((await service.confirmCardPayment(9001, 'FID-ABC234-X7K2')).outcome).toBe('failed');
        expect(manager.update).not.toHaveBeenCalled();
      });

      it('recargar la página de retorno no vuelve a confirmar', async () => {
        paymentRepo.findOne.mockResolvedValue(
          open({
            gatewayClientTxId: 'FID-ABC234-X7K2',
            gatewayTransactionId: '9001',
            status: PaymentStatus.REPORTED,
          }),
        );

        const result = await service.confirmCardPayment(9001, 'FID-ABC234-X7K2');

        expect(result.outcome).toBe('approved');
        expect(payphone.confirm).not.toHaveBeenCalled();
        expect(manager.update).not.toHaveBeenCalled();
      });

      it('un identificador desconocido no existe', async () => {
        paymentRepo.findOne.mockResolvedValue(null);

        await expect(service.confirmCardPayment(1, 'NOPE')).rejects.toBeInstanceOf(
          NotFoundException,
        );
        expect(payphone.confirm).not.toHaveBeenCalled();
      });
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

    it('el pago con tarjeta no se puede reportar a mano: lo confirma PayPhone', async () => {
      paymentRepo.findOne.mockResolvedValue(payment());

      await expect(
        service.report('p1', 'owner-1', { method: PaymentMethod.CARD, note: 'Operacion 5521' }),
      ).rejects.toThrow('PayPhone');
      expect(paymentRepo.save).not.toHaveBeenCalled();
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
