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
var ScansService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.ScansService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const scan_entity_1 = require("../../database/entities/scan.entity");
const scan_attempt_entity_1 = require("../../database/entities/scan-attempt.entity");
const qr_code_entity_1 = require("../../database/entities/qr-code.entity");
const business_entity_1 = require("../../database/entities/business.entity");
const loyalty_card_entity_1 = require("../../database/entities/loyalty-card.entity");
const reward_entity_1 = require("../../database/entities/reward.entity");
const profile_entity_1 = require("../../database/entities/profile.entity");
const notifications_service_1 = require("../notifications/notifications.service");
const realtime_gateway_1 = require("../realtime/realtime.gateway");
let ScansService = ScansService_1 = class ScansService {
    constructor(scanRepository, attemptRepository, qrRepository, businessRepository, cardRepository, rewardRepository, profileRepository, notificationsService, realtimeGateway, dataSource) {
        this.scanRepository = scanRepository;
        this.attemptRepository = attemptRepository;
        this.qrRepository = qrRepository;
        this.businessRepository = businessRepository;
        this.cardRepository = cardRepository;
        this.rewardRepository = rewardRepository;
        this.profileRepository = profileRepository;
        this.notificationsService = notificationsService;
        this.realtimeGateway = realtimeGateway;
        this.dataSource = dataSource;
        this.logger = new common_1.Logger(ScansService_1.name);
    }
    async validateScan(userId, dto) {
        const qrCodeStr = dto.qr_code.trim();
        const qrData = await this.qrRepository.findOne({
            where: { qrCode: qrCodeStr, isActive: true },
            relations: ['business'],
        });
        if (!qrData || !qrData.business || !qrData.business.isActive) {
            await this.attemptRepository.save(this.attemptRepository.create({
                userId,
                businessId: qrData?.businessId || null,
                qrCodeId: qrData?.id || null,
                success: false,
                failureReason: 'invalid_qr_or_inactive_business',
            }));
            throw new common_1.NotFoundException({
                success: false,
                error: 'QR invalido o negocio inactivo',
            });
        }
        const business = qrData.business;
        const qrCodeId = qrData.id;
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
                await this.attemptRepository.save(this.attemptRepository.create({
                    userId,
                    businessId: business.id,
                    qrCodeId,
                    success: false,
                    failureReason: 'cooldown_active',
                }));
                throw new common_1.HttpException({
                    success: false,
                    error: 'cooldown',
                    message: `Ya escaneaste en ${business.name}. Vuelve en ${remainingHours}h ${remainingMins}min`,
                    remainingMinutes,
                    remainingHours,
                    businessName: business.name,
                }, common_1.HttpStatus.TOO_MANY_REQUESTS);
            }
        }
        const queryRunner = this.dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();
        try {
            let card = await queryRunner.manager.findOne(loyalty_card_entity_1.LoyaltyCard, {
                where: { userId, businessId: business.id },
            });
            if (!card) {
                card = queryRunner.manager.create(loyalty_card_entity_1.LoyaltyCard, {
                    userId,
                    businessId: business.id,
                    currentPoints: 0,
                    totalPointsLifetime: 0,
                    rewardsClaimed: 0,
                    lastScanAt: null,
                });
                card = await queryRunner.manager.save(loyalty_card_entity_1.LoyaltyCard, card);
            }
            const userProfile = await queryRunner.manager.findOne(profile_entity_1.Profile, { where: { id: userId } });
            const isDemo = userProfile?.isDemo || false;
            const newScan = queryRunner.manager.create(scan_entity_1.Scan, {
                userId,
                businessId: business.id,
                loyaltyCardId: card.id,
                qrCodeId,
                status: scan_entity_1.ScanStatus.APPROVED,
                isDemo,
                scannedAt: new Date(),
            });
            const savedScan = await queryRunner.manager.save(scan_entity_1.Scan, newScan);
            const pointsRequired = business.pointsRequired || 10;
            const newPoints = card.currentPoints + 1;
            const isRewardComplete = newPoints >= pointsRequired;
            card.currentPoints = isRewardComplete ? 0 : newPoints;
            card.totalPointsLifetime = card.totalPointsLifetime + 1;
            if (isRewardComplete) {
                card.rewardsClaimed = card.rewardsClaimed + 1;
            }
            card.lastScanAt = new Date();
            const updatedCard = await queryRunner.manager.save(loyalty_card_entity_1.LoyaltyCard, card);
            let newReward = null;
            if (isRewardComplete) {
                newReward = queryRunner.manager.create(reward_entity_1.Reward, {
                    userId,
                    businessId: business.id,
                    loyaltyCardId: card.id,
                    rewardDescription: business.rewardDescription,
                    description: business.rewardDescription,
                    pointsUsed: pointsRequired,
                    status: reward_entity_1.RewardStatus.PENDING,
                    isDemo,
                    earnedAt: new Date(),
                });
                await queryRunner.manager.save(reward_entity_1.Reward, newReward);
            }
            const attempt = queryRunner.manager.create(scan_attempt_entity_1.ScanAttempt, {
                userId,
                businessId: business.id,
                qrCodeId,
                success: true,
                failureReason: null,
            });
            await queryRunner.manager.save(scan_attempt_entity_1.ScanAttempt, attempt);
            await queryRunner.commitTransaction();
            const clientName = userProfile?.fullName || 'Un cliente';
            this.realtimeGateway.emitToBusiness(business.id, 'scan:new', {
                scanId: savedScan.id,
                clientName,
                businessId: business.id,
                cardId: updatedCard.id,
                currentPoints: updatedCard.currentPoints,
                rewardCompleted: isRewardComplete,
            });
            this.realtimeGateway.emitToUser(userId, 'card:updated', updatedCard);
            if (isRewardComplete) {
                await this.notificationsService.sendToUser(userId, 'Premio alcanzado', `Has ganado premio en ${business.name}, acercate a retirar.`, {
                    route: '/reward',
                    business_id: business.id,
                    loyalty_card_id: updatedCard.id,
                    business_name: business.name,
                });
                await this.notificationsService.sendToBusinessOwner(business.id, 'Premio solicitado', `${clientName} gano un premio, pendiente de entrega.`, { route: '/business_dashboard/rewards' });
                await this.notificationsService.broadcastToAdmins('Premio Alcanzado', `${clientName} alcanzo un premio en ${business.name}.`, '/admin_rewards');
            }
            else {
                await this.notificationsService.broadcastToAdmins('Nuevo Escaneo', `${clientName} escaneo en ${business.name}.`, '/admin_activity');
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
        }
        catch (error) {
            await queryRunner.rollbackTransaction();
            if (error instanceof common_1.HttpException)
                throw error;
            this.logger.error(`Error in validateScan: ${error.message}`);
            throw new common_1.BadRequestException(`Error al procesar escaneo: ${error.message}`);
        }
        finally {
            await queryRunner.release();
        }
    }
    async addManualPoints(callerId, callerRole, dto) {
        const business = await this.businessRepository.findOne({
            where: { id: dto.businessId },
        });
        if (!business) {
            throw new common_1.NotFoundException('Negocio no encontrado');
        }
        if (business.ownerId !== callerId && callerRole !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('Solo el dueno del negocio puede asignar puntos manuales');
        }
        const pendingReward = await this.rewardRepository.findOne({
            where: {
                userId: dto.userId,
                businessId: dto.businessId,
                status: reward_entity_1.RewardStatus.PENDING,
            },
        });
        if (pendingReward) {
            throw new common_1.BadRequestException('El usuario tiene un premio pendiente. No se pueden otorgar mas puntos hasta que se apruebe o canjee');
        }
        const queryRunner = this.dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();
        try {
            let card = await queryRunner.manager.findOne(loyalty_card_entity_1.LoyaltyCard, {
                where: { userId: dto.userId, businessId: dto.businessId },
            });
            if (!card) {
                card = queryRunner.manager.create(loyalty_card_entity_1.LoyaltyCard, {
                    userId: dto.userId,
                    businessId: dto.businessId,
                    currentPoints: 0,
                    totalPointsLifetime: 0,
                    rewardsClaimed: 0,
                });
                card = await queryRunner.manager.save(loyalty_card_entity_1.LoyaltyCard, card);
            }
            const client = await queryRunner.manager.findOne(profile_entity_1.Profile, { where: { id: dto.userId } });
            const isDemo = client?.isDemo || false;
            const pointsRequired = business.pointsRequired || 10;
            const totalNewPoints = card.currentPoints + dto.points;
            const newRewards = Math.floor(totalNewPoints / pointsRequired);
            card.currentPoints = totalNewPoints % pointsRequired;
            card.totalPointsLifetime = card.totalPointsLifetime + dto.points;
            card.rewardsClaimed = card.rewardsClaimed + newRewards;
            card.lastScanAt = new Date();
            const updatedCard = await queryRunner.manager.save(loyalty_card_entity_1.LoyaltyCard, card);
            for (let i = 0; i < dto.points; i++) {
                const scan = queryRunner.manager.create(scan_entity_1.Scan, {
                    userId: dto.userId,
                    businessId: dto.businessId,
                    loyaltyCardId: card.id,
                    qrCodeId: null,
                    status: scan_entity_1.ScanStatus.APPROVED,
                    isDemo,
                    scannedAt: new Date(),
                });
                await queryRunner.manager.save(scan_entity_1.Scan, scan);
            }
            if (newRewards > 0) {
                for (let i = 0; i < newRewards; i++) {
                    const reward = queryRunner.manager.create(reward_entity_1.Reward, {
                        userId: dto.userId,
                        businessId: dto.businessId,
                        loyaltyCardId: card.id,
                        pointsUsed: pointsRequired,
                        rewardDescription: business.rewardDescription,
                        description: business.rewardDescription,
                        status: reward_entity_1.RewardStatus.PENDING,
                        isDemo,
                        earnedAt: new Date(),
                    });
                    await queryRunner.manager.save(reward_entity_1.Reward, reward);
                }
            }
            await queryRunner.commitTransaction();
            await this.notificationsService.sendToUser(dto.userId, 'Punto asignado manualmente', `${business.name} te ha otorgado ${dto.points} puntos.`, {
                route: '/points_approved',
                business_id: business.id,
                loyalty_card_id: updatedCard.id,
                business_name: business.name,
            });
            this.realtimeGateway.emitToUser(dto.userId, 'card:updated', updatedCard);
            return {
                success: true,
                currentPoints: updatedCard.currentPoints,
                newRewardsEarned: newRewards,
                totalRewardsClaimed: updatedCard.rewardsClaimed,
                message: `Se asignaron ${dto.points} puntos exitosamente`,
            };
        }
        catch (error) {
            await queryRunner.rollbackTransaction();
            this.logger.error(`Error in addManualPoints: ${error.message}`);
            throw error;
        }
        finally {
            await queryRunner.release();
        }
    }
    async getBusinessScans(businessId, callerId, callerRole, status) {
        const business = await this.businessRepository.findOne({ where: { id: businessId } });
        if (!business)
            throw new common_1.NotFoundException('Negocio no encontrado');
        if (business.ownerId !== callerId && callerRole !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('No autorizado para ver escaneos de este negocio');
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
    async updateScanStatus(scanId, callerId, callerRole, dto) {
        const scan = await this.scanRepository.findOne({
            where: { id: scanId },
            relations: ['business', 'user', 'loyaltyCard'],
        });
        if (!scan)
            throw new common_1.NotFoundException('Escaneo no encontrado');
        if (scan.business.ownerId !== callerId && callerRole !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('No autorizado para modificar este escaneo');
        }
        scan.status = dto.status;
        const saved = await this.scanRepository.save(scan);
        const title = dto.status === scan_entity_1.ScanStatus.APPROVED ? 'Punto aprobado' : 'Escaneo rechazado';
        const body = dto.status === scan_entity_1.ScanStatus.APPROVED
            ? `Tu escaneo en ${scan.business.name} fue aprobado.`
            : `Tu escaneo en ${scan.business.name} fue rechazado.`;
        await this.notificationsService.sendToUser(scan.userId, title, body, {
            route: dto.status === scan_entity_1.ScanStatus.APPROVED ? '/points_approved' : '/my_cards',
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
};
exports.ScansService = ScansService;
exports.ScansService = ScansService = ScansService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(scan_entity_1.Scan)),
    __param(1, (0, typeorm_1.InjectRepository)(scan_attempt_entity_1.ScanAttempt)),
    __param(2, (0, typeorm_1.InjectRepository)(qr_code_entity_1.QrCode)),
    __param(3, (0, typeorm_1.InjectRepository)(business_entity_1.Business)),
    __param(4, (0, typeorm_1.InjectRepository)(loyalty_card_entity_1.LoyaltyCard)),
    __param(5, (0, typeorm_1.InjectRepository)(reward_entity_1.Reward)),
    __param(6, (0, typeorm_1.InjectRepository)(profile_entity_1.Profile)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        notifications_service_1.NotificationsService,
        realtime_gateway_1.RealtimeGateway,
        typeorm_2.DataSource])
], ScansService);
//# sourceMappingURL=scans.service.js.map