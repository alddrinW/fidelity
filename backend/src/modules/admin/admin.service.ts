import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { Business } from '../../database/entities/business.entity';
import { Scan, ScanStatus } from '../../database/entities/scan.entity';
import { Reward, RewardStatus } from '../../database/entities/reward.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { RewardTransferHistory } from '../../database/entities/reward-transfer-history.entity';

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(
    @InjectRepository(Profile)
    private readonly profileRepository: Repository<Profile>,
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(Scan)
    private readonly scanRepository: Repository<Scan>,
    @InjectRepository(Reward)
    private readonly rewardRepository: Repository<Reward>,
    @InjectRepository(LoyaltyCard)
    private readonly cardRepository: Repository<LoyaltyCard>,
    @InjectRepository(RewardTransferHistory)
    private readonly transferRepository: Repository<RewardTransferHistory>,
  ) {}

  async getDashboardStats() {
    const [
      totalUsers,
      totalClients,
      totalBusinessesOwners,
      totalAdmins,
      totalBusinesses,
      activeBusinesses,
      totalScans,
      approvedScans,
      pendingScans,
      totalRewards,
      pendingRewards,
      claimedRewards,
      totalTransfers,
    ] = await Promise.all([
      this.profileRepository.count(),
      this.profileRepository.count({ where: { role: UserRole.CLIENT } }),
      this.profileRepository.count({ where: { role: UserRole.BUSINESS } }),
      this.profileRepository.count({ where: { role: UserRole.ADMIN } }),
      this.businessRepository.count(),
      this.businessRepository.count({ where: { isActive: true } }),
      this.scanRepository.count(),
      this.scanRepository.count({ where: { status: ScanStatus.APPROVED } }),
      this.scanRepository.count({ where: { status: ScanStatus.PENDING } }),
      this.rewardRepository.count(),
      this.rewardRepository.count({ where: { status: RewardStatus.PENDING } }),
      this.rewardRepository.count({ where: { status: RewardStatus.CLAIMED } }),
      this.transferRepository.count(),
    ]);

    return {
      users: {
        total: totalUsers,
        clients: totalClients,
        businessOwners: totalBusinessesOwners,
        admins: totalAdmins,
      },
      businesses: {
        total: totalBusinesses,
        active: activeBusinesses,
        inactive: totalBusinesses - activeBusinesses,
      },
      scans: {
        total: totalScans,
        approved: approvedScans,
        pending: pendingScans,
      },
      rewards: {
        total: totalRewards,
        pending: pendingRewards,
        claimed: claimedRewards,
      },
      transfers: {
        total: totalTransfers,
      },
    };
  }

  async getUsers(role?: UserRole, search?: string) {
    const query = this.profileRepository.createQueryBuilder('profile');

    if (role) {
      query.andWhere('profile.role = :role', { role });
    }

    if (search && search.trim().length > 0) {
      const clean = `%${search.trim()}%`;
      query.andWhere(
        '(profile.email ILIKE :clean OR profile.fullName ILIKE :clean)',
        { clean },
      );
    }

    query.orderBy('profile.createdAt', 'DESC').take(100);
    return query.getMany();
  }

  async getRecentActivity(
    limit: number = 50,
    businessId?: string,
    startDate?: string,
    endDate?: string,
  ) {
    const query = this.scanRepository
      .createQueryBuilder('scan')
      .leftJoinAndSelect('scan.user', 'user')
      .leftJoinAndSelect('scan.business', 'business')
      .orderBy('scan.scannedAt', 'DESC')
      .take(limit);

    if (businessId && businessId !== 'all') {
      query.andWhere('scan.businessId = :businessId', { businessId });
    }
    if (startDate) {
      query.andWhere('scan.scannedAt >= :startDate', { startDate });
    }
    if (endDate) {
      query.andWhere('scan.scannedAt <= :endDate', { endDate });
    }

    return query.getMany();
  }

  async getQrStats(startDate?: string, endDate?: string) {
    const query = this.scanRepository
      .createQueryBuilder('scan')
      .leftJoinAndSelect('scan.business', 'business')
      .where('scan.status = :status', { status: ScanStatus.APPROVED })
      .andWhere('scan.isDemo = :isDemo', { isDemo: false });

    if (startDate) {
      query.andWhere('scan.scannedAt >= :startDate', { startDate });
    }
    if (endDate) {
      query.andWhere('scan.scannedAt <= :endDate', { endDate });
    }

    return query.orderBy('scan.scannedAt', 'ASC').getMany();
  }

  async getAllRewards(businessId?: string, startDate?: string, endDate?: string) {
    const query = this.rewardRepository
      .createQueryBuilder('reward')
      .leftJoinAndSelect('reward.business', 'business')
      .leftJoinAndSelect('reward.user', 'user')
      .leftJoinAndSelect('reward.loyaltyCard', 'loyaltyCard')
      .orderBy('reward.earnedAt', 'DESC');

    if (businessId && businessId !== 'all') {
      query.andWhere('reward.businessId = :businessId', { businessId });
    }
    if (startDate) {
      query.andWhere('reward.earnedAt >= :startDate', { startDate });
    }
    if (endDate) {
      query.andWhere('reward.earnedAt <= :endDate', { endDate });
    }

    return query.getMany();
  }

  async updateUserRole(userId: string, newRole: UserRole) {
    const user = await this.profileRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('Usuario no encontrado');

    user.role = newRole;
    return this.profileRepository.save(user);
  }
}
