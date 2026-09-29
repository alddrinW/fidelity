import { Profile } from './profile.entity';
import { Business } from './business.entity';
export declare class LoyaltyCard {
    id: string;
    userId: string;
    user: Profile;
    businessId: string;
    business: Business;
    currentPoints: number;
    totalPointsLifetime: number;
    rewardsClaimed: number;
    lastScanAt: Date;
    createdAt: Date;
    updatedAt: Date;
}
