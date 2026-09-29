import { Repository } from 'typeorm';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Business } from '../../database/entities/business.entity';
import { Scan } from '../../database/entities/scan.entity';
import { Reward } from '../../database/entities/reward.entity';
import { RewardTransferHistory } from '../../database/entities/reward-transfer-history.entity';
import { UserRole } from '../../database/entities/profile.entity';
export declare class LoyaltyCardsService {
    private readonly cardRepository;
    private readonly businessRepository;
    private readonly scanRepository;
    private readonly rewardRepository;
    private readonly transferRepository;
    private readonly logger;
    constructor(cardRepository: Repository<LoyaltyCard>, businessRepository: Repository<Business>, scanRepository: Repository<Scan>, rewardRepository: Repository<Reward>, transferRepository: Repository<RewardTransferHistory>);
    getOrCreateLoyaltyCard(userId: string, businessId: string): Promise<LoyaltyCard>;
    getUserCards(userId: string): Promise<LoyaltyCard[]>;
    getBusinessCards(businessId: string, ownerId: string, role: UserRole): Promise<LoyaltyCard[]>;
    getCardHistory(cardId: string, userId: string, role: UserRole): Promise<{
        card: LoyaltyCard;
        scans: Scan[];
        rewards: Reward[];
        transfers: RewardTransferHistory[];
    }>;
}
