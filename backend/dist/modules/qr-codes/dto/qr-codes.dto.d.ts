export declare class CreateQrCodeDto {
    businessId: string;
    label?: string;
    qrCode?: string;
}
export declare class ToggleQrCodeDto {
    isActive: boolean;
}
export declare class UpdateQrCodeDto {
    qrCode?: string;
    label?: string;
    isActive?: boolean;
}
