import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { RegisterDto, LoginDto, ResetPasswordDto } from './dto/auth.dto';
import { NotificationsService } from '../notifications/notifications.service';
export declare class AuthService {
    private readonly profileRepository;
    private readonly jwtService;
    private readonly notificationsService;
    private readonly logger;
    constructor(profileRepository: Repository<Profile>, jwtService: JwtService, notificationsService: NotificationsService);
    register(dto: RegisterDto): Promise<{
        user: {
            id: string;
            email: string;
            fullName: string;
            role: UserRole;
            avatarUrl: string;
            phone: string;
            isDemo: boolean;
        };
        accessToken: string;
    }>;
    login(dto: LoginDto): Promise<{
        user: {
            id: string;
            email: string;
            fullName: string;
            role: UserRole;
            avatarUrl: string;
            phone: string;
            fcmToken: string;
            isDemo: boolean;
        };
        accessToken: string;
    }>;
    resetPassword(dto: ResetPasswordDto): Promise<{
        message: string;
    }>;
    getProfile(userId: string): Promise<Profile>;
    private generateToken;
}
