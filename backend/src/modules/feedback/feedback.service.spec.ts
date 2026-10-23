import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  BadRequestException,
  ForbiddenException,
  HttpException,
  NotFoundException,
} from '@nestjs/common';
import { FeedbackService, MAX_FEEDBACK_PER_DAY } from './feedback.service';
import { Feedback, FeedbackKind, FeedbackStatus } from '../../database/entities/feedback.entity';
import { Business } from '../../database/entities/business.entity';
import { Scan } from '../../database/entities/scan.entity';
import { UserRole } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { BusinessAccessService } from '../businesses/business-access.service';
import { SettingsService } from '../settings/settings.service';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { fakeSettings } from '../settings/settings.testing';

describe('FeedbackService', () => {
  let service: FeedbackService;
  let feedbackRepo: any;
  let scanRepo: any;
  let businessRepo: any;
  let notifications: any;
  let access: any;
  let settings: ReturnType<typeof fakeSettings>;

  const BUSINESS_ID = '11111111-1111-4111-8111-111111111111';

  beforeEach(async () => {
    feedbackRepo = {
      count: jest.fn().mockResolvedValue(0),
      create: jest.fn((data) => data),
      save: jest.fn((f) => Promise.resolve({ id: 'f1', ...f })),
      find: jest.fn().mockResolvedValue([]),
      findOne: jest.fn(),
    };
    scanRepo = { count: jest.fn().mockResolvedValue(1) };
    businessRepo = { findOne: jest.fn().mockResolvedValue({ id: BUSINESS_ID, name: 'Cafe Aurora' }) };
    notifications = {
      sendToBusinessStaff: jest.fn().mockResolvedValue(true),
      broadcastToAdmins: jest.fn().mockResolvedValue(undefined),
      sendToUser: jest.fn().mockResolvedValue(true),
    };
    access = { canOperate: jest.fn().mockResolvedValue(true) };
    settings = fakeSettings();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FeedbackService,
        { provide: getRepositoryToken(Feedback), useValue: feedbackRepo },
        { provide: getRepositoryToken(Scan), useValue: scanRepo },
        { provide: getRepositoryToken(Business), useValue: businessRepo },
        { provide: NotificationsService, useValue: notifications },
        { provide: BusinessAccessService, useValue: access },
        { provide: SettingsService, useValue: settings },
      ],
    }).compile();

    service = module.get(FeedbackService);
  });

  describe('inferKind', () => {
    it('calificacion baja es reclamo', () => {
      expect(FeedbackService.inferKind(1, 'tardaron mucho')).toBe(FeedbackKind.COMPLAINT);
    });
    it('con texto es sugerencia', () => {
      expect(FeedbackService.inferKind(2, 'pongan mas mesas')).toBe(FeedbackKind.SUGGESTION);
    });
    it('solo calificacion buena es felicitacion', () => {
      expect(FeedbackService.inferKind(3, null)).toBe(FeedbackKind.PRAISE);
    });
  });

  describe('create', () => {
    it('guarda un reclamo, avisa al dueño y al admin', async () => {
      const saved = await service.create('u1', {
        businessId: BUSINESS_ID,
        rating: 1,
        tags: ['Demora', ' Demora ', 'Mal trato'],
        message: '  Esperé 40 minutos  ',
      });

      expect(saved.kind).toBe(FeedbackKind.COMPLAINT);
      expect(saved.status).toBe(FeedbackStatus.OPEN);
      expect(saved.message).toBe('Esperé 40 minutos');
      expect(saved.tags).toEqual(['Demora', 'Mal trato']);
      expect(notifications.sendToBusinessStaff).toHaveBeenCalledWith(
        BUSINESS_ID,
        expect.stringContaining('reclamo'),
        expect.stringContaining('Cafe Aurora'),
        expect.anything(),
      );
      expect(notifications.broadcastToAdmins).toHaveBeenCalled();
    });

    it('una felicitacion nace resuelta y solo avisa al dueño', async () => {
      const saved = await service.create('u1', { businessId: BUSINESS_ID, rating: 3, tags: ['Atención rápida'] });

      expect(saved.kind).toBe(FeedbackKind.PRAISE);
      expect(saved.status).toBe(FeedbackStatus.RESOLVED);
      expect(notifications.sendToBusinessStaff).toHaveBeenCalled();
      expect(notifications.broadcastToAdmins).not.toHaveBeenCalled();
    });

    it('no deja opinar de un local donde nunca escaneó', async () => {
      scanRepo.count.mockResolvedValue(0);

      await expect(
        service.create('u1', { businessId: BUSINESS_ID, rating: 3 }),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(feedbackRepo.save).not.toHaveBeenCalled();
    });

    it('falla si el negocio no existe', async () => {
      businessRepo.findOne.mockResolvedValue(null);

      await expect(
        service.create('u1', { businessId: BUSINESS_ID, rating: 3 }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('exige calificacion o comentario', async () => {
      await expect(service.create('u1', { businessId: BUSINESS_ID })).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('un reclamo o sugerencia necesita un comentario de verdad', async () => {
      await expect(
        service.create('u1', { businessId: BUSINESS_ID, rating: 1 }),
      ).rejects.toBeInstanceOf(BadRequestException);
      await expect(
        service.create('u1', { businessId: BUSINESS_ID, kind: FeedbackKind.SUGGESTION, message: 'ok' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('limita las opiniones por cliente y local al dia', async () => {
      feedbackRepo.count.mockResolvedValue(MAX_FEEDBACK_PER_DAY);

      const attempt = service.create('u1', { businessId: BUSINESS_ID, rating: 3 });

      await expect(attempt).rejects.toBeInstanceOf(HttpException);
      await expect(attempt).rejects.toMatchObject({ status: 429 });
    });

    it('el tope diario lo fija el administrador', async () => {
      settings.get.mockImplementation(fakeSettings({ [SETTING_KEYS.maxFeedbackPerDay]: 5 }).get);
      feedbackRepo.count.mockResolvedValue(4);

      await expect(service.create('u1', { businessId: BUSINESS_ID, rating: 3 })).resolves.toBeDefined();

      feedbackRepo.count.mockResolvedValue(5);
      await expect(service.create('u1', { businessId: BUSINESS_ID, rating: 3 })).rejects.toMatchObject({ status: 429 });
    });

    it('si falla la notificacion igual se guarda la opinion', async () => {
      notifications.sendToBusinessStaff.mockRejectedValue(new Error('fcm caido'));

      const saved = await service.create('u1', { businessId: BUSINESS_ID, rating: 3 });

      expect(saved.id).toBe('f1');
    });
  });

  describe('listForBusiness', () => {
    it('el dueño o admin ve las opiniones', async () => {
      await service.listForBusiness(BUSINESS_ID, { id: 'owner', role: UserRole.BUSINESS });

      expect(access.canOperate).toHaveBeenCalledWith('owner', UserRole.BUSINESS, BUSINESS_ID);
      expect(feedbackRepo.find).toHaveBeenCalled();
    });

    it('otro usuario no puede verlas', async () => {
      access.canOperate.mockResolvedValue(false);

      await expect(
        service.listForBusiness(BUSINESS_ID, { id: 'otro', role: UserRole.BUSINESS }),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(feedbackRepo.find).not.toHaveBeenCalled();
    });
  });

  describe('resolve', () => {
    const open = () => ({
      id: 'f1',
      userId: 'u1',
      businessId: BUSINESS_ID,
      status: FeedbackStatus.OPEN,
      reply: null,
      business: { name: 'Cafe Aurora' },
    });

    it('resuelve con respuesta y avisa al cliente', async () => {
      feedbackRepo.findOne.mockResolvedValue(open());

      const saved = await service.resolve('f1', { id: 'admin', role: UserRole.ADMIN }, ' Lo revisamos ');

      expect(saved.status).toBe(FeedbackStatus.RESOLVED);
      expect(saved.reply).toBe('Lo revisamos');
      expect(saved.resolvedById).toBe('admin');
      expect(saved.resolvedAt).toBeInstanceOf(Date);
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'u1',
        expect.stringContaining('Cafe Aurora'),
        'Lo revisamos',
        expect.anything(),
      );
    });

    it('resolver sin respuesta no notifica', async () => {
      feedbackRepo.findOne.mockResolvedValue(open());

      await service.resolve('f1', { id: 'admin', role: UserRole.ADMIN });

      expect(notifications.sendToUser).not.toHaveBeenCalled();
    });

    it('quien no gestiona el negocio no puede resolver', async () => {
      feedbackRepo.findOne.mockResolvedValue(open());
      access.canOperate.mockResolvedValue(false);

      await expect(
        service.resolve('f1', { id: 'otro', role: UserRole.BUSINESS }),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(feedbackRepo.save).not.toHaveBeenCalled();
    });

    it('falla si la opinion no existe', async () => {
      feedbackRepo.findOne.mockResolvedValue(null);

      await expect(
        service.resolve('f1', { id: 'admin', role: UserRole.ADMIN }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
