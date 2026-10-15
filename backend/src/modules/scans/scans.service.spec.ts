import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  HttpException,
  NotFoundException,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { ScansService } from './scans.service';
import { Scan, ScanStatus } from '../../database/entities/scan.entity';
import { ScanAttempt } from '../../database/entities/scan-attempt.entity';
import { QrCode } from '../../database/entities/qr-code.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Reward, RewardStatus } from '../../database/entities/reward.entity';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { BusinessAccessService } from '../businesses/business-access.service';
import { CampaignsService } from '../campaigns/campaigns.service';

describe('ScansService', () => {
  let service: ScansService;
  let qrRepo: any;
  let attemptRepo: any;
  let scanRepo: any;
  let manager: any;
  let queryRunner: any;
  let notifications: any;
  let realtime: any;
  let access: any;
  let campaigns: any;

  /** Lo que devuelve manager.findOne para cada entidad. Cada test lo ajusta. */
  let db: { card: any; pendingReward: any; profile: any; lockedScan: any };

  const business = {
    id: 'b1',
    name: 'Cafe Central',
    ownerId: 'owner-1',
    isActive: true,
    cooldownHours: 4,
    pointsRequired: 3,
    rewardDescription: 'Cafe gratis',
    category: 'Cafeteria',
  };
  const qr = { id: 'qr-1', businessId: 'b1', business, isActive: true };

  const savedOf = (entity: any) =>
    manager.save.mock.calls.filter((c: any[]) => c[0] === entity).map((c: any[]) => c[1]);

  beforeEach(async () => {
    db = {
      card: { id: 'c1', userId: 'u1', businessId: 'b1', currentPoints: 0, totalPointsLifetime: 0, rewardsClaimed: 0, lastScanAt: null },
      pendingReward: null,
      profile: { id: 'u1', fullName: 'Ana Perez', isDemo: false },
      lockedScan: null,
    };

    manager = {
      findOne: jest.fn((entity: any) => {
        if (entity === LoyaltyCard) return Promise.resolve(db.card);
        if (entity === Reward) return Promise.resolve(db.pendingReward);
        if (entity === Profile) return Promise.resolve(db.profile);
        if (entity === Scan) return Promise.resolve(db.lockedScan);
        return Promise.resolve(null);
      }),
      count: jest.fn().mockResolvedValue(0),
      create: jest.fn((_entity: any, data: any) => ({ ...data })),
      save: jest.fn((_entity: any, data: any) => {
        if (!data.id) data.id = 'generated-id';
        return Promise.resolve(data);
      }),
    };

    queryRunner = {
      isTransactionActive: false,
      manager,
      connect: jest.fn(),
      release: jest.fn(),
      startTransaction: jest.fn(() => {
        queryRunner.isTransactionActive = true;
      }),
      commitTransaction: jest.fn(() => {
        queryRunner.isTransactionActive = false;
      }),
      rollbackTransaction: jest.fn(() => {
        queryRunner.isTransactionActive = false;
      }),
    };

    qrRepo = { findOne: jest.fn().mockResolvedValue(qr) };
    attemptRepo = {
      create: jest.fn((e: any) => e),
      save: jest.fn((e: any) => Promise.resolve(e)),
    };
    scanRepo = { findOne: jest.fn(), update: jest.fn().mockResolvedValue({ affected: 1 }) };
    campaigns = { registerApprovedScan: jest.fn().mockResolvedValue(0) };
    // El dueño y el aprobador asignado pueden operar; cualquier otro no.
    access = {
      canOperate: jest.fn(
        async (userId: string, role: UserRole) =>
          role === UserRole.ADMIN || userId === 'owner-1' || userId === 'approver-1',
      ),
    };
    notifications = {
      sendToUser: jest.fn(),
      sendToBusinessOwner: jest.fn(),
      sendToBusinessStaff: jest.fn(),
      broadcastToAdmins: jest.fn(),
    };
    realtime = { emitToBusiness: jest.fn(), emitToUser: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ScansService,
        { provide: getRepositoryToken(Scan), useValue: scanRepo },
        { provide: getRepositoryToken(ScanAttempt), useValue: attemptRepo },
        { provide: getRepositoryToken(QrCode), useValue: qrRepo },
        { provide: getRepositoryToken(Business), useValue: {} },
        { provide: getRepositoryToken(LoyaltyCard), useValue: {} },
        { provide: getRepositoryToken(Reward), useValue: {} },
        { provide: getRepositoryToken(Profile), useValue: {} },
        { provide: NotificationsService, useValue: notifications },
        { provide: RealtimeGateway, useValue: realtime },
        { provide: BusinessAccessService, useValue: access },
        { provide: CampaignsService, useValue: campaigns },
        { provide: DataSource, useValue: { createQueryRunner: () => queryRunner } },
      ],
    }).compile();

    service = module.get<ScansService>(ScansService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('validateScan (el cliente escanea)', () => {
    it('lanza NotFound y registra el intento si el QR no existe', async () => {
      qrRepo.findOne.mockResolvedValue(null);

      await expect(service.validateScan('u1', { qr_code: 'NO_EXISTE' })).rejects.toThrow(
        NotFoundException,
      );
      expect(attemptRepo.save).toHaveBeenCalled();
      expect(queryRunner.startTransaction).not.toHaveBeenCalled();
    });

    it('registra el escaneo como PENDIENTE y NO suma puntos', async () => {
      const result = await service.validateScan('u1', { qr_code: 'FID-1' });

      expect(result.status).toBe(ScanStatus.PENDING);
      expect(result.rewardCompleted).toBe(false);
      expect(result.currentPoints).toBe(0);
      expect(result.message).toContain('aprue');

      const scans = savedOf(Scan);
      expect(scans).toHaveLength(1);
      expect(scans[0].status).toBe(ScanStatus.PENDING);

      // La tarjeta solo registra el momento del escaneo (inicia la espera).
      expect(db.card.currentPoints).toBe(0);
      expect(db.card.totalPointsLifetime).toBe(0);
      expect(db.card.lastScanAt).toBeInstanceOf(Date);
      expect(savedOf(Reward)).toHaveLength(0);
      expect(queryRunner.commitTransaction).toHaveBeenCalled();
    });

    it('avisa al negocio en tiempo real y por push que hay un escaneo por aprobar', async () => {
      await service.validateScan('u1', { qr_code: 'FID-1' });

      expect(realtime.emitToBusiness).toHaveBeenCalledWith(
        'b1',
        'scan:new',
        expect.objectContaining({ status: ScanStatus.PENDING, clientName: 'Ana Perez' }),
      );
      expect(notifications.sendToBusinessStaff).toHaveBeenCalledWith(
        'b1',
        expect.any(String),
        expect.any(String),
        { route: '/business_dashboard/pending' },
      );
      // Al cliente no se le avisa de "punto aprobado": todavia no lo esta.
      expect(notifications.sendToUser).not.toHaveBeenCalled();
    });

    it('crea la tarjeta si el cliente no tenia una en ese negocio', async () => {
      db.card = null;

      await service.validateScan('u1', { qr_code: 'FID-1' });

      expect(manager.create).toHaveBeenCalledWith(
        LoyaltyCard,
        expect.objectContaining({ userId: 'u1', businessId: 'b1', currentPoints: 0 }),
      );
    });

    it('rechaza con 409 si el cliente tiene un premio pendiente en ese negocio', async () => {
      db.pendingReward = { id: 'r1', status: RewardStatus.PENDING };

      const error: any = await service.validateScan('u1', { qr_code: 'FID-1' }).catch((e) => e);

      expect(error).toBeInstanceOf(ConflictException);
      expect(error.message.toLowerCase()).toContain('premio pendiente');
      expect(attemptRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ success: false, failureReason: 'pending_reward' }),
      );
      expect(savedOf(Scan)).toHaveLength(0);
      expect(queryRunner.rollbackTransaction).toHaveBeenCalledTimes(1);
      expect(queryRunner.commitTransaction).not.toHaveBeenCalled();
    });

    it('rechaza con 409 si ya hay un escaneo pendiente en ese negocio', async () => {
      manager.count.mockResolvedValue(1);

      const error: any = await service.validateScan('u1', { qr_code: 'FID-1' }).catch((e) => e);

      expect(error).toBeInstanceOf(ConflictException);
      expect(error.message.toLowerCase()).toContain('escaneo pendiente');
      expect(attemptRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ failureReason: 'pending_scan' }),
      );
      expect(savedOf(Scan)).toHaveLength(0);
    });

    it('rechaza con 429 e indica el tiempo restante si esta dentro del tiempo de espera', async () => {
      db.card.lastScanAt = new Date(Date.now() - 60 * 60 * 1000); // hace 1 h, espera de 4 h

      const error: any = await service.validateScan('u1', { qr_code: 'FID-1' }).catch((e) => e);

      expect(error).toBeInstanceOf(HttpException);
      expect(error.getStatus()).toBe(429);
      expect(error.message).toContain('Vuelve en 3h');
      expect(attemptRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ failureReason: 'cooldown_active' }),
      );
      expect(savedOf(Scan)).toHaveLength(0);
    });

    it('permite escanear de nuevo cuando ya paso el tiempo de espera', async () => {
      db.card.lastScanAt = new Date(Date.now() - 5 * 60 * 60 * 1000); // hace 5 h

      const result = await service.validateScan('u1', { qr_code: 'FID-1' });

      expect(result.status).toBe(ScanStatus.PENDING);
    });
  });

  describe('updateScanStatus (el negocio aprueba o rechaza)', () => {
    const pendingScan = () => ({
      id: 's1',
      userId: 'u1',
      businessId: 'b1',
      loyaltyCardId: 'c1',
      status: ScanStatus.PENDING,
      isDemo: false,
      business,
      user: { id: 'u1', fullName: 'Ana Perez' },
    });

    beforeEach(() => {
      scanRepo.findOne.mockResolvedValue(pendingScan());
      db.lockedScan = { id: 's1', status: ScanStatus.PENDING };
      db.card.currentPoints = 1;
      db.card.totalPointsLifetime = 1;
    });

    const approve = (callerId = 'owner-1', role = UserRole.BUSINESS) =>
      service.updateScanStatus('s1', callerId, role, { status: ScanStatus.APPROVED });
    const reject = () =>
      service.updateScanStatus('s1', 'owner-1', UserRole.BUSINESS, { status: ScanStatus.REJECTED });

    it('al aprobar suma 1 punto y marca el escaneo como aprobado', async () => {
      const result: any = await approve();

      expect(result.rewardCompleted).toBe(false);
      expect(result.currentPoints).toBe(2);
      expect(db.card.currentPoints).toBe(2);
      expect(db.card.totalPointsLifetime).toBe(2);
      expect(savedOf(Scan)[0].status).toBe(ScanStatus.APPROVED);
      expect(savedOf(Reward)).toHaveLength(0);
      expect(queryRunner.commitTransaction).toHaveBeenCalled();
    });

    it('al aprobar avisa al cliente y actualiza su tarjeta en tiempo real', async () => {
      await approve();

      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'u1',
        'Punto aprobado',
        expect.any(String),
        expect.objectContaining({ route: '/points_approved' }),
      );
      expect(realtime.emitToUser).toHaveBeenCalledWith('u1', 'card:updated', expect.anything());
      expect(realtime.emitToUser).toHaveBeenCalledWith(
        'u1',
        'scan:status',
        expect.objectContaining({ status: ScanStatus.APPROVED }),
      );
    });

    it('si el punto completa la meta crea el premio, reinicia puntos y lo informa', async () => {
      db.card.currentPoints = 2; // meta de 3

      const result: any = await approve();

      expect(result.rewardCompleted).toBe(true);
      expect(db.card.currentPoints).toBe(0);
      expect(db.card.rewardsClaimed).toBe(1);
      const rewards = savedOf(Reward);
      expect(rewards).toHaveLength(1);
      expect(rewards[0]).toEqual(
        expect.objectContaining({ userId: 'u1', businessId: 'b1', status: RewardStatus.PENDING }),
      );
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'u1',
        'Premio alcanzado',
        expect.any(String),
        expect.objectContaining({ route: '/reward' }),
      );
    });

    it('no permite aprobar un escaneo ya procesado', async () => {
      scanRepo.findOne.mockResolvedValue({ ...pendingScan(), status: ScanStatus.APPROVED });

      await expect(approve()).rejects.toThrow(ConflictException);
      expect(queryRunner.startTransaction).not.toHaveBeenCalled();
    });

    it('si otro dispositivo lo aprobo mientras tanto, no suma el punto dos veces', async () => {
      db.lockedScan = { id: 's1', status: ScanStatus.APPROVED }; // ya aprobado al bloquear la fila

      await expect(approve()).rejects.toThrow(ConflictException);
      expect(db.card.currentPoints).toBe(1);
      expect(queryRunner.rollbackTransaction).toHaveBeenCalledTimes(1);
      expect(queryRunner.commitTransaction).not.toHaveBeenCalled();
    });

    it('al aprobar un escaneo se registra el sello de las rutas vigentes', async () => {
      scanRepo.findOne.mockResolvedValue({ ...pendingScan(), qrCodeId: 'qr-1' });
      db.lockedScan = { id: 's1', status: ScanStatus.PENDING, userId: 'u1', businessId: 'b1', qrCodeId: 'qr-1' };

      await approve();

      expect(campaigns.registerApprovedScan).toHaveBeenCalledWith(
        expect.objectContaining({ id: 's1', userId: 'u1', businessId: 'b1', qrCodeId: 'qr-1' }),
      );
    });

    it('si falla el registro del sello la aprobacion igual se completa', async () => {
      campaigns.registerApprovedScan.mockRejectedValue(new Error('db caida'));

      const result = await approve();

      expect(result.status).toBe(ScanStatus.APPROVED);
      expect(db.card.currentPoints).toBe(2);
    });

    it('rechazar un escaneo no suma sellos', async () => {
      await reject();

      expect(campaigns.registerApprovedScan).not.toHaveBeenCalled();
    });

    it('un aprobador asignado al local puede aprobar el escaneo', async () => {
      const result = await approve('approver-1', 'approver' as UserRole);

      expect(result.status).toBe(ScanStatus.APPROVED);
      expect(access.canOperate).toHaveBeenCalledWith('approver-1', 'approver', 'b1');
      expect(db.card.currentPoints).toBe(2);
    });

    it('un aprobador de otro local no puede aprobar', async () => {
      await expect(approve('approver-de-otro', 'approver' as UserRole)).rejects.toThrow(
        ForbiddenException,
      );
      expect(db.card.currentPoints).toBe(1);
    });

    it('no aprueba si el cliente tiene un premio pendiente: hay que entregarlo o rechazar', async () => {
      db.pendingReward = { id: 'r1', status: RewardStatus.PENDING };

      await expect(approve()).rejects.toThrow(BadRequestException);
      expect(db.card.currentPoints).toBe(1);
      expect(queryRunner.rollbackTransaction).toHaveBeenCalledTimes(1);
    });

    it('solo el dueno del negocio o un administrador pueden aprobar', async () => {
      await expect(approve('otro-usuario', UserRole.BUSINESS)).rejects.toThrow(ForbiddenException);
      expect(queryRunner.startTransaction).not.toHaveBeenCalled();

      await expect(approve('admin-1', UserRole.ADMIN)).resolves.toBeDefined();
    });

    it('al rechazar no suma puntos y avisa al cliente', async () => {
      const result: any = await reject();

      expect(result.status).toBe(ScanStatus.REJECTED);
      expect(result.rewardCompleted).toBe(false);
      expect(scanRepo.update).toHaveBeenCalledWith(
        { id: 's1', status: ScanStatus.PENDING },
        { status: ScanStatus.REJECTED },
      );
      expect(manager.save).not.toHaveBeenCalled();
      expect(db.card.currentPoints).toBe(1);
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'u1',
        'Escaneo rechazado',
        expect.any(String),
        expect.anything(),
      );
    });

    it('al rechazar no expone datos privados del cliente en la respuesta', async () => {
      const result: any = await reject();

      expect(result.user).toBeUndefined();
      expect(result.business).toBeUndefined();
    });

    it('si otro dispositivo ya lo proceso, rechazar responde conflicto', async () => {
      scanRepo.update.mockResolvedValue({ affected: 0 });

      await expect(reject()).rejects.toThrow(ConflictException);
      expect(notifications.sendToUser).not.toHaveBeenCalled();
    });

    it('no acepta volver un escaneo a pendiente', async () => {
      await expect(
        service.updateScanStatus('s1', 'owner-1', UserRole.BUSINESS, {
          status: ScanStatus.PENDING,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('lanza NotFound si el escaneo no existe', async () => {
      scanRepo.findOne.mockResolvedValue(null);

      await expect(approve()).rejects.toThrow(NotFoundException);
    });
  });
});
