import { RewardsService } from './rewards.service';
import { UpdateRewardStatusDto, TransferRewardDto } from './dto/rewards.dto';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { RewardStatus } from '../../database/entities/reward.entity';
export declare class RewardsController {
    private readonly rewardsService;
    constructor(rewardsService: RewardsService);
    getMyRewards(user: AuthenticatedUser, status?: RewardStatus): Promise<import("../../database/entities/reward.entity").Reward[]>;
    getBusinessRewards(user: AuthenticatedUser, businessId: string, status?: RewardStatus): Promise<import("../../database/entities/reward.entity").Reward[]>;
    updateRewardStatus(user: AuthenticatedUser, rewardId: string, dto: UpdateRewardStatusDto): Promise<import("../../database/entities/reward.entity").Reward>;
    transferReward(user: AuthenticatedUser, dto: TransferRewardDto): Promise<{
        success: boolean;
        message: string;
    }>;
    getTransfers(businessId?: string): Promise<import("../../database/entities").RewardTransferHistory[]>;
}
