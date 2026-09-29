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
var AdminService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AdminService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const profile_entity_1 = require("../../database/entities/profile.entity");
const business_entity_1 = require("../../database/entities/business.entity");
const scan_entity_1 = require("../../database/entities/scan.entity");
const reward_entity_1 = require("../../database/entities/reward.entity");
const loyalty_card_entity_1 = require("../../database/entities/loyalty-card.entity");
const reward_transfer_history_entity_1 = require("../../database/entities/reward-transfer-history.entity");
let AdminService = AdminService_1 = class AdminService {
    constructor(profileRepository, businessRepository, scanRepository, rewardRepository, cardRepository, transferRepository) {
        this.profileRepository = profileRepository;
        this.businessRepository = businessRepository;
        this.scanRepository = scanRepository;
        this.rewardRepository = rewardRepository;
        this.cardRepository = cardRepository;
        this.transferRepository = transferRepository;
        this.logger = new common_1.Logger(AdminService_1.name);
    }
    async getDashboardStats() {
        const [totalUsers, totalClients, totalBusinessesOwners, totalAdmins, totalBusinesses, activeBusinesses, totalScans, approvedScans, pendingScans, totalRewards, pendingRewards, claimedRewards, totalTransfers,] = await Promise.all([
            this.profileRepository.count(),
            this.profileRepository.count({ where: { role: profile_entity_1.UserRole.CLIENT } }),
            this.profileRepository.count({ where: { role: profile_entity_1.UserRole.BUSINESS } }),
            this.profileRepository.count({ where: { role: profile_entity_1.UserRole.ADMIN } }),
            this.businessRepository.count(),
            this.businessRepository.count({ where: { isActive: true } }),
            this.scanRepository.count(),
            this.scanRepository.count({ where: { status: scan_entity_1.ScanStatus.APPROVED } }),
            this.scanRepository.count({ where: { status: scan_entity_1.ScanStatus.PENDING } }),
            this.rewardRepository.count(),
            this.rewardRepository.count({ where: { status: reward_entity_1.RewardStatus.PENDING } }),
            this.rewardRepository.count({ where: { status: reward_entity_1.RewardStatus.CLAIMED } }),
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
    async getUsers(role, search) {
        const query = this.profileRepository.createQueryBuilder('profile');
        if (role) {
            query.andWhere('profile.role = :role', { role });
        }
        if (search && search.trim().length > 0) {
            const clean = `%${search.trim()}%`;
            query.andWhere('(profile.email ILIKE :clean OR profile.fullName ILIKE :clean)', { clean });
        }
        query.orderBy('profile.createdAt', 'DESC').take(100);
        return query.getMany();
    }
    async getRecentActivity(limit = 50, businessId, startDate, endDate) {
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
    async getQrStats(startDate, endDate) {
        const query = this.scanRepository
            .createQueryBuilder('scan')
            .leftJoinAndSelect('scan.business', 'business')
            .where('scan.status = :status', { status: scan_entity_1.ScanStatus.APPROVED })
            .andWhere('scan.isDemo = :isDemo', { isDemo: false });
        if (startDate) {
            query.andWhere('scan.scannedAt >= :startDate', { startDate });
        }
        if (endDate) {
            query.andWhere('scan.scannedAt <= :endDate', { endDate });
        }
        return query.orderBy('scan.scannedAt', 'ASC').getMany();
    }
    async getAllRewards(businessId, startDate, endDate) {
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
    async updateUserRole(userId, newRole) {
        const user = await this.profileRepository.findOne({ where: { id: userId } });
        if (!user)
            throw new common_1.NotFoundException('Usuario no encontrado');
        user.role = newRole;
        return this.profileRepository.save(user);
    }
};
exports.AdminService = AdminService;
exports.AdminService = AdminService = AdminService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(profile_entity_1.Profile)),
    __param(1, (0, typeorm_1.InjectRepository)(business_entity_1.Business)),
    __param(2, (0, typeorm_1.InjectRepository)(scan_entity_1.Scan)),
    __param(3, (0, typeorm_1.InjectRepository)(reward_entity_1.Reward)),
    __param(4, (0, typeorm_1.InjectRepository)(loyalty_card_entity_1.LoyaltyCard)),
    __param(5, (0, typeorm_1.InjectRepository)(reward_transfer_history_entity_1.RewardTransferHistory)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], AdminService);
//# sourceMappingURL=admin.service.js.map