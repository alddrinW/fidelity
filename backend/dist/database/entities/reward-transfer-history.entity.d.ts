import { Profile } from './profile.entity';
import { Business } from './business.entity';
import { Reward } from './reward.entity';
export declare class RewardTransferHistory {
    id: string;
    rewardId: string;
    reward: Reward;
    businessId: string;
    business: Business;
    fromUserId: string;
    fromUser: Profile;
    toUserId: string;
    toUser: Profile;
    transferredAt: Date;
}
