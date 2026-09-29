import { LoyaltyCardsService } from './loyalty-cards.service';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
export declare class LoyaltyCardsController {
    private readonly cardsService;
    constructor(cardsService: LoyaltyCardsService);
    getMyCards(user: AuthenticatedUser): Promise<import("../../database/entities").LoyaltyCard[]>;
    getOrCreateCard(user: AuthenticatedUser, businessId: string): Promise<import("../../database/entities").LoyaltyCard>;
    getBusinessCards(user: AuthenticatedUser, businessId: string): Promise<import("../../database/entities").LoyaltyCard[]>;
    getCardHistory(user: AuthenticatedUser, cardId: string): Promise<{
        card: import("../../database/entities").LoyaltyCard;
        scans: import("../../database/entities").Scan[];
        rewards: import("../../database/entities").Reward[];
        transfers: import("../../database/entities").RewardTransferHistory[];
    }>;
}
