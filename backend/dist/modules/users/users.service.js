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
var UsersService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.UsersService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const profile_entity_1 = require("../../database/entities/profile.entity");
const business_entity_1 = require("../../database/entities/business.entity");
const loyalty_card_entity_1 = require("../../database/entities/loyalty-card.entity");
const scan_entity_1 = require("../../database/entities/scan.entity");
const scan_attempt_entity_1 = require("../../database/entities/scan-attempt.entity");
const reward_entity_1 = require("../../database/entities/reward.entity");
const support_ticket_entity_1 = require("../../database/entities/support-ticket.entity");
const qr_code_entity_1 = require("../../database/entities/qr-code.entity");
let UsersService = UsersService_1 = class UsersService {
    constructor(profileRepository, dataSource) {
        this.profileRepository = profileRepository;
        this.dataSource = dataSource;
        this.logger = new common_1.Logger(UsersService_1.name);
    }
    async getProfile(userId) {
        const profile = await this.profileRepository.findOne({
            where: { id: userId },
        });
        if (!profile) {
            throw new common_1.NotFoundException('Perfil de usuario no encontrado');
        }
        return profile;
    }
    async updateProfile(userId, dto) {
        const profile = await this.getProfile(userId);
        if (dto.fullName !== undefined)
            profile.fullName = dto.fullName.trim();
        if (dto.phone !== undefined)
            profile.phone = dto.phone.trim();
        if (dto.avatarUrl !== undefined)
            profile.avatarUrl = dto.avatarUrl;
        if (dto.fcmToken !== undefined)
            profile.fcmToken = dto.fcmToken;
        return this.profileRepository.save(profile);
    }
    async updateFcmToken(userId, dto) {
        const profile = await this.getProfile(userId);
        profile.fcmToken = dto.fcmToken;
        return this.profileRepository.save(profile);
    }
    async searchUsers(query, currentUserId) {
        if (!query || query.trim().length === 0)
            return [];
        const cleanQuery = `%${query.trim()}%`;
        const users = await this.profileRepository
            .createQueryBuilder('profile')
            .where('profile.id != :currentUserId', { currentUserId })
            .andWhere('(profile.email ILIKE :cleanQuery OR profile.fullName ILIKE :cleanQuery)', { cleanQuery })
            .select(['profile.id', 'profile.email', 'profile.fullName', 'profile.avatarUrl'])
            .take(20)
            .getMany();
        return users;
    }
    async deleteAccount(userIdToDelete, requesterId, requesterRole) {
        if (userIdToDelete !== requesterId && requesterRole !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('Solo puedes eliminar tu propia cuenta');
        }
        const queryRunner = this.dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();
        try {
            const ownedBusinesses = await queryRunner.manager.find(business_entity_1.Business, {
                where: { ownerId: userIdToDelete },
            });
            const businessIds = ownedBusinesses.map((b) => b.id);
            let scanAttemptQuery = queryRunner.manager
                .createQueryBuilder()
                .delete()
                .from(scan_attempt_entity_1.ScanAttempt)
                .where('userId = :userId', { userId: userIdToDelete });
            if (businessIds.length > 0) {
                scanAttemptQuery = scanAttemptQuery.orWhere('businessId IN (:...businessIds)', { businessIds });
            }
            await scanAttemptQuery.execute();
            let scansQuery = queryRunner.manager
                .createQueryBuilder()
                .delete()
                .from(scan_entity_1.Scan)
                .where('userId = :userId', { userId: userIdToDelete });
            if (businessIds.length > 0) {
                scansQuery = scansQuery.orWhere('businessId IN (:...businessIds)', { businessIds });
            }
            await scansQuery.execute();
            let rewardsQuery = queryRunner.manager
                .createQueryBuilder()
                .delete()
                .from(reward_entity_1.Reward)
                .where('userId = :userId', { userId: userIdToDelete });
            if (businessIds.length > 0) {
                rewardsQuery = rewardsQuery.orWhere('businessId IN (:...businessIds)', { businessIds });
            }
            await rewardsQuery.execute();
            let cardsQuery = queryRunner.manager
                .createQueryBuilder()
                .delete()
                .from(loyalty_card_entity_1.LoyaltyCard)
                .where('userId = :userId', { userId: userIdToDelete });
            if (businessIds.length > 0) {
                cardsQuery = cardsQuery.orWhere('businessId IN (:...businessIds)', { businessIds });
            }
            await cardsQuery.execute();
            let ticketsQuery = queryRunner.manager
                .createQueryBuilder()
                .delete()
                .from(support_ticket_entity_1.SupportTicket)
                .where('userId = :userId', { userId: userIdToDelete });
            if (businessIds.length > 0) {
                ticketsQuery = ticketsQuery.orWhere('businessId IN (:...businessIds)', { businessIds });
            }
            await ticketsQuery.execute();
            if (businessIds.length > 0) {
                await queryRunner.manager
                    .createQueryBuilder()
                    .delete()
                    .from(qr_code_entity_1.QrCode)
                    .where('businessId IN (:...businessIds)', { businessIds })
                    .execute();
            }
            if (businessIds.length > 0) {
                await queryRunner.manager.delete(business_entity_1.Business, { ownerId: userIdToDelete });
            }
            await queryRunner.manager.delete(profile_entity_1.Profile, { id: userIdToDelete });
            await queryRunner.commitTransaction();
            this.logger.log(`Account data completely deleted for user: ${userIdToDelete}`);
            return {
                success: true,
                message: 'Cuenta y datos asociados eliminados exitosamente',
            };
        }
        catch (error) {
            await queryRunner.rollbackTransaction();
            this.logger.error(`Error deleting user data: ${error.message}`);
            throw error;
        }
        finally {
            await queryRunner.release();
        }
    }
};
exports.UsersService = UsersService;
exports.UsersService = UsersService = UsersService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(profile_entity_1.Profile)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.DataSource])
], UsersService);
//# sourceMappingURL=users.service.js.map