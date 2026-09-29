import { Repository, DataSource } from 'typeorm';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { UpdateProfileDto, UpdateFcmTokenDto } from './dto/users.dto';
export declare class UsersService {
    private readonly profileRepository;
    private readonly dataSource;
    private readonly logger;
    constructor(profileRepository: Repository<Profile>, dataSource: DataSource);
    getProfile(userId: string): Promise<Profile>;
    updateProfile(userId: string, dto: UpdateProfileDto): Promise<Profile>;
    updateFcmToken(userId: string, dto: UpdateFcmTokenDto): Promise<Profile>;
    searchUsers(query: string, currentUserId: string): Promise<Profile[]>;
    deleteAccount(userIdToDelete: string, requesterId: string, requesterRole: UserRole): Promise<{
        success: boolean;
        message: string;
    }>;
}
