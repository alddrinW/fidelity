export declare class CreateBusinessDto {
    name: string;
    description?: string;
    categoryId?: number;
    category?: string;
    logoUrl?: string;
    rewardDescription?: string;
    pointsRequired?: number;
    cooldownHours?: number;
    latitude?: number;
    longitude?: number;
    address?: string;
    phone?: string;
}
export declare class UpdateBusinessDto {
    name?: string;
    description?: string;
    categoryId?: number;
    category?: string;
    logoUrl?: string;
    rewardDescription?: string;
    pointsRequired?: number;
    cooldownHours?: number;
    isActive?: boolean;
    latitude?: number;
    longitude?: number;
    address?: string;
    phone?: string;
}
export declare class CreateCategoryDto {
    name: string;
    icon?: string;
}
export declare class ToggleBusinessStatusDto {
    isActive: boolean;
}
