import { Repository } from 'typeorm';
import { Business } from '../../database/entities/business.entity';
import { BusinessCategory } from '../../database/entities/business-category.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Scan } from '../../database/entities/scan.entity';
import { Reward } from '../../database/entities/reward.entity';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { CreateBusinessDto, UpdateBusinessDto, CreateCategoryDto } from './dto/businesses.dto';
import { NotificationsService } from '../notifications/notifications.service';
export declare class BusinessesService {
    private readonly businessRepository;
    private readonly categoryRepository;
    private readonly cardRepository;
    private readonly scanRepository;
    private readonly rewardRepository;
    private readonly profileRepository;
    private readonly notificationsService;
    private readonly logger;
    constructor(businessRepository: Repository<Business>, categoryRepository: Repository<BusinessCategory>, cardRepository: Repository<LoyaltyCard>, scanRepository: Repository<Scan>, rewardRepository: Repository<Reward>, profileRepository: Repository<Profile>, notificationsService: NotificationsService);
    getCategories(): Promise<BusinessCategory[]>;
    createCategory(dto: CreateCategoryDto): Promise<BusinessCategory>;
    deleteCategory(id: number): Promise<{
        success: boolean;
        message: string;
    }>;
    createBusiness(ownerId: string, dto: CreateBusinessDto): Promise<Business>;
    findAll(activeOnly?: boolean): Promise<Business[]>;
    findById(id: string): Promise<Business>;
    findByOwner(ownerId: string): Promise<Business[]>;
    updateBusiness(id: string, ownerId: string, role: UserRole, dto: UpdateBusinessDto): Promise<Business>;
    toggleStatus(id: string, isActive: boolean, role: UserRole): Promise<Business>;
    getBusinessStats(businessId: string, ownerId: string, role: UserRole): Promise<{
        businessId: string;
        businessName: string;
        totalClients: number;
        totalScans: number;
        pendingScans: number;
        approvedScans: number;
        totalRewardsEarned: number;
        pendingRewards: number;
        claimedRewards: number;
    }>;
}
