import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { Business } from '../../database/entities/business.entity';
import { BusinessMember } from '../../database/entities/business-member.entity';
import { PaymentConcept } from '../../database/entities/payment.entity';
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
import { PaymentsService } from '../payments/payments.service';
import { BusinessAccessService } from './business-access.service';

/**
 * Categorias base. Las crea el backend al arrancar si la tabla esta vacia
 * (con DB_SYNCHRONIZE=true las tablas las crea TypeORM y el INSERT de
 * schema.sql nunca se ejecuta). Mantener alineado con schema.sql.
 */
export const DEFAULT_CATEGORIES: ReadonlyArray<{ name: string; icon: string }> = [
  { name: 'Cafeterías & Panaderías', icon: 'coffee' },
  { name: 'Restaurantes & Bares', icon: 'restaurant' },
  { name: 'Belleza & Barberías', icon: 'content_cut' },
  { name: 'Moda & Calzado', icon: 'checkroom' },
  { name: 'Salud & Fitness', icon: 'fitness_center' },
  { name: 'Servicios & Entretenimiento', icon: 'local_activity' },
];

/**
 * Datos de un negocio que puede ver cualquier usuario con sesión. Deja fuera
 * al dueño (su perfil completo), los clientes con tarjeta y la cédula/RUC.
 */
const PUBLIC_BUSINESS_FIELDS = [
  'id',
  'name',
  'description',
  'category',
  'categoryId',
  'categoryRef',
  'logoUrl',
  'address',
  'latitude',
  'longitude',
  'rewardDescription',
  'rewardLongDescription',
  'pointsRequired',
  'isActive',
  'parentId',
  'createdAt',
] as const;

/** Un perfil sin el token de notificaciones push (nadie debe leerlo). */
function withoutPushToken<T extends { fcmToken?: unknown } | null | undefined>(profile: T): T {
  if (!profile) return profile;
  const { fcmToken: _omit, ...rest } = profile as any;
  return rest as T;
}

@Injectable()
export class BusinessesService implements OnModuleInit {
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
    private readonly paymentsService: PaymentsService,
    private readonly businessAccess: BusinessAccessService,
    @InjectRepository(BusinessMember)
    private readonly memberRepository: Repository<BusinessMember>,
  ) {}

  async onModuleInit() {
    await this.seedDefaultCategories();
  }

  /** Crea las categorias base solo si no existe ninguna. Devuelve cuantas creo. */
  async seedDefaultCategories(): Promise<number> {
    try {
      if ((await this.categoryRepository.count()) > 0) return 0;
      const categories = this.categoryRepository.create(
        DEFAULT_CATEGORIES.map((c) => ({ ...c })),
      );
      await this.categoryRepository.save(categories);
      this.logger.log(`Categorias base creadas: ${categories.length}`);
      return categories.length;
    } catch (error) {
      // No impedir el arranque del servidor si la siembra falla.
      this.logger.error(`No se pudieron crear las categorias base: ${error.message}`);
      return 0;
    }
  }

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

    // Siempre inactivo al crearse, sin importar lo que envíe el cliente: lo
    // activa el administrador al validar el pago del registro.
    // Una sucursal cuelga de un negocio principal del mismo dueño.
    if (dto.parentId) {
      const parent = await this.businessRepository.findOne({
        where: { id: dto.parentId },
        select: ['id', 'ownerId', 'parentId'],
      });
      if (!parent || parent.ownerId !== ownerId) {
        throw new BadRequestException('El negocio principal no existe o no es tuyo');
      }
      if (parent.parentId) {
        throw new BadRequestException('Una sucursal no puede tener sus propias sucursales');
      }
    }

    const business = this.businessRepository.create({
      ...dto,
      ownerId,
      isActive: false,
    });

    const saved = await this.businessRepository.save(business);

    // La cuenta queda inactiva hasta que se valide el pago: se crea su orden
    // (las sucursales tienen su propio precio).
    const payment = await this.paymentsService.createOrder(
      saved,
      saved.parentId ? PaymentConcept.BRANCH : PaymentConcept.REGISTRATION,
    );

    // Notify admins of new business
    await this.notificationsService.broadcastToAdmins(
      'Nuevo Negocio Registrado',
      `Se creo el negocio ${saved.name} por ${owner.fullName || 'un usuario'}.`,
      '/admin_businesses',
    );

    return Object.assign(saved, { payment });
  }

  /** Vista completa para el administrador (con dueño y clientes). */
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

    const businesses = await query.getMany();
    return businesses.map((b) => ({
      ...b,
      owner: withoutPushToken(b.owner),
      loyaltyCards: b.loyaltyCards?.map((c) => ({ ...c, user: withoutPushToken(c.user) })),
    }));
  }

  /** Datos que puede ver cualquier usuario con sesión. */
  toPublic(business: Business) {
    const view: Record<string, unknown> = {};
    for (const field of PUBLIC_BUSINESS_FIELDS) view[field] = business[field];
    return view;
  }

  /**
   * Listado de negocios. El administrador ve todo (y, con `all`, también los
   * inactivos); el resto solo los activos y con los datos públicos.
   */
  async listFor(role: UserRole, all: boolean) {
    if (role === UserRole.ADMIN) return this.findAll(!all);
    if (all) {
      throw new ForbiddenException('Solo los administradores pueden ver todos los negocios');
    }
    const businesses = await this.businessRepository.find({
      where: { isActive: true },
      relations: ['categoryRef'],
      order: { createdAt: 'DESC' },
    });
    return businesses.map((b) => this.toPublic(b));
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

  /**
   * Un negocio para quien lo consulta: el administrador y el dueño ven todos
   * sus datos; los demás, solo los públicos.
   */
  async findByIdFor(id: string, userId: string, role: UserRole) {
    const business = await this.findById(id);
    if (role === UserRole.ADMIN || business.ownerId === userId) {
      return { ...business, owner: withoutPushToken(business.owner) };
    }
    return this.toPublic(business);
  }

  async findByOwner(ownerId: string) {
    return this.businessRepository.find({
      where: { ownerId },
      relations: ['categoryRef'],
      order: { createdAt: 'DESC' },
    });
  }

  /**
   * Negocios con los que trabaja un usuario: los suyos (dueño) o aquellos donde
   * fue asignado como aprobador.
   */
  async findForUser(userId: string, role: UserRole) {
    if (role !== UserRole.APPROVER) return this.findByOwner(userId);
    const ids = await this.businessAccess.businessIdsForMember(userId);
    if (ids.length === 0) return [];
    return this.businessRepository.find({
      where: { id: In(ids) },
      relations: ['categoryRef'],
      order: { createdAt: 'DESC' },
    });
  }

  /**
   * Matriz de control del dueño: por cada uno de sus negocios y sucursales,
   * su estado y sus cifras de actividad.
   */
  async getOverview(ownerId: string) {
    const businesses = await this.businessRepository.find({
      where: { ownerId },
      order: { createdAt: 'ASC' },
    });
    if (businesses.length === 0) return [];
    const ids = businesses.map((b) => b.id);

    // Medianoche de Ecuador (UTC-5) en UTC: las 05:00.
    const now = new Date();
    const todayStart = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 5),
    );
    if (todayStart > now) todayStart.setUTCDate(todayStart.getUTCDate() - 1);

    const [cards, scans, today, staff] = await Promise.all([
      this.cardRepository
        .createQueryBuilder('card')
        .select('card.businessId', 'businessId')
        .addSelect('COUNT(*)', 'n')
        .where('card.businessId IN (:...ids)', { ids })
        .groupBy('card.businessId')
        .getRawMany(),
      this.scanRepository
        .createQueryBuilder('scan')
        .select('scan.businessId', 'businessId')
        .addSelect('scan.status', 'status')
        .addSelect('COUNT(*)', 'n')
        .where('scan.businessId IN (:...ids)', { ids })
        .groupBy('scan.businessId')
        .addGroupBy('scan.status')
        .getRawMany(),
      this.scanRepository
        .createQueryBuilder('scan')
        .select('scan.businessId', 'businessId')
        .addSelect('COUNT(*)', 'n')
        .where('scan.businessId IN (:...ids)', { ids })
        .andWhere('scan.scannedAt >= :todayStart', { todayStart })
        .groupBy('scan.businessId')
        .getRawMany(),
      this.memberRepository
        .createQueryBuilder('member')
        .select('member.businessId', 'businessId')
        .addSelect('COUNT(*)', 'n')
        .where('member.businessId IN (:...ids)', { ids })
        .groupBy('member.businessId')
        .getRawMany(),
    ]);

    const count = (rows: any[], id: string, status?: string) =>
      rows
        .filter((r) => r.businessId === id && (status === undefined || r.status === status))
        .reduce((sum, r) => sum + Number(r.n), 0);

    return businesses.map((b) => ({
      id: b.id,
      name: b.name,
      logoUrl: b.logoUrl,
      parentId: b.parentId,
      isActive: b.isActive,
      customers: count(cards, b.id),
      scansToday: count(today, b.id),
      scansTotal: count(scans, b.id),
      pendingScans: count(scans, b.id, ScanStatus.PENDING),
      approvers: count(staff, b.id),
    }));
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

  async toggleStatus(id: string, isActive: boolean, role: UserRole, adminId?: string) {
    if (role !== UserRole.ADMIN) {
      throw new ForbiddenException('Solo los administradores pueden cambiar el estado del negocio');
    }
    const business = await this.findById(id);
    const wasActive = business.isActive;
    business.isActive = isActive;
    const saved = await this.businessRepository.save(business);

    // Activar a mano equivale a confirmar el pago: se cierran sus órdenes
    // abiertas y el dueño recibe su comprobante.
    if (isActive && !wasActive && adminId) {
      await this.paymentsService.settleOpenForBusiness(saved.id, adminId);
    }

    // Al activar la cuenta, avisamos al dueño. Un fallo de la notificación
    // no debe deshacer la activación.
    if (isActive && !wasActive) {
      try {
        await this.notificationsService.sendToBusinessOwner(
          saved.id,
          '¡Tu negocio fue activado!',
          `${saved.name} ya está activo en Fidelity. Vuelve a iniciar sesión para empezar.`,
          { type: 'business_activated' },
        );
      } catch (error) {
        this.logger.warn(`No se pudo notificar la activación: ${error.message}`);
      }
    }

    return saved;
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
