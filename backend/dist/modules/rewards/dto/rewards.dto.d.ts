import { RewardStatus } from '../../../database/entities/reward.entity';
export declare class UpdateRewardStatusDto {
    status: RewardStatus;
}
export declare class TransferRewardDto {
    rewardId: string;
    toUserId?: string;
    toEmail?: string;
}
