import { fakeSettings } from '../settings/settings.testing';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { FidelyService } from './fidely.service';

describe('FidelyUsuario', () => {
  let scanQuery: any;
  let scanRepo: any;
  let businessRepo: any;
  let profileRepo: any;
  let notifications: any;
  let settings: ReturnType<typeof fakeSettings>;
  let service: FidelyService;
  let rows: any[];

  beforeEach(() => {
    rows = [];
    scanQuery = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      addSelect: jest.fn().mockReturnThis(),
      groupBy: jest.fn().mockReturnThis(),
      getRawMany: jest.fn(async () => rows),
    };
    scanRepo = { createQueryBuilder: jest.fn(() => scanQuery) };
    businessRepo = { findOne: jest.fn().mockResolvedValue({ id: 'b1', name: 'Café Aurora' }) };
    profileRepo = { findOne: jest.fn().mockResolvedValue({ id: 'u1', fullName: 'Ana Pérez', email: 'ana@mail.com' }) };
    notifications = {
      sendToUser: jest.fn().mockResolvedValue(true),
      sendToBusinessOwner: jest.fn().mockResolvedValue(true),
    };
    settings = fakeSettings();
    service = new FidelyService(scanRepo, businessRepo, profileRepo, notifications, settings as any);
  });

  describe('cuántos escaneos cuentan', () => {
    it('solo escaneos aprobados y reales (de un QR), no puntos regalados a mano', async () => {
      await service.countsForUser('u1');

      expect(scanQuery.where).toHaveBeenCalledWith('scan.status = :status', { status: 'approved' });
      expect(scanQuery.andWhere).toHaveBeenCalledWith('scan.qrCodeId IS NOT NULL');
    });

    it('del cliente por local', async () => {
      rows = [{ key: 'b1', count: '3' }, { key: 'b2', count: '1' }];

      const counts = await service.countsForUser('u1');

      expect(scanQuery.andWhere).toHaveBeenCalledWith('scan.userId = :userId', { userId: 'u1' });
      expect(counts.get('b1')).toBe(3);
      expect(counts.get('b2')).toBe(1);
    });

    it('de los clientes de un local', async () => {
      rows = [{ key: 'u1', count: '5' }];

      const counts = await service.countsForBusiness('b1');

      expect(scanQuery.andWhere).toHaveBeenCalledWith('scan.businessId = :businessId', { businessId: 'b1' });
      expect(counts.get('u1')).toBe(5);
    });
  });

  describe('la insignia', () => {
    it('con 3 escaneos (por defecto) ya es FidelyUsuario', () => {
      expect(service.status(2, 3)).toEqual({ verifiedScans: 2, fidelyRequired: 3, isFidely: false });
      expect(service.status(3, 3)).toEqual({ verifiedScans: 3, fidelyRequired: 3, isFidely: true });
      expect(service.status(9, 3).isFidely).toBe(true);
    });

    it('sin escaneos no lo es', () => {
      expect(service.status(undefined, 3)).toEqual({ verifiedScans: 0, fidelyRequired: 3, isFidely: false });
    });

    it('la cantidad la fija el administrador', async () => {
      expect(await service.required()).toBe(3);

      settings.get.mockImplementation(fakeSettings({ [SETTING_KEYS.fidelyScansRequired]: 5 }).get);
      expect(await service.required()).toBe(5);
    });

    it('statusFor junta el conteo del local con lo que exige el administrador', async () => {
      rows = [{ key: 'b1', count: '3' }];

      expect(await service.statusFor('u1', 'b1')).toEqual({ verifiedScans: 3, fidelyRequired: 3, isFidely: true });
      expect(await service.statusFor('u1', 'b9')).toEqual({ verifiedScans: 0, fidelyRequired: 3, isFidely: false });
    });
  });

  describe('al aprobar un escaneo', () => {
    const withScans = (n: number) => {
      rows = [{ key: 'b1', count: String(n) }];
    };

    it('en el escaneo número 3 le avisa al cliente y al dueño', async () => {
      withScans(3);

      expect(await service.onScanApproved('u1', 'b1', 'card-1')).toBe(true);

      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'u1',
        '¡Ya eres FidelyUsuario de Café Aurora!',
        'Por tu fidelidad a Café Aurora tienes la insignia FidelyUsuario. ¡Gracias por volver!',
        { type: 'fidely', route: '/fidely_user', business_id: 'b1', business_name: 'Café Aurora', loyalty_card_id: 'card-1' },
      );
      expect(notifications.sendToBusinessOwner).toHaveBeenCalledWith(
        'b1',
        'Nuevo FidelyUsuario',
        'Ana Pérez ya es FidelyUsuario de Café Aurora: 3 escaneos aprobados.',
        { type: 'fidely', route: '/business_dashboard/customers', business_id: 'b1' },
      );
    });

    it('antes del tercero no avisa', async () => {
      withScans(2);

      expect(await service.onScanApproved('u1', 'b1')).toBe(false);
      expect(notifications.sendToUser).not.toHaveBeenCalled();
    });

    it('después del tercero tampoco repite el aviso: solo ocurre una vez', async () => {
      withScans(4);

      expect(await service.onScanApproved('u1', 'b1')).toBe(false);
      expect(notifications.sendToUser).not.toHaveBeenCalled();
      expect(notifications.sendToBusinessOwner).not.toHaveBeenCalled();
    });

    it('con otra cantidad del administrador, avisa justo en esa', async () => {
      settings.get.mockImplementation(fakeSettings({ [SETTING_KEYS.fidelyScansRequired]: 5 }).get);
      withScans(3);
      expect(await service.onScanApproved('u1', 'b1')).toBe(false);

      withScans(5);
      expect(await service.onScanApproved('u1', 'b1')).toBe(true);
      expect(notifications.sendToBusinessOwner).toHaveBeenCalledWith('b1', 'Nuevo FidelyUsuario', expect.stringContaining('5 escaneos'), expect.any(Object));
    });

    it('sin nombre usa el correo; si el local no existe no hace nada', async () => {
      withScans(3);
      profileRepo.findOne.mockResolvedValue({ id: 'u1', fullName: null, email: 'luis@mail.com' });
      await service.onScanApproved('u1', 'b1');
      expect(notifications.sendToBusinessOwner).toHaveBeenCalledWith('b1', expect.any(String), expect.stringContaining('luis ya es'), expect.any(Object));

      notifications.sendToUser.mockClear();
      businessRepo.findOne.mockResolvedValue(null);
      expect(await service.onScanApproved('u1', 'b1')).toBe(false);
      expect(notifications.sendToUser).not.toHaveBeenCalled();
    });
  });
});
