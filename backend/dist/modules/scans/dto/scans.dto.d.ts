import { ScanStatus } from '../../../database/entities/scan.entity';
export declare class ValidateScanDto {
    qr_code: string;
}
export declare class AddManualPointsDto {
    userId: string;
    businessId: string;
    points: number;
}
export declare class UpdateScanStatusDto {
    status: ScanStatus;
}
