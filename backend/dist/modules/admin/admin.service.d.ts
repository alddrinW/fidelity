import { Repository } from 'typeorm';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { Business } from '../../database/entities/business.entity';
import { Scan } from '../../database/entities/scan.entity';
import { Reward } from '../../database/entities/reward.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { RewardTransferHistory } from '../../database/entities/reward-transfer-history.entity';
export declare class AdminService {
    private readonly profileRepository;
    private readonly businessRepository;
    private readonly scanRepository;
    private readonly rewardRepository;
    private readonly cardRepository;
    private readonly transferRepository;
    private readonly logger;
    constructor(profileRepository: Repository<Profile>, businessRepository: Repository<Business>, scanRepository: Repository<Scan>, rewardRepository: Repository<Reward>, cardRepository: Repository<LoyaltyCard>, transferRepository: Repository<RewardTransferHistory>);
    getDashboardStats(): Promise<{
        users: {
            total: number;
            clients: number;
            businessOwners: number;
            admins: number;
        };
        businesses: {
            total: number;
            active: number;
            inactive: number;
        };
        scans: {
            total: number;
            approved: number;
            pending: number;
        };
        rewards: {
            total: number;
            pending: number;
            claimed: number;
        };
        transfers: {
            total: number;
        };
    }>;
    getUsers(role?: UserRole, search?: string): Promise<Profile[]>;
    getRecentActivity(limit?: number, businessId?: string, startDate?: string, endDate?: string): Promise<Scan[]>;
    getQrStats(startDate?: string, endDate?: string): Promise<Scan[]>;
    getAllRewards(businessId?: string, startDate?: string, endDate?: string): Promise<Reward[]>;
    updateUserRole(userId: string, newRole: UserRole): Promise<Profile>;
}
