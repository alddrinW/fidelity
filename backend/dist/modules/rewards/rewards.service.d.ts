import { Repository, DataSource } from 'typeorm';
import { Reward, RewardStatus } from '../../database/entities/reward.entity';
import { RewardTransferHistory } from '../../database/entities/reward-transfer-history.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { UpdateRewardStatusDto, TransferRewardDto } from './dto/rewards.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
export declare class RewardsService {
    private readonly rewardRepository;
    private readonly transferRepository;
    private readonly businessRepository;
    private readonly cardRepository;
    private readonly profileRepository;
    private readonly notificationsService;
    private readonly realtimeGateway;
    private readonly dataSource;
    private readonly logger;
    constructor(rewardRepository: Repository<Reward>, transferRepository: Repository<RewardTransferHistory>, businessRepository: Repository<Business>, cardRepository: Repository<LoyaltyCard>, profileRepository: Repository<Profile>, notificationsService: NotificationsService, realtimeGateway: RealtimeGateway, dataSource: DataSource);
    getUserRewards(userId: string, status?: RewardStatus): Promise<Reward[]>;
    getBusinessRewards(businessId: string, callerId: string, callerRole: UserRole, status?: RewardStatus): Promise<Reward[]>;
    updateRewardStatus(rewardId: string, callerId: string, callerRole: UserRole, dto: UpdateRewardStatusDto): Promise<Reward>;
    transferReward(fromUserId: string, dto: TransferRewardDto): Promise<{
        success: boolean;
        message: string;
    }>;
    getTransferHistory(businessId?: string): Promise<RewardTransferHistory[]>;
}
