import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, ILike } from 'typeorm';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Scan } from '../../database/entities/scan.entity';
import { ScanAttempt } from '../../database/entities/scan-attempt.entity';
import { Reward } from '../../database/entities/reward.entity';
import { SupportTicket } from '../../database/entities/support-ticket.entity';
import { QrCode } from '../../database/entities/qr-code.entity';
import { UpdateProfileDto, UpdateFcmTokenDto } from './dto/users.dto';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    @InjectRepository(Profile)
    private readonly profileRepository: Repository<Profile>,
    private readonly dataSource: DataSource,
  ) {}

  async getProfile(userId: string) {
    const profile = await this.profileRepository.findOne({
      where: { id: userId },
    });
    if (!profile) {
      throw new NotFoundException('Perfil de usuario no encontrado');
    }
    return profile;
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const profile = await this.getProfile(userId);

    if (dto.fullName !== undefined) profile.fullName = dto.fullName.trim();
    if (dto.phone !== undefined) profile.phone = dto.phone.trim();
    if (dto.avatarUrl !== undefined) profile.avatarUrl = dto.avatarUrl;
    if (dto.fcmToken !== undefined) profile.fcmToken = dto.fcmToken;

    return this.profileRepository.save(profile);
  }

  async updateFcmToken(userId: string, dto: UpdateFcmTokenDto) {
    const profile = await this.getProfile(userId);
    profile.fcmToken = dto.fcmToken;
    return this.profileRepository.save(profile);
  }

  async searchUsers(query: string, currentUserId: string) {
    if (!query || query.trim().length === 0) return [];

    const cleanQuery = `%${query.trim()}%`;
    const users = await this.profileRepository
      .createQueryBuilder('profile')
      .where('profile.id != :currentUserId', { currentUserId })
      .andWhere(
        '(profile.email ILIKE :cleanQuery OR profile.fullName ILIKE :cleanQuery)',
        { cleanQuery },
      )
      .select(['profile.id', 'profile.email', 'profile.fullName', 'profile.avatarUrl'])
      .take(20)
      .getMany();

    return users;
  }

  async deleteAccount(userIdToDelete: string, requesterId: string, requesterRole: UserRole) {
    // Security check: only own account or admin
    if (userIdToDelete !== requesterId && requesterRole !== UserRole.ADMIN) {
      throw new ForbiddenException('Solo puedes eliminar tu propia cuenta');
    }

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // Find businesses owned by the user
      const ownedBusinesses = await queryRunner.manager.find(Business, {
        where: { ownerId: userIdToDelete },
      });
      const businessIds = ownedBusinesses.map((b) => b.id);

      // 1. Delete scan attempts
      let scanAttemptQuery = queryRunner.manager
        .createQueryBuilder()
        .delete()
        .from(ScanAttempt)
        .where('userId = :userId', { userId: userIdToDelete });
      if (businessIds.length > 0) {
        scanAttemptQuery = scanAttemptQuery.orWhere('businessId IN (:...businessIds)', { businessIds });
      }
      await scanAttemptQuery.execute();

      // 2. Delete scans
      let scansQuery = queryRunner.manager
        .createQueryBuilder()
        .delete()
        .from(Scan)
        .where('userId = :userId', { userId: userIdToDelete });
      if (businessIds.length > 0) {
        scansQuery = scansQuery.orWhere('businessId IN (:...businessIds)', { businessIds });
      }
      await scansQuery.execute();

      // 3. Delete rewards
      let rewardsQuery = queryRunner.manager
        .createQueryBuilder()
        .delete()
        .from(Reward)
        .where('userId = :userId', { userId: userIdToDelete });
      if (businessIds.length > 0) {
        rewardsQuery = rewardsQuery.orWhere('businessId IN (:...businessIds)', { businessIds });
      }
      await rewardsQuery.execute();

      // 4. Delete loyalty cards
      let cardsQuery = queryRunner.manager
        .createQueryBuilder()
        .delete()
        .from(LoyaltyCard)
        .where('userId = :userId', { userId: userIdToDelete });
      if (businessIds.length > 0) {
        cardsQuery = cardsQuery.orWhere('businessId IN (:...businessIds)', { businessIds });
      }
      await cardsQuery.execute();

      // 5. Delete support tickets
      let ticketsQuery = queryRunner.manager
        .createQueryBuilder()
        .delete()
        .from(SupportTicket)
        .where('userId = :userId', { userId: userIdToDelete });
      if (businessIds.length > 0) {
        ticketsQuery = ticketsQuery.orWhere('businessId IN (:...businessIds)', { businessIds });
      }
      await ticketsQuery.execute();

      // 6. Delete QR codes of owned businesses
      if (businessIds.length > 0) {
        await queryRunner.manager
          .createQueryBuilder()
          .delete()
          .from(QrCode)
          .where('businessId IN (:...businessIds)', { businessIds })
          .execute();
      }

      // 7. Delete owned businesses
      if (businessIds.length > 0) {
        await queryRunner.manager.delete(Business, { ownerId: userIdToDelete });
      }

      // 8. Delete Profile
      await queryRunner.manager.delete(Profile, { id: userIdToDelete });

      await queryRunner.commitTransaction();
      this.logger.log(`Account data completely deleted for user: ${userIdToDelete}`);

      return {
        success: true,
        message: 'Cuenta y datos asociados eliminados exitosamente',
      };
    } catch (error) {
      await queryRunner.rollbackTransaction();
      this.logger.error(`Error deleting user data: ${error.message}`);
      throw error;
    } finally {
      await queryRunner.release();
    }
  }
}
