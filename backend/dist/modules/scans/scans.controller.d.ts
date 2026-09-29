import { ScansService } from './scans.service';
import { ValidateScanDto, AddManualPointsDto, UpdateScanStatusDto } from './dto/scans.dto';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { ScanStatus } from '../../database/entities/scan.entity';
export declare class ScansController {
    private readonly scansService;
    constructor(scansService: ScansService);
    validateScan(user: AuthenticatedUser, dto: ValidateScanDto): Promise<{
        success: boolean;
        businessName: string;
        businessCategory: string;
        rewardDescription: string;
        currentPoints: number;
        pointsRequired: number;
        rewardCompleted: boolean;
        totalRewardsClaimed: number;
        message: string;
    }>;
    addManualPoints(user: AuthenticatedUser, dto: AddManualPointsDto): Promise<{
        success: boolean;
        currentPoints: number;
        newRewardsEarned: number;
        totalRewardsClaimed: number;
        message: string;
    }>;
    getBusinessScans(user: AuthenticatedUser, businessId: string, status?: ScanStatus): Promise<import("../../database/entities/scan.entity").Scan[]>;
    updateScanStatus(user: AuthenticatedUser, scanId: string, dto: UpdateScanStatusDto): Promise<import("../../database/entities/scan.entity").Scan>;
}
