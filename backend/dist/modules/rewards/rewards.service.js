"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var RewardsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.RewardsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const reward_entity_1 = require("../../database/entities/reward.entity");
const reward_transfer_history_entity_1 = require("../../database/entities/reward-transfer-history.entity");
const business_entity_1 = require("../../database/entities/business.entity");
const loyalty_card_entity_1 = require("../../database/entities/loyalty-card.entity");
const profile_entity_1 = require("../../database/entities/profile.entity");
const notifications_service_1 = require("../notifications/notifications.service");
const realtime_gateway_1 = require("../realtime/realtime.gateway");
let RewardsService = RewardsService_1 = class RewardsService {
    constructor(rewardRepository, transferRepository, businessRepository, cardRepository, profileRepository, notificationsService, realtimeGateway, dataSource) {
        this.rewardRepository = rewardRepository;
        this.transferRepository = transferRepository;
        this.businessRepository = businessRepository;
        this.cardRepository = cardRepository;
        this.profileRepository = profileRepository;
        this.notificationsService = notificationsService;
        this.realtimeGateway = realtimeGateway;
        this.dataSource = dataSource;
        this.logger = new common_1.Logger(RewardsService_1.name);
    }
    async getUserRewards(userId, status) {
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
    async getBusinessRewards(businessId, callerId, callerRole, status) {
        const business = await this.businessRepository.findOne({ where: { id: businessId } });
        if (!business)
            throw new common_1.NotFoundException('Negocio no encontrado');
        if (business.ownerId !== callerId && callerRole !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('No autorizado para ver premios de este negocio');
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
    async updateRewardStatus(rewardId, callerId, callerRole, dto) {
        const reward = await this.rewardRepository.findOne({
            where: { id: rewardId },
            relations: ['business', 'user', 'loyaltyCard'],
        });
        if (!reward)
            throw new common_1.NotFoundException('Premio no encontrado');
        if (reward.business.ownerId !== callerId && callerRole !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('No autorizado para gestionar este premio');
        }
        reward.status = dto.status;
        if (dto.status === reward_entity_1.RewardStatus.CLAIMED || dto.status === reward_entity_1.RewardStatus.APPROVED) {
            reward.claimedAt = new Date();
        }
        const saved = await this.rewardRepository.save(reward);
        const isApprovedOrClaimed = dto.status === reward_entity_1.RewardStatus.APPROVED || dto.status === reward_entity_1.RewardStatus.CLAIMED;
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
    async transferReward(fromUserId, dto) {
        let recipient = null;
        if (dto.toUserId) {
            recipient = await this.profileRepository.findOne({ where: { id: dto.toUserId } });
        }
        else if (dto.toEmail) {
            recipient = await this.profileRepository.findOne({ where: { email: dto.toEmail.trim().toLowerCase() } });
        }
        if (!recipient) {
            throw new common_1.NotFoundException('Usuario destinatario no encontrado');
        }
        if (fromUserId === recipient.id) {
            throw new common_1.BadRequestException('No puedes transferirte un premio a ti mismo');
        }
        if (recipient.role !== profile_entity_1.UserRole.CLIENT) {
            throw new common_1.BadRequestException('No se puede transferir un premio a una cuenta de negocio.');
        }
        const sender = await this.profileRepository.findOne({ where: { id: fromUserId } });
        if (!sender) {
            throw new common_1.NotFoundException('Usuario remitente no encontrado');
        }
        const reward = await this.rewardRepository.findOne({
            where: { id: dto.rewardId },
            relations: ['business'],
        });
        if (!reward) {
            throw new common_1.NotFoundException('Premio no encontrado');
        }
        if (reward.userId !== fromUserId) {
            throw new common_1.ForbiddenException('No eres el dueno de este premio');
        }
        if (reward.status === reward_entity_1.RewardStatus.CLAIMED) {
            throw new common_1.BadRequestException('No se puede transferir un premio ya canjeado');
        }
        if (reward.status === reward_entity_1.RewardStatus.REJECTED) {
            throw new common_1.BadRequestException('No se puede transferir un premio rechazado');
        }
        const queryRunner = this.dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();
        try {
            let recipientCard = await queryRunner.manager.findOne(loyalty_card_entity_1.LoyaltyCard, {
                where: { userId: dto.toUserId, businessId: reward.businessId },
            });
            if (!recipientCard) {
                recipientCard = queryRunner.manager.create(loyalty_card_entity_1.LoyaltyCard, {
                    userId: dto.toUserId,
                    businessId: reward.businessId,
                    currentPoints: 0,
                    totalPointsLifetime: 0,
                    rewardsClaimed: 0,
                });
                recipientCard = await queryRunner.manager.save(loyalty_card_entity_1.LoyaltyCard, recipientCard);
            }
            reward.userId = dto.toUserId;
            reward.loyaltyCardId = recipientCard.id;
            await queryRunner.manager.save(reward_entity_1.Reward, reward);
            const history = queryRunner.manager.create(reward_transfer_history_entity_1.RewardTransferHistory, {
                rewardId: reward.id,
                businessId: reward.businessId,
                fromUserId,
                toUserId: dto.toUserId,
                transferredAt: new Date(),
            });
            await queryRunner.manager.save(reward_transfer_history_entity_1.RewardTransferHistory, history);
            await queryRunner.commitTransaction();
            const senderName = sender.fullName || 'Un usuario';
            const receiverName = recipient.fullName || 'Un usuario';
            const businessName = reward.business.name;
            await this.notificationsService.sendToUser(dto.toUserId, 'Te han transferido un premio', `${senderName} te regalo un premio de ${businessName}. Entra para ver como retirarlo.`, {
                route: '/transfer_received',
                business_id: reward.businessId,
                loyalty_card_id: recipientCard.id,
                business_name: businessName,
            });
            await this.notificationsService.sendToBusinessOwner(reward.businessId, 'Transferencia de premio', `${senderName} transfirio su premio a ${receiverName}.`, { route: '/business_dashboard' });
            await this.notificationsService.broadcastToAdmins('Premio Transferido', `${senderName} transfirio un premio a ${receiverName} en ${businessName}.`, '/admin_rewards');
            this.realtimeGateway.emitToUser(dto.toUserId, 'reward:transferred', {
                rewardId: reward.id,
                businessId: reward.businessId,
                fromUserName: senderName,
            });
            return {
                success: true,
                message: `Premio transferido exitosamente a ${receiverName}`,
            };
        }
        catch (error) {
            await queryRunner.rollbackTransaction();
            this.logger.error(`Error transferring reward: ${error.message}`);
            throw error;
        }
        finally {
            await queryRunner.release();
        }
    }
    async getTransferHistory(businessId) {
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
};
exports.RewardsService = RewardsService;
exports.RewardsService = RewardsService = RewardsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(reward_entity_1.Reward)),
    __param(1, (0, typeorm_1.InjectRepository)(reward_transfer_history_entity_1.RewardTransferHistory)),
    __param(2, (0, typeorm_1.InjectRepository)(business_entity_1.Business)),
    __param(3, (0, typeorm_1.InjectRepository)(loyalty_card_entity_1.LoyaltyCard)),
    __param(4, (0, typeorm_1.InjectRepository)(profile_entity_1.Profile)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        notifications_service_1.NotificationsService,
        realtime_gateway_1.RealtimeGateway,
        typeorm_2.DataSource])
], RewardsService);
//# sourceMappingURL=rewards.service.js.map