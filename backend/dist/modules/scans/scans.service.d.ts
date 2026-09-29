import { Repository, DataSource } from 'typeorm';
import { Scan, ScanStatus } from '../../database/entities/scan.entity';
import { ScanAttempt } from '../../database/entities/scan-attempt.entity';
import { QrCode } from '../../database/entities/qr-code.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Reward } from '../../database/entities/reward.entity';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { ValidateScanDto, AddManualPointsDto, UpdateScanStatusDto } from './dto/scans.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
export declare class ScansService {
    private readonly scanRepository;
    private readonly attemptRepository;
    private readonly qrRepository;
    private readonly businessRepository;
    private readonly cardRepository;
    private readonly rewardRepository;
    private readonly profileRepository;
    private readonly notificationsService;
    private readonly realtimeGateway;
    private readonly dataSource;
    private readonly logger;
    constructor(scanRepository: Repository<Scan>, attemptRepository: Repository<ScanAttempt>, qrRepository: Repository<QrCode>, businessRepository: Repository<Business>, cardRepository: Repository<LoyaltyCard>, rewardRepository: Repository<Reward>, profileRepository: Repository<Profile>, notificationsService: NotificationsService, realtimeGateway: RealtimeGateway, dataSource: DataSource);
    validateScan(userId: string, dto: ValidateScanDto): Promise<{
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
    addManualPoints(callerId: string, callerRole: UserRole, dto: AddManualPointsDto): Promise<{
        success: boolean;
        currentPoints: number;
        newRewardsEarned: number;
        totalRewardsClaimed: number;
        message: string;
    }>;
    getBusinessScans(businessId: string, callerId: string, callerRole: UserRole, status?: ScanStatus): Promise<Scan[]>;
    updateScanStatus(scanId: string, callerId: string, callerRole: UserRole, dto: UpdateScanStatusDto): Promise<Scan>;
}
