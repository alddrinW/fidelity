import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Reward, RewardStatus } from '../../database/entities/reward.entity';
import { RewardTransferHistory } from '../../database/entities/reward-transfer-history.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { UpdateRewardStatusDto, TransferRewardDto } from './dto/rewards.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { BusinessAccessService } from '../businesses/business-access.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

@Injectable()
export class RewardsService {
  private readonly logger = new Logger(RewardsService.name);

  constructor(
    @InjectRepository(Reward)
    private readonly rewardRepository: Repository<Reward>,
    @InjectRepository(RewardTransferHistory)
    private readonly transferRepository: Repository<RewardTransferHistory>,
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(LoyaltyCard)
    private readonly cardRepository: Repository<LoyaltyCard>,
    @InjectRepository(Profile)
    private readonly profileRepository: Repository<Profile>,
    private readonly notificationsService: NotificationsService,
    private readonly realtimeGateway: RealtimeGateway,
    private readonly dataSource: DataSource,
    private readonly businessAccess: BusinessAccessService,
  ) {}

  async getUserRewards(userId: string, status?: RewardStatus) {
    const query = this.rewardRepository
      .createQueryBuilder('reward')
      .leftJoinAndSelect('reward.business', 'business')
      .leftJoinAndSelect('reward.loyaltyCard', 'card')
      .where('reward.userId = :userId', { userId })
      .orderBy('reward.earnedAt', 'DESC');

    if (status) {
      query.andWhere('reward.status = :status', { status });
    }

    return query.getMany();
  }

  async getBusinessRewards(
    businessId: string,
    callerId: string,
    callerRole: UserRole,
    status?: RewardStatus,
  ) {
    const business = await this.businessRepository.findOne({ where: { id: businessId } });
    if (!business) throw new NotFoundException('Negocio no encontrado');

    if (!(await this.businessAccess.canOperate(callerId, callerRole, business.id))) {
      throw new ForbiddenException('No autorizado para ver premios de este negocio');
    }

    const query = this.rewardRepository
      .createQueryBuilder('reward')
      .leftJoinAndSelect('reward.user', 'user')
      .leftJoinAndSelect('reward.loyaltyCard', 'card')
      .where('reward.businessId = :businessId', { businessId })
      .orderBy('reward.earnedAt', 'DESC');

    if (status) {
      query.andWhere('reward.status = :status', { status });
    }

    return query.getMany();
  }

  async updateRewardStatus(
    rewardId: string,
    callerId: string,
    callerRole: UserRole,
    dto: UpdateRewardStatusDto,
  ) {
    const reward = await this.rewardRepository.findOne({
      where: { id: rewardId },
      relations: ['business', 'user', 'loyaltyCard'],
    });

    if (!reward) throw new NotFoundException('Premio no encontrado');

    if (!(await this.businessAccess.canOperate(callerId, callerRole, reward.businessId))) {
      throw new ForbiddenException('No autorizado para gestionar este premio');
    }

    reward.status = dto.status;
    if (dto.status === RewardStatus.CLAIMED || dto.status === RewardStatus.APPROVED) {
      reward.claimedAt = new Date();
    }

    const saved = await this.rewardRepository.save(reward);

    const isApprovedOrClaimed =
      dto.status === RewardStatus.APPROVED || dto.status === RewardStatus.CLAIMED;
    const title = isApprovedOrClaimed ? 'Premio entregado' : 'Premio rechazado';
    const body = isApprovedOrClaimed
      ? `Tu premio en ${reward.business.name} fue aprobado.`
      : `Tu premio en ${reward.business.name} fue rechazado.`;

    await this.notificationsService.sendToUser(reward.userId, title, body, {
      route: '/reward',
      business_id: reward.businessId,
      loyalty_card_id: reward.loyaltyCardId,
      business_name: reward.business.name,
    });

    this.realtimeGateway.emitToUser(reward.userId, 'reward:status', {
      rewardId: reward.id,
      status: reward.status,
    });

    return saved;
  }

  async transferReward(fromUserId: string, dto: TransferRewardDto) {
    let recipient: Profile | null = null;
    if (dto.toUserId) {
      recipient = await this.profileRepository.findOne({ where: { id: dto.toUserId } });
    } else if (dto.toEmail) {
      recipient = await this.profileRepository.findOne({ where: { email: dto.toEmail.trim().toLowerCase() } });
    }

    if (!recipient) {
      throw new NotFoundException('Usuario destinatario no encontrado');
    }

    if (fromUserId === recipient.id) {
      throw new BadRequestException('No puedes transferirte un premio a ti mismo');
    }

    if (recipient.role !== UserRole.CLIENT) {
      throw new BadRequestException('No se puede transferir un premio a una cuenta de negocio.');
    }

    const sender = await this.profileRepository.findOne({ where: { id: fromUserId } });
    if (!sender) {
      throw new NotFoundException('Usuario remitente no encontrado');
    }

    const reward = await this.rewardRepository.findOne({
      where: { id: dto.rewardId },
      relations: ['business'],
    });

    if (!reward) {
      throw new NotFoundException('Premio no encontrado');
    }

    if (reward.userId !== fromUserId) {
      throw new ForbiddenException('No eres el dueno de este premio');
    }

    if (reward.status === RewardStatus.CLAIMED) {
      throw new BadRequestException('No se puede transferir un premio ya canjeado');
    }

    if (reward.status === RewardStatus.REJECTED) {
      throw new BadRequestException('No se puede transferir un premio rechazado');
    }

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // Find or create recipient's loyalty card for this business
      let recipientCard = await queryRunner.manager.findOne(LoyaltyCard, {
        where: { userId: dto.toUserId, businessId: reward.businessId },
      });

      if (!recipientCard) {
        recipientCard = queryRunner.manager.create(LoyaltyCard, {
          userId: dto.toUserId,
          businessId: reward.businessId,
          currentPoints: 0,
          totalPointsLifetime: 0,
          rewardsClaimed: 0,
        });
        recipientCard = await queryRunner.manager.save(LoyaltyCard, recipientCard);
      }

      // Update reward owner and loyalty card
      reward.userId = dto.toUserId;
      reward.loyaltyCardId = recipientCard.id;
      await queryRunner.manager.save(Reward, reward);

      // Record transfer history
      const history = queryRunner.manager.create(RewardTransferHistory, {
        rewardId: reward.id,
        businessId: reward.businessId,
        fromUserId,
        toUserId: dto.toUserId,
        transferredAt: new Date(),
      });
      await queryRunner.manager.save(RewardTransferHistory, history);

      await queryRunner.commitTransaction();

      // Notifications
      const senderName = sender.fullName || 'Un usuario';
      const receiverName = recipient.fullName || 'Un usuario';
      const businessName = reward.business.name;

      // 1. Notify recipient
      await this.notificationsService.sendToUser(
        dto.toUserId,
        'Te han transferido un premio',
        `${senderName} te regalo un premio de ${businessName}. Entra para ver como retirarlo.`,
        {
          route: '/transfer_received',
          business_id: reward.businessId,
          loyalty_card_id: recipientCard.id,
          business_name: businessName,
        },
      );

      // 2. Notify business owner
      await this.notificationsService.sendToBusinessOwner(
        reward.businessId,
        'Transferencia de premio',
        `${senderName} transfirio su premio a ${receiverName}.`,
        { route: '/business_dashboard' },
      );

      // 3. Notify admins
      await this.notificationsService.broadcastToAdmins(
        'Premio Transferido',
        `${senderName} transfirio un premio a ${receiverName} en ${businessName}.`,
        '/admin_rewards',
      );

      // 4. Realtime emit
      this.realtimeGateway.emitToUser(dto.toUserId, 'reward:transferred', {
        rewardId: reward.id,
        businessId: reward.businessId,
        fromUserName: senderName,
      });

      return {
        success: true,
        message: `Premio transferido exitosamente a ${receiverName}`,
      };
    } catch (error) {
      await queryRunner.rollbackTransaction();
      this.logger.error(`Error transferring reward: ${error.message}`);
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  async getTransferHistory(businessId?: string) {
    const query = this.transferRepository
      .createQueryBuilder('transfer')
      .leftJoinAndSelect('transfer.fromUser', 'fromUser')
      .leftJoinAndSelect('transfer.toUser', 'toUser')
      .leftJoinAndSelect('transfer.business', 'business')
      .leftJoinAndSelect('transfer.reward', 'reward')
      .orderBy('transfer.transferredAt', 'DESC')
      .take(100);

    if (businessId) {
      query.where('transfer.businessId = :businessId', { businessId });
    }

    return query.getMany();
  }
}
