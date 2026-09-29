import { Profile } from './profile.entity';
import { Business } from './business.entity';
import { LoyaltyCard } from './loyalty-card.entity';
export declare enum RewardStatus {
    PENDING = "pending",
    APPROVED = "approved",
    CLAIMED = "claimed",
    REJECTED = "rejected"
}
export declare class Reward {
    id: string;
    userId: string;
    user: Profile;
    businessId: string;
    business: Business;
    loyaltyCardId: string;
    loyaltyCard: LoyaltyCard;
    rewardDescription: string;
    description: string;
    pointsUsed: number;
    status: RewardStatus;
    isDemo: boolean;
    earnedAt: Date;
    claimedAt: Date;
    createdAt: Date;
}
