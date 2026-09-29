import { Profile } from './profile.entity';
import { Business } from './business.entity';
import { LoyaltyCard } from './loyalty-card.entity';
import { QrCode } from './qr-code.entity';
export declare enum ScanStatus {
    PENDING = "pending",
    APPROVED = "approved",
    REJECTED = "rejected"
}
export declare class Scan {
    id: string;
    userId: string;
    user: Profile;
    businessId: string;
    business: Business;
    loyaltyCardId: string;
    loyaltyCard: LoyaltyCard;
    qrCodeId: string;
    qrCode: QrCode;
    status: ScanStatus;
    isDemo: boolean;
    scannedAt: Date;
    createdAt: Date;
}
