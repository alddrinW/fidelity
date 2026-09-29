import { Profile } from './profile.entity';
import { Business } from './business.entity';
import { QrCode } from './qr-code.entity';
export declare class ScanAttempt {
    id: string;
    userId: string;
    user: Profile;
    businessId: string;
    business: Business;
    qrCodeId: string;
    qrCode: QrCode;
    success: boolean;
    failureReason: string;
    createdAt: Date;
}
