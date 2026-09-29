import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { HttpException, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { ScansService } from './scans.service';
import { Scan } from '../../database/entities/scan.entity';
import { ScanAttempt } from '../../database/entities/scan-attempt.entity';
import { QrCode } from '../../database/entities/qr-code.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Reward } from '../../database/entities/reward.entity';
import { Profile } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

describe('ScansService', () => {
  let service: ScansService;
  let qrRepo: any;
  let attemptRepo: any;
  let cardRepo: any;

  beforeEach(async () => {
    qrRepo = {
      findOne: jest.fn(),
    };
    attemptRepo = {
      create: jest.fn((e) => e),
      save: jest.fn((e) => Promise.resolve(e)),
    };
    cardRepo = {
      findOne: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ScansService,
        { provide: getRepositoryToken(Scan), useValue: {} },
        { provide: getRepositoryToken(ScanAttempt), useValue: attemptRepo },
        { provide: getRepositoryToken(QrCode), useValue: qrRepo },
        { provide: getRepositoryToken(Business), useValue: {} },
        { provide: getRepositoryToken(LoyaltyCard), useValue: cardRepo },
        { provide: getRepositoryToken(Reward), useValue: {} },
        { provide: getRepositoryToken(Profile), useValue: {} },
        { provide: NotificationsService, useValue: { sendToUser: jest.fn(), broadcastToAdmins: jest.fn() } },
        { provide: RealtimeGateway, useValue: { emitToBusiness: jest.fn(), emitToUser: jest.fn() } },
        { provide: DataSource, useValue: {} },
      ],
    }).compile();

    service = module.get<ScansService>(ScansService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should throw NotFoundException and log failed attempt if QR code does not exist', async () => {
    qrRepo.findOne.mockResolvedValue(null);

    await expect(
      service.validateScan('user-1', { qr_code: 'NON_EXISTENT_QR' }),
    ).rejects.toThrow(NotFoundException);

    expect(attemptRepo.save).toHaveBeenCalled();
  });
});
