import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { RewardsService } from './rewards.service';
import { Reward, RewardStatus } from '../../database/entities/reward.entity';
import { RewardTransferHistory } from '../../database/entities/reward-transfer-history.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Profile } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';

describe('RewardsService', () => {
  let service: RewardsService;
  let rewardRepo: any;
  let profileRepo: any;
  let dataSource: any;

  beforeEach(async () => {
    rewardRepo = {
      findOne: jest.fn(),
      createQueryBuilder: jest.fn(),
      save: jest.fn((e) => Promise.resolve(e)),
    };
    profileRepo = {
      findOne: jest.fn(),
    };
    dataSource = {
      createQueryRunner: jest.fn().mockReturnValue({
        connect: jest.fn(),
        startTransaction: jest.fn(),
        commitTransaction: jest.fn(),
        rollbackTransaction: jest.fn(),
        release: jest.fn(),
        manager: {
          findOne: jest.fn(),
          create: jest.fn((entity, data) => data),
          save: jest.fn((entity, data) => Promise.resolve(data)),
        },
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RewardsService,
        { provide: getRepositoryToken(Reward), useValue: rewardRepo },
        { provide: getRepositoryToken(RewardTransferHistory), useValue: {} },
        { provide: getRepositoryToken(Business), useValue: {} },
        { provide: getRepositoryToken(LoyaltyCard), useValue: {} },
        { provide: getRepositoryToken(Profile), useValue: profileRepo },
        { provide: NotificationsService, useValue: { sendToUser: jest.fn(), sendToBusinessOwner: jest.fn(), broadcastToAdmins: jest.fn() } },
        { provide: RealtimeGateway, useValue: { emitToUser: jest.fn() } },
        { provide: DataSource, useValue: dataSource },
      ],
    }).compile();

    service = module.get<RewardsService>(RewardsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should reject transferring a reward to oneself', async () => {
    await expect(
      service.transferReward('user-1', {
        rewardId: 'reward-1',
        toUserId: 'user-1',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('should throw NotFoundException if recipient does not exist', async () => {
    profileRepo.findOne.mockResolvedValueOnce(null);

    await expect(
      service.transferReward('user-1', {
        rewardId: 'reward-1',
        toUserId: 'user-2',
      }),
    ).rejects.toThrow(NotFoundException);
  });

  it('should throw ForbiddenException if sender is not the owner of the reward', async () => {
    profileRepo.findOne
      .mockResolvedValueOnce({ id: 'user-2', fullName: 'Recipient' })
      .mockResolvedValueOnce({ id: 'user-1', fullName: 'Sender' });

    rewardRepo.findOne.mockResolvedValueOnce({
      id: 'reward-1',
      userId: 'other-user',
      status: RewardStatus.PENDING,
      business: { name: 'Cafe Test' },
    });

    await expect(
      service.transferReward('user-1', {
        rewardId: 'reward-1',
        toUserId: 'user-2',
      }),
    ).rejects.toThrow(ForbiddenException);
  });
});
