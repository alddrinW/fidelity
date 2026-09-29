import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Business } from '../../database/entities/business.entity';
import { BusinessCategory } from '../../database/entities/business-category.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Scan, ScanStatus } from '../../database/entities/scan.entity';
import { Reward, RewardStatus } from '../../database/entities/reward.entity';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import {
  CreateBusinessDto,
  UpdateBusinessDto,
  CreateCategoryDto,
} from './dto/businesses.dto';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class BusinessesService {
  private readonly logger = new Logger(BusinessesService.name);

  constructor(
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(BusinessCategory)
    private readonly categoryRepository: Repository<BusinessCategory>,
    @InjectRepository(LoyaltyCard)
    private readonly cardRepository: Repository<LoyaltyCard>,
    @InjectRepository(Scan)
    private readonly scanRepository: Repository<Scan>,
    @InjectRepository(Reward)
    private readonly rewardRepository: Repository<Reward>,
    @InjectRepository(Profile)
    private readonly profileRepository: Repository<Profile>,
    private readonly notificationsService: NotificationsService,
  ) {}

  // Categories
  async getCategories() {
    return this.categoryRepository.find({ order: { name: 'ASC' } });
  }

  async createCategory(dto: CreateCategoryDto) {
    const category = this.categoryRepository.create(dto);
    return this.categoryRepository.save(category);
  }

  async deleteCategory(id: number) {
    const result = await this.categoryRepository.delete(id);
    if (result.affected === 0) {
      throw new NotFoundException('Categoria no encontrada');
    }
    return { success: true, message: 'Categoria eliminada exitosamente' };
  }

  // Businesses
  async createBusiness(ownerId: string, dto: CreateBusinessDto) {
    const owner = await this.profileRepository.findOne({ where: { id: ownerId } });
    if (!owner) {
      throw new NotFoundException('Perfil de dueno no encontrado');
    }

    // Upgrade profile role to business if it was client
    if (owner.role === UserRole.CLIENT) {
      owner.role = UserRole.BUSINESS;
      await this.profileRepository.save(owner);
    }

    const business = this.businessRepository.create({
      ...dto,
      ownerId,
    });

    const saved = await this.businessRepository.save(business);

    // Notify admins of new business
    await this.notificationsService.broadcastToAdmins(
      'Nuevo Negocio Registrado',
      `Se creo el negocio ${saved.name} por ${owner.fullName || 'un usuario'}.`,
      '/admin_businesses',
    );

    return saved;
  }

  async findAll(activeOnly: boolean = true) {
    const query = this.businessRepository
      .createQueryBuilder('business')
      .leftJoinAndSelect('business.categoryRef', 'categoryRef')
      .leftJoinAndSelect('business.owner', 'owner')
      .leftJoinAndSelect('business.loyaltyCards', 'loyaltyCards')
      .leftJoinAndSelect('loyaltyCards.user', 'loyaltyCardUser')
      .orderBy('business.createdAt', 'DESC');

    if (activeOnly) {
      query.where('business.isActive = :isActive', { isActive: true });
    }

    return query.getMany();
  }

  async findById(id: string) {
    const business = await this.businessRepository.findOne({
      where: { id },
      relations: ['categoryRef', 'owner'],
    });
    if (!business) {
      throw new NotFoundException('Negocio no encontrado');
    }
    return business;
  }

  async findByOwner(ownerId: string) {
    return this.businessRepository.find({
      where: { ownerId },
      relations: ['categoryRef'],
      order: { createdAt: 'DESC' },
    });
  }

  async updateBusiness(
    id: string,
    ownerId: string,
    role: UserRole,
    dto: UpdateBusinessDto,
  ) {
    const business = await this.findById(id);

    if (business.ownerId !== ownerId && role !== UserRole.ADMIN) {
      throw new ForbiddenException('Solo el dueno del negocio o un administrador pueden editarlo');
    }

    Object.assign(business, dto);
    return this.businessRepository.save(business);
  }

  async toggleStatus(id: string, isActive: boolean, role: UserRole) {
    if (role !== UserRole.ADMIN) {
      throw new ForbiddenException('Solo los administradores pueden cambiar el estado del negocio');
    }
    const business = await this.findById(id);
    business.isActive = isActive;
    return this.businessRepository.save(business);
  }

  async getBusinessStats(businessId: string, ownerId: string, role: UserRole) {
    const business = await this.findById(businessId);
    if (business.ownerId !== ownerId && role !== UserRole.ADMIN) {
      throw new ForbiddenException('No tienes permiso para ver las estadisticas de este negocio');
    }

    const [
      totalClients,
      totalScans,
      pendingScans,
      approvedScans,
      totalRewardsEarned,
      pendingRewards,
      claimedRewards,
    ] = await Promise.all([
      this.cardRepository.count({ where: { businessId } }),
      this.scanRepository.count({ where: { businessId } }),
      this.scanRepository.count({ where: { businessId, status: ScanStatus.PENDING } }),
      this.scanRepository.count({ where: { businessId, status: ScanStatus.APPROVED } }),
      this.rewardRepository.count({ where: { businessId } }),
      this.rewardRepository.count({ where: { businessId, status: RewardStatus.PENDING } }),
      this.rewardRepository.count({ where: { businessId, status: RewardStatus.CLAIMED } }),
    ]);

    return {
      businessId,
      businessName: business.name,
      totalClients,
      totalScans,
      pendingScans,
      approvedScans,
      totalRewardsEarned,
      pendingRewards,
      claimedRewards,
    };
  }
}
