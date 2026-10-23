import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, EntityManager } from 'typeorm';
import { Scan, ScanStatus } from '../../database/entities/scan.entity';
import { ScanAttempt } from '../../database/entities/scan-attempt.entity';
import { QrCode } from '../../database/entities/qr-code.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Reward, RewardStatus } from '../../database/entities/reward.entity';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { ValidateScanDto, AddManualPointsDto, UpdateScanStatusDto } from './dto/scans.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { BusinessAccessService } from '../businesses/business-access.service';
import { CampaignsService } from '../campaigns/campaigns.service';
import { FidelyService } from '../loyalty-cards/fidely.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

/** Regla que impide registrar un escaneo, con el error a devolver al cliente. */
interface ScanBlock {
  reason: string;
  error: HttpException;
}

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
    private readonly businessAccess: BusinessAccessService,
    private readonly campaignsService: CampaignsService,
    private readonly fidelyService: FidelyService,
  ) {}

  /**
   * Registra un escaneo del cliente. El escaneo queda PENDIENTE: el punto solo
   * se suma cuando el negocio lo aprueba (ver updateScanStatus).
   */
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

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    let block: ScanBlock | null = null;

    try {
      const manager = queryRunner.manager;

      // La fila de la tarjeta se bloquea para que dos escaneos simultaneos del
      // mismo cliente no se salten las comprobaciones de abajo.
      let card = await manager.findOne(LoyaltyCard, {
        where: { userId, businessId: business.id },
        lock: { mode: 'pessimistic_write' },
      });

      if (!card) {
        card = manager.create(LoyaltyCard, {
          userId,
          businessId: business.id,
          currentPoints: 0,
          totalPointsLifetime: 0,
          rewardsClaimed: 0,
          lastScanAt: null,
        });
        card = await manager.save(LoyaltyCard, card);
      }

      block = await this.findScanBlock(manager, userId, business, card);
      if (block) {
        await queryRunner.rollbackTransaction();
      } else {
        const userProfile = await manager.findOne(Profile, { where: { id: userId } });
        const isDemo = userProfile?.isDemo || false;

        const scan = await manager.save(
          Scan,
          manager.create(Scan, {
            userId,
            businessId: business.id,
            loyaltyCardId: card.id,
            qrCodeId,
            status: ScanStatus.PENDING,
            isDemo,
            scannedAt: new Date(),
          }),
        );

        // Marca el momento del escaneo: inicia el tiempo de espera y sube la
        // tarjeta al inicio de la lista del cliente.
        card.lastScanAt = new Date();
        const updatedCard = await manager.save(LoyaltyCard, card);

        await manager.save(
          ScanAttempt,
          manager.create(ScanAttempt, {
            userId,
            businessId: business.id,
            qrCodeId,
            success: true,
            failureReason: null,
          }),
        );

        await queryRunner.commitTransaction();

        const clientName = userProfile?.fullName || 'Un cliente';

        // Avisar al negocio que hay un escaneo por aprobar
        this.realtimeGateway.emitToBusiness(business.id, 'scan:new', {
          scanId: scan.id,
          status: ScanStatus.PENDING,
          clientName,
          businessId: business.id,
          cardId: updatedCard.id,
          currentPoints: updatedCard.currentPoints,
        });
        this.realtimeGateway.emitToUser(userId, 'card:updated', updatedCard);

        await this.notificationsService.sendToBusinessStaff(
          business.id,
          'Escaneo por aprobar',
          `${clientName} escaneo en ${business.name}. Apruebalo para sumarle el punto.`,
          { route: '/business_dashboard/pending' },
        );
        await this.notificationsService.broadcastToAdmins(
          'Nuevo Escaneo',
          `${clientName} escaneo en ${business.name}.`,
          '/admin_activity',
        );

        return {
          success: true,
          status: ScanStatus.PENDING,
          scanId: scan.id,
          businessId: business.id,
          businessName: business.name,
          businessCategory: business.category,
          rewardDescription: business.rewardDescription,
          currentPoints: updatedCard.currentPoints,
          pointsRequired: business.pointsRequired,
          rewardCompleted: false,
          message:
            'Escaneo registrado. Espera a que el local lo apruebe para recibir tu punto.',
        };
      }
    } catch (error) {
      if (queryRunner.isTransactionActive) await queryRunner.rollbackTransaction();
      if (error instanceof HttpException) throw error;
      this.logger.error(`Error in validateScan: ${error.message}`);
      throw new BadRequestException(`Error al procesar escaneo: ${error.message}`);
    } finally {
      await queryRunner.release();
    }

    // Escaneo rechazado por una regla: se registra el intento y se informa al cliente.
    await this.attemptRepository.save(
      this.attemptRepository.create({
        userId,
        businessId: business.id,
        qrCodeId,
        success: false,
        failureReason: block!.reason,
      }),
    );
    throw block!.error;
  }

  /**
   * Reglas que impiden registrar un escaneo nuevo. Devuelve el motivo y el
   * error HTTP a lanzar, o null si el escaneo puede registrarse.
   */
  private async findScanBlock(
    manager: EntityManager,
    userId: string,
    business: Business,
    card: LoyaltyCard,
  ): Promise<ScanBlock | null> {
    // Un premio pendiente bloquea nuevos puntos hasta que se entregue.
    const pendingReward = await manager.findOne(Reward, {
      where: { userId, businessId: business.id, status: RewardStatus.PENDING },
    });
    if (pendingReward) {
      return {
        reason: 'pending_reward',
        error: new ConflictException({
          success: false,
          error: 'pending_reward',
          message: `Tienes un premio pendiente en ${business.name}. Reclamalo antes de seguir acumulando puntos.`,
          businessName: business.name,
        }),
      };
    }

    // Un solo escaneo pendiente por negocio.
    const pendingScans = await manager.count(Scan, {
      where: { userId, businessId: business.id, status: ScanStatus.PENDING },
    });
    if (pendingScans > 0) {
      return {
        reason: 'pending_scan',
        error: new ConflictException({
          success: false,
          error: 'pending_scan',
          message: `Ya tienes un escaneo pendiente en ${business.name}. Espera a que el local lo apruebe.`,
          businessName: business.name,
        }),
      };
    }

    // Tiempo de espera entre escaneos del mismo negocio.
    if (card.lastScanAt) {
      const cooldownMs = (business.cooldownHours || 24) * 60 * 60 * 1000;
      const elapsedMs = Date.now() - new Date(card.lastScanAt).getTime();
      if (elapsedMs < cooldownMs) {
        const remainingMinutes = Math.ceil((cooldownMs - elapsedMs) / 60000);
        const remainingHours = Math.floor(remainingMinutes / 60);
        const remainingMins = remainingMinutes % 60;
        return {
          reason: 'cooldown_active',
          error: new HttpException(
            {
              success: false,
              error: 'cooldown',
              message: `Ya escaneaste en ${business.name}. Vuelve en ${remainingHours}h ${remainingMins}min`,
              remainingMinutes,
              remainingHours,
              businessName: business.name,
            },
            HttpStatus.TOO_MANY_REQUESTS,
          ),
        };
      }
    }

    return null;
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

    if (!(await this.businessAccess.canOperate(callerId, callerRole, business.id))) {
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

  /**
   * El negocio aprueba o rechaza un escaneo pendiente. Al aprobar se suma el
   * punto a la tarjeta y, si completa la meta, se genera el premio.
   */
  async updateScanStatus(
    scanId: string,
    callerId: string,
    callerRole: UserRole,
    dto: UpdateScanStatusDto,
  ) {
    if (dto.status !== ScanStatus.APPROVED && dto.status !== ScanStatus.REJECTED) {
      throw new BadRequestException('El estado debe ser approved o rejected');
    }

    const scan = await this.scanRepository.findOne({
      where: { id: scanId },
      relations: ['business', 'user'],
    });

    if (!scan) throw new NotFoundException('Escaneo no encontrado');

    if (!(await this.businessAccess.canOperate(callerId, callerRole, scan.businessId))) {
      throw new ForbiddenException('No autorizado para modificar este escaneo');
    }

    if (scan.status !== ScanStatus.PENDING) {
      throw new ConflictException('Este escaneo ya fue procesado');
    }

    const business = scan.business;

    if (dto.status === ScanStatus.REJECTED) {
      // Actualizacion condicionada: si otro dispositivo lo aprobo mientras
      // tanto, no se pisa su estado.
      const result = await this.scanRepository.update(
        { id: scan.id, status: ScanStatus.PENDING },
        { status: ScanStatus.REJECTED },
      );
      if (!result.affected) throw new ConflictException('Este escaneo ya fue procesado');

      await this.notificationsService.sendToUser(
        scan.userId,
        'Escaneo rechazado',
        `Tu escaneo en ${business.name} fue rechazado.`,
        { route: '/my_cards', business_id: business.id, business_name: business.name },
      );
      this.emitScanStatus(scan, ScanStatus.REJECTED, false);
      return {
        id: scan.id,
        status: ScanStatus.REJECTED,
        userId: scan.userId,
        businessId: business.id,
        loyaltyCardId: scan.loyaltyCardId,
        rewardCompleted: false,
      };
    }

    // APPROVED: sumar el punto de forma atomica.
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const manager = queryRunner.manager;

      // Se bloquea el escaneo: si dos dispositivos lo aprueban a la vez, solo
      // el primero suma el punto.
      const locked = await manager.findOne(Scan, {
        where: { id: scan.id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!locked || locked.status !== ScanStatus.PENDING) {
        throw new ConflictException('Este escaneo ya fue procesado');
      }

      const card = await manager.findOne(LoyaltyCard, {
        where: { id: scan.loyaltyCardId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!card) throw new NotFoundException('Tarjeta de fidelizacion no encontrada');

      const pendingReward = await manager.findOne(Reward, {
        where: {
          userId: scan.userId,
          businessId: business.id,
          status: RewardStatus.PENDING,
        },
      });
      if (pendingReward) {
        throw new BadRequestException(
          'El cliente tiene un premio pendiente. Entregalo antes de aprobar mas puntos o rechaza este escaneo',
        );
      }

      const pointsRequired = business.pointsRequired || 10;
      const newPoints = card.currentPoints + 1;
      const rewardCompleted = newPoints >= pointsRequired;

      card.currentPoints = rewardCompleted ? 0 : newPoints;
      card.totalPointsLifetime = card.totalPointsLifetime + 1;
      if (rewardCompleted) card.rewardsClaimed = card.rewardsClaimed + 1;
      const updatedCard = await manager.save(LoyaltyCard, card);

      if (rewardCompleted) {
        await manager.save(
          Reward,
          manager.create(Reward, {
            userId: scan.userId,
            businessId: business.id,
            loyaltyCardId: card.id,
            rewardDescription: business.rewardDescription,
            description: business.rewardDescription,
            pointsUsed: pointsRequired,
            status: RewardStatus.PENDING,
            isDemo: scan.isDemo,
            earnedAt: new Date(),
          }),
        );
      }

      locked.status = ScanStatus.APPROVED;
      const approved = await manager.save(Scan, locked);

      await queryRunner.commitTransaction();

      // Rutas (pasaporte): un escaneo aprobado suma sello en las rutas vigentes
      // del local. Un fallo aquí nunca debe afectar la aprobación.
      try {
        await this.campaignsService.registerApprovedScan({
          id: approved.id,
          userId: approved.userId,
          businessId: approved.businessId,
          qrCodeId: approved.qrCodeId,
          scannedAt: approved.scannedAt,
        });
      } catch (error) {
        this.logger.warn(`No se pudo registrar el sello de ruta: ${error.message}`);
      }

      // Notificaciones y tiempo real
      if (rewardCompleted) {
        await this.notificationsService.sendToUser(
          scan.userId,
          'Premio alcanzado',
          `Has ganado premio en ${business.name}, acercate a retirar.`,
          {
            route: '/reward',
            business_id: business.id,
            loyalty_card_id: updatedCard.id,
            business_name: business.name,
          },
        );
        await this.notificationsService.sendToBusinessStaff(
          business.id,
          'Premio solicitado',
          `${scan.user?.fullName || 'Un cliente'} gano un premio, pendiente de entrega.`,
          { route: '/business_dashboard/rewards' },
        );
        await this.notificationsService.broadcastToAdmins(
          'Premio Alcanzado',
          `${scan.user?.fullName || 'Un cliente'} alcanzo un premio en ${business.name}.`,
          '/admin_rewards',
        );
      } else {
        await this.notificationsService.sendToUser(
          scan.userId,
          'Punto aprobado',
          `Tu escaneo en ${business.name} fue aprobado.`,
          {
            route: '/points_approved',
            business_id: business.id,
            loyalty_card_id: updatedCard.id,
            business_name: business.name,
          },
        );
      }

      this.realtimeGateway.emitToUser(scan.userId, 'card:updated', updatedCard);
      this.emitScanStatus(scan, ScanStatus.APPROVED, rewardCompleted);

      // FidelyUsuario (después del aviso del punto): al llegar a la cantidad de escaneos aprobados que fija el
      // administrador, el cliente gana la insignia de este local. Un fallo aquí
      // nunca debe afectar la aprobación.
      try {
        await this.fidelyService.onScanApproved(scan.userId, business.id, updatedCard.id);
      } catch (error) {
        this.logger.warn(`No se pudo revisar la insignia FidelyUsuario: ${error.message}`);
      }

      return {
        ...approved,
        success: true,
        rewardCompleted,
        businessName: business.name,
        currentPoints: updatedCard.currentPoints,
        pointsRequired,
        message: rewardCompleted
          ? `Premio generado: ${business.rewardDescription}`
          : `Punto agregado. Progreso: ${updatedCard.currentPoints}/${pointsRequired}`,
      };
    } catch (error) {
      if (queryRunner.isTransactionActive) await queryRunner.rollbackTransaction();
      if (error instanceof HttpException) throw error;
      this.logger.error(`Error in updateScanStatus: ${error.message}`);
      throw new BadRequestException(`Error al procesar la aprobacion: ${error.message}`);
    } finally {
      await queryRunner.release();
    }
  }

  private emitScanStatus(scan: Scan, status: ScanStatus, rewardCompleted: boolean) {
    const payload = {
      scanId: scan.id,
      status,
      businessId: scan.businessId,
      rewardCompleted,
    };
    this.realtimeGateway.emitToUser(scan.userId, 'scan:status', payload);
    this.realtimeGateway.emitToBusiness(scan.businessId, 'scan:status', payload);
  }
}
