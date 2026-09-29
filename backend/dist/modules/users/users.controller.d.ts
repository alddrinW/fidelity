import { UsersService } from './users.service';
import { UpdateProfileDto, UpdateFcmTokenDto } from './dto/users.dto';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
export declare class UsersController {
    private readonly usersService;
    constructor(usersService: UsersService);
    getMyProfile(user: AuthenticatedUser): Promise<import("../../database/entities").Profile>;
    getProfileById(id: string): Promise<import("../../database/entities").Profile>;
    updateProfile(user: AuthenticatedUser, dto: UpdateProfileDto): Promise<import("../../database/entities").Profile>;
    updateFcmToken(user: AuthenticatedUser, dto: UpdateFcmTokenDto): Promise<import("../../database/entities").Profile>;
    searchUsers(user: AuthenticatedUser, query: string): Promise<import("../../database/entities").Profile[]>;
    deleteMyAccount(user: AuthenticatedUser): Promise<{
        success: boolean;
        message: string;
    }>;
    deleteAccountById(user: AuthenticatedUser, id: string): Promise<{
        success: boolean;
        message: string;
    }>;
}
