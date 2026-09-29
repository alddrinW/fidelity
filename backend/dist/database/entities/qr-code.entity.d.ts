import { Business } from './business.entity';
export declare class QrCode {
    id: string;
    businessId: string;
    business: Business;
    qrCode: string;
    label: string;
    isActive: boolean;
    createdAt: Date;
}
