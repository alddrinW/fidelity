import { QrCodesService } from './qr-codes.service';
import { CreateQrCodeDto, ToggleQrCodeDto, UpdateQrCodeDto } from './dto/qr-codes.dto';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
export declare class QrCodesController {
    private readonly qrService;
    constructor(qrService: QrCodesService);
    createQrCode(user: AuthenticatedUser, dto: CreateQrCodeDto): Promise<import("../../database/entities").QrCode>;
    getBusinessQrCodes(user: AuthenticatedUser, businessId: string): Promise<import("../../database/entities").QrCode[]>;
    updateQrCode(user: AuthenticatedUser, qrId: string, dto: UpdateQrCodeDto): Promise<import("../../database/entities").QrCode>;
    toggleQrCode(user: AuthenticatedUser, qrId: string, dto: ToggleQrCodeDto): Promise<import("../../database/entities").QrCode>;
    getQrStats(user: AuthenticatedUser, qrId: string): Promise<{
        qrId: string;
        qrCode: string;
        label: string;
        isActive: boolean;
        totalScans: number;
    }>;
}
