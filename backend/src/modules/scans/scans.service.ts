import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Scan, ScanStatus } from '../../database/entities/scan.entity';
import { ScanAttempt } from '../../database/entities/scan-attempt.entity';
import { QrCode } from '../../database/entities/qr-code.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Reward, RewardStatus } from '../../database/entities/reward.entity';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { ValidateScanDto, AddManualPointsDto, UpdateScanStatusDto } from './dto/scans.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

@Injectable()
export class ScansService {
  private readonly logger = new Logger(ScansService.name);

  constructor(
    @InjectRepository(Scan)
    private readonly scanRepository: Repository<Scan>,
    @InjectRepository(ScanAttempt)
    private readonly attemptRepository: Repository<ScanAttempt>,
    @InjectRepository(QrCode)
    private readonly qrRepository: Repository<QrCode>,
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(LoyaltyCard)
    private readonly cardRepository: Repository<LoyaltyCard>,
    @InjectRepository(Reward)
    private readonly rewardRepository: Repository<Reward>,
    @InjectRepository(Profile)
    private readonly profileRepository: Repository<Profile>,
    private readonly notificationsService: NotificationsService,
    private readonly realtimeGateway: RealtimeGateway,
    private readonly dataSource: DataSource,
  ) {}

  async validateScan(userId: string, dto: ValidateScanDto) {
    const qrCodeStr = dto.qr_code.trim();

    // 1. Verify QR exists and is active, and business is active
    const qrData = await this.qrRepository.findOne({
      where: { qrCode: qrCodeStr, isActive: true },
      relations: ['business'],
    });

    if (!qrData || !qrData.business || !qrData.business.isActive) {
      await this.attemptRepository.save(
        this.attemptRepository.create({
          userId,
          businessId: qrData?.businessId || null,
          qrCodeId: qrData?.id || null,
          success: false,
          failureReason: 'invalid_qr_or_inactive_business',
        }),
      );

      throw new NotFoundException({
        success: false,
        error: 'QR invalido o negocio inactivo',
      });
    }

    const business = qrData.business;
    const qrCodeId = qrData.id;

    // 2. Verify COOLDOWN
    const loyaltyCard = await this.cardRepository.findOne({
      where: { userId, businessId: business.id },
    });

    if (loyaltyCard && loyaltyCard.lastScanAt) {
      const lastScanTime = new Date(loyaltyCard.lastScanAt).getTime();
      const currentTime = Date.now();
      const cooldownMs = (business.cooldownHours || 24) * 60 * 60 * 1000;
      const timeSinceLastScan = currentTime - lastScanTime;

      if (timeSinceLastScan < cooldownMs) {
        const remainingMs = cooldownMs - timeSinceLastScan;
        const remainingMinutes = Math.ceil(remainingMs / 60000);
        const remainingHours = Math.floor(remainingMinutes / 60);
        const remainingMins = remainingMinutes % 60;

        await this.attemptRepository.save(
          this.attemptRepository.create({
            userId,
            businessId: business.id,
            qrCodeId,
            success: false,
            failureReason: 'cooldown_active',
          }),
        );

        throw new HttpException(
          {
            success: false,
            error: 'cooldown',
            message: `Ya escaneaste en ${business.name}. Vuelve en ${remainingHours}h ${remainingMins}min`,
            remainingMinutes,
            remainingHours,
            businessName: business.name,
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
    }

    // 3. Execute Transaction for Atomic Scan Processing
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // Get or create card
      let card = await queryRunner.manager.findOne(LoyaltyCard, {
        where: { userId, businessId: business.id },
      });

      if (!card) {
        card = queryRunner.manager.create(LoyaltyCard, {
          userId,
          businessId: business.id,
          currentPoints: 0,
          totalPointsLifetime: 0,
          rewardsClaimed: 0,
          lastScanAt: null,
        });
        card = await queryRunner.manager.save(LoyaltyCard, card);
      }

      // Check if user is demo
      const userProfile = await queryRunner.manager.findOne(Profile, { where: { id: userId } });
      const isDemo = userProfile?.isDemo || false;

      // Register Scan
      const newScan = queryRunner.manager.create(Scan, {
        userId,
        businessId: business.id,
        loyaltyCardId: card.id,
        qrCodeId,
        status: ScanStatus.APPROVED,
        isDemo,
        scannedAt: new Date(),
      });
      const savedScan = await queryRunner.manager.save(Scan, newScan);

      // Update Card Points
      const pointsRequired = business.pointsRequired || 10;
      const newPoints = card.currentPoints + 1;
      const isRewardComplete = newPoints >= pointsRequired;

      card.currentPoints = isRewardComplete ? 0 : newPoints;
      card.totalPointsLifetime = card.totalPointsLifetime + 1;
      if (isRewardComplete) {
        card.rewardsClaimed = card.rewardsClaimed + 1;
      }
      card.lastScanAt = new Date();
      const updatedCard = await queryRunner.manager.save(LoyaltyCard, card);

      // If reward reached, create Reward record
      let newReward: Reward | null = null;
      if (isRewardComplete) {
        newReward = queryRunner.manager.create(Reward, {
          userId,
          businessId: business.id,
          loyaltyCardId: card.id,
          rewardDescription: business.rewardDescription,
          description: business.rewardDescription,
          pointsUsed: pointsRequired,
          status: RewardStatus.PENDING,
          isDemo,
          earnedAt: new Date(),
        });
        await queryRunner.manager.save(Reward, newReward);
      }

      // Record successful attempt
      const attempt = queryRunner.manager.create(ScanAttempt, {
        userId,
        businessId: business.id,
        qrCodeId,
        success: true,
        failureReason: null,
      });
      await queryRunner.manager.save(ScanAttempt, attempt);

      await queryRunner.commitTransaction();

      // Notifications & Realtime Broadcasting
      const clientName = userProfile?.fullName || 'Un cliente';

      // 1. Emit WebSockets
      this.realtimeGateway.emitToBusiness(business.id, 'scan:new', {
        scanId: savedScan.id,
        clientName,
        businessId: business.id,
        cardId: updatedCard.id,
        currentPoints: updatedCard.currentPoints,
        rewardCompleted: isRewardComplete,
      });
      this.realtimeGateway.emitToUser(userId, 'card:updated', updatedCard);

      // 2. Push Notifications
      if (isRewardComplete) {
        // Notify client
        await this.notificationsService.sendToUser(
          userId,
          'Premio alcanzado',
          `Has ganado premio en ${business.name}, acercate a retirar.`,
          {
            route: '/reward',
            business_id: business.id,
            loyalty_card_id: updatedCard.id,
            business_name: business.name,
          },
        );
        // Notify owner
        await this.notificationsService.sendToBusinessOwner(
          business.id,
          'Premio solicitado',
          `${clientName} gano un premio, pendiente de entrega.`,
          { route: '/business_dashboard/rewards' },
        );
        // Notify admins
        await this.notificationsService.broadcastToAdmins(
          'Premio Alcanzado',
          `${clientName} alcanzo un premio en ${business.name}.`,
          '/admin_rewards',
        );
      } else {
        await this.notificationsService.broadcastToAdmins(
          'Nuevo Escaneo',
          `${clientName} escaneo en ${business.name}.`,
          '/admin_activity',
        );
      }

      return {
        success: true,
        businessName: business.name,
        businessCategory: business.category,
        rewardDescription: business.rewardDescription,
        currentPoints: updatedCard.currentPoints,
        pointsRequired: business.pointsRequired,
        rewardCompleted: isRewardComplete,
        totalRewardsClaimed: updatedCard.rewardsClaimed,
        message: isRewardComplete
          ? `Felicitaciones Ganaste: ${business.rewardDescription}`
          : `Punto agregado. Progreso: ${updatedCard.currentPoints}/${business.pointsRequired}`,
      };
    } catch (error) {
      await queryRunner.rollbackTransaction();
      if (error instanceof HttpException) throw error;
      this.logger.error(`Error in validateScan: ${error.message}`);
      throw new BadRequestException(`Error al procesar escaneo: ${error.message}`);
    } finally {
      await queryRunner.release();
    }
  }

  async addManualPoints(callerId: string, callerRole: UserRole, dto: AddManualPointsDto) {
    const business = await this.businessRepository.findOne({
      where: { id: dto.businessId },
    });

    if (!business) {
      throw new NotFoundException('Negocio no encontrado');
    }

    if (business.ownerId !== callerId && callerRole !== UserRole.ADMIN) {
      throw new ForbiddenException('Solo el dueno del negocio puede asignar puntos manuales');
    }

    // Check if user has a pending reward
    const pendingReward = await this.rewardRepository.findOne({
      where: {
        userId: dto.userId,
        businessId: dto.businessId,
        status: RewardStatus.PENDING,
      },
    });

    if (pendingReward) {
      throw new BadRequestException(
        'El usuario tiene un premio pendiente. No se pueden otorgar mas puntos hasta que se apruebe o canjee',
      );
    }

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      let card = await queryRunner.manager.findOne(LoyaltyCard, {
        where: { userId: dto.userId, businessId: dto.businessId },
      });

      if (!card) {
        card = queryRunner.manager.create(LoyaltyCard, {
          userId: dto.userId,
          businessId: dto.businessId,
          currentPoints: 0,
          totalPointsLifetime: 0,
          rewardsClaimed: 0,
        });
        card = await queryRunner.manager.save(LoyaltyCard, card);
      }

      const client = await queryRunner.manager.findOne(Profile, { where: { id: dto.userId } });
      const isDemo = client?.isDemo || false;
      const pointsRequired = business.pointsRequired || 10;

      const totalNewPoints = card.currentPoints + dto.points;
      const newRewards = Math.floor(totalNewPoints / pointsRequired);
      card.currentPoints = totalNewPoints % pointsRequired;
      card.totalPointsLifetime = card.totalPointsLifetime + dto.points;
      card.rewardsClaimed = card.rewardsClaimed + newRewards;
      card.lastScanAt = new Date();

      const updatedCard = await queryRunner.manager.save(LoyaltyCard, card);

      // Insert scans for each point
      for (let i = 0; i < dto.points; i++) {
        const scan = queryRunner.manager.create(Scan, {
          userId: dto.userId,
          businessId: dto.businessId,
          loyaltyCardId: card.id,
          qrCodeId: null,
          status: ScanStatus.APPROVED,
          isDemo,
          scannedAt: new Date(),
        });
        await queryRunner.manager.save(Scan, scan);
      }

      // Insert rewards if achieved
      if (newRewards > 0) {
        for (let i = 0; i < newRewards; i++) {
          const reward = queryRunner.manager.create(Reward, {
            userId: dto.userId,
            businessId: dto.businessId,
            loyaltyCardId: card.id,
            pointsUsed: pointsRequired,
            rewardDescription: business.rewardDescription,
            description: business.rewardDescription,
            status: RewardStatus.PENDING,
            isDemo,
            earnedAt: new Date(),
          });
          await queryRunner.manager.save(Reward, reward);
        }
      }

      await queryRunner.commitTransaction();

      // Notify Client
      await this.notificationsService.sendToUser(
        dto.userId,
        'Punto asignado manualmente',
        `${business.name} te ha otorgado ${dto.points} puntos.`,
        {
          route: '/points_approved',
          business_id: business.id,
          loyalty_card_id: updatedCard.id,
          business_name: business.name,
        },
      );

      this.realtimeGateway.emitToUser(dto.userId, 'card:updated', updatedCard);

      return {
        success: true,
        currentPoints: updatedCard.currentPoints,
        newRewardsEarned: newRewards,
        totalRewardsClaimed: updatedCard.rewardsClaimed,
        message: `Se asignaron ${dto.points} puntos exitosamente`,
      };
    } catch (error) {
      await queryRunner.rollbackTransaction();
      this.logger.error(`Error in addManualPoints: ${error.message}`);
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  async getBusinessScans(
    businessId: string,
    callerId: string,
    callerRole: UserRole,
    status?: ScanStatus,
  ) {
    const business = await this.businessRepository.findOne({ where: { id: businessId } });
    if (!business) throw new NotFoundException('Negocio no encontrado');

    if (business.ownerId !== callerId && callerRole !== UserRole.ADMIN) {
      throw new ForbiddenException('No autorizado para ver escaneos de este negocio');
    }

    const query = this.scanRepository
      .createQueryBuilder('scan')
      .leftJoinAndSelect('scan.user', 'user')
      .leftJoinAndSelect('scan.loyaltyCard', 'card')
      .where('scan.businessId = :businessId', { businessId })
      .orderBy('scan.scannedAt', 'DESC')
      .take(100);

    if (status) {
      query.andWhere('scan.status = :status', { status });
    }

    return query.getMany();
  }

  async updateScanStatus(
    scanId: string,
    callerId: string,
    callerRole: UserRole,
    dto: UpdateScanStatusDto,
  ) {
    const scan = await this.scanRepository.findOne({
      where: { id: scanId },
      relations: ['business', 'user', 'loyaltyCard'],
    });

    if (!scan) throw new NotFoundException('Escaneo no encontrado');

    if (scan.business.ownerId !== callerId && callerRole !== UserRole.ADMIN) {
      throw new ForbiddenException('No autorizado para modificar este escaneo');
    }

    scan.status = dto.status;
    const saved = await this.scanRepository.save(scan);

    // Notify user of status change
    const title = dto.status === ScanStatus.APPROVED ? 'Punto aprobado' : 'Escaneo rechazado';
    const body =
      dto.status === ScanStatus.APPROVED
        ? `Tu escaneo en ${scan.business.name} fue aprobado.`
        : `Tu escaneo en ${scan.business.name} fue rechazado.`;

    await this.notificationsService.sendToUser(scan.userId, title, body, {
      route: dto.status === ScanStatus.APPROVED ? '/points_approved' : '/my_cards',
      business_id: scan.businessId,
      loyalty_card_id: scan.loyaltyCardId,
      business_name: scan.business.name,
    });

    this.realtimeGateway.emitToUser(scan.userId, 'scan:status', {
      scanId: scan.id,
      status: scan.status,
    });

    return saved;
  }
}
