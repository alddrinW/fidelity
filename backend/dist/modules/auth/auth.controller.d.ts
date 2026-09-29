import { AuthService } from './auth.service';
import { RegisterDto, LoginDto, ResetPasswordDto } from './dto/auth.dto';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
export declare class AuthController {
    private readonly authService;
    constructor(authService: AuthService);
    register(dto: RegisterDto): Promise<{
        user: {
            id: string;
            email: string;
            fullName: string;
            role: import("../../database/entities").UserRole;
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
            role: import("../../database/entities").UserRole;
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
    getMe(user: AuthenticatedUser): Promise<import("../../database/entities").Profile>;
}
