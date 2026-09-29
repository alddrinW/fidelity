import { UserRole } from '../../../database/entities/profile.entity';
export declare class RegisterDto {
    email: string;
    password: string;
    fullName: string;
    role?: UserRole;
    phone?: string;
    avatarUrl?: string;
    fcmToken?: string;
    isDemo?: boolean;
}
export declare class LoginDto {
    email: string;
    password: string;
    fcmToken?: string;
}
export declare class ResetPasswordDto {
    email: string;
}
