import { BusinessesService } from './businesses.service';
import { CreateBusinessDto, UpdateBusinessDto, CreateCategoryDto, ToggleBusinessStatusDto } from './dto/businesses.dto';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
export declare class BusinessesController {
    private readonly businessesService;
    constructor(businessesService: BusinessesService);
    getCategories(): Promise<import("../../database/entities").BusinessCategory[]>;
    createCategory(dto: CreateCategoryDto): Promise<import("../../database/entities").BusinessCategory>;
    deleteCategory(id: string): Promise<{
        success: boolean;
        message: string;
    }>;
    getBusinesses(all?: string): Promise<import("../../database/entities").Business[]>;
    getMyBusinesses(user: AuthenticatedUser): Promise<import("../../database/entities").Business[]>;
    getBusinessById(id: string): Promise<import("../../database/entities").Business>;
    createBusiness(user: AuthenticatedUser, dto: CreateBusinessDto): Promise<import("../../database/entities").Business>;
    updateBusiness(user: AuthenticatedUser, id: string, dto: UpdateBusinessDto): Promise<import("../../database/entities").Business>;
    toggleStatus(user: AuthenticatedUser, id: string, dto: ToggleBusinessStatusDto): Promise<import("../../database/entities").Business>;
    getStats(user: AuthenticatedUser, id: string): Promise<{
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
