import { Profile } from './profile.entity';
import { BusinessCategory } from './business-category.entity';
import { LoyaltyCard } from './loyalty-card.entity';
export declare class Business {
    id: string;
    ownerId: string;
    owner: Profile;
    categoryId: number;
    categoryRef: BusinessCategory;
    name: string;
    description: string;
    category: string;
    logoUrl: string;
    rewardDescription: string;
    pointsRequired: number;
    cooldownHours: number;
    isActive: boolean;
    latitude: number;
    longitude: number;
    address: string;
    phone: string;
    loyaltyCards: LoyaltyCard[];
    createdAt: Date;
    updatedAt: Date;
}
