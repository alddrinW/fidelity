import { Repository } from 'typeorm';
import { QrCode } from '../../database/entities/qr-code.entity';
import { Business } from '../../database/entities/business.entity';
import { Scan } from '../../database/entities/scan.entity';
import { CreateQrCodeDto, ToggleQrCodeDto } from './dto/qr-codes.dto';
import { UserRole } from '../../database/entities/profile.entity';
export declare class QrCodesService {
    private readonly qrRepository;
    private readonly businessRepository;
    private readonly scanRepository;
    private readonly logger;
    constructor(qrRepository: Repository<QrCode>, businessRepository: Repository<Business>, scanRepository: Repository<Scan>);
    createQrCode(callerId: string, callerRole: UserRole, dto: CreateQrCodeDto): Promise<QrCode>;
    getBusinessQrCodes(businessId: string, callerId: string, callerRole: UserRole): Promise<QrCode[]>;
    toggleQrCode(qrId: string, callerId: string, callerRole: UserRole, dto: ToggleQrCodeDto): Promise<QrCode>;
    updateQrCode(qrId: string, callerId: string, callerRole: UserRole, dto: {
        qrCode?: string;
        label?: string;
        isActive?: boolean;
    }): Promise<QrCode>;
    getQrStats(qrId: string, callerId: string, callerRole: UserRole): Promise<{
        qrId: string;
        qrCode: string;
        label: string;
        isActive: boolean;
        totalScans: number;
    }>;
}
