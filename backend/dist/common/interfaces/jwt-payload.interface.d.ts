import { UserRole } from '../../database/entities/profile.entity';
export interface JwtPayload {
    sub: string;
    email: string;
    role: UserRole;
    fullName?: string;
}
export interface AuthenticatedUser {
    id: string;
    email: string;
    role: UserRole;
    fullName?: string;
    fcmToken?: string;
}
