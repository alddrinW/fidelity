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
var BusinessesService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.BusinessesService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const business_entity_1 = require("../../database/entities/business.entity");
const business_category_entity_1 = require("../../database/entities/business-category.entity");
const loyalty_card_entity_1 = require("../../database/entities/loyalty-card.entity");
const scan_entity_1 = require("../../database/entities/scan.entity");
const reward_entity_1 = require("../../database/entities/reward.entity");
const profile_entity_1 = require("../../database/entities/profile.entity");
const notifications_service_1 = require("../notifications/notifications.service");
let BusinessesService = BusinessesService_1 = class BusinessesService {
    constructor(businessRepository, categoryRepository, cardRepository, scanRepository, rewardRepository, profileRepository, notificationsService) {
        this.businessRepository = businessRepository;
        this.categoryRepository = categoryRepository;
        this.cardRepository = cardRepository;
        this.scanRepository = scanRepository;
        this.rewardRepository = rewardRepository;
        this.profileRepository = profileRepository;
        this.notificationsService = notificationsService;
        this.logger = new common_1.Logger(BusinessesService_1.name);
    }
    async getCategories() {
        return this.categoryRepository.find({ order: { name: 'ASC' } });
    }
    async createCategory(dto) {
        const category = this.categoryRepository.create(dto);
        return this.categoryRepository.save(category);
    }
    async deleteCategory(id) {
        const result = await this.categoryRepository.delete(id);
        if (result.affected === 0) {
            throw new common_1.NotFoundException('Categoria no encontrada');
        }
        return { success: true, message: 'Categoria eliminada exitosamente' };
    }
    async createBusiness(ownerId, dto) {
        const owner = await this.profileRepository.findOne({ where: { id: ownerId } });
        if (!owner) {
            throw new common_1.NotFoundException('Perfil de dueno no encontrado');
        }
        if (owner.role === profile_entity_1.UserRole.CLIENT) {
            owner.role = profile_entity_1.UserRole.BUSINESS;
            await this.profileRepository.save(owner);
        }
        const business = this.businessRepository.create({
            ...dto,
            ownerId,
        });
        const saved = await this.businessRepository.save(business);
        await this.notificationsService.broadcastToAdmins('Nuevo Negocio Registrado', `Se creo el negocio ${saved.name} por ${owner.fullName || 'un usuario'}.`, '/admin_businesses');
        return saved;
    }
    async findAll(activeOnly = true) {
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
    async findById(id) {
        const business = await this.businessRepository.findOne({
            where: { id },
            relations: ['categoryRef', 'owner'],
        });
        if (!business) {
            throw new common_1.NotFoundException('Negocio no encontrado');
        }
        return business;
    }
    async findByOwner(ownerId) {
        return this.businessRepository.find({
            where: { ownerId },
            relations: ['categoryRef'],
            order: { createdAt: 'DESC' },
        });
    }
    async updateBusiness(id, ownerId, role, dto) {
        const business = await this.findById(id);
        if (business.ownerId !== ownerId && role !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('Solo el dueno del negocio o un administrador pueden editarlo');
        }
        Object.assign(business, dto);
        return this.businessRepository.save(business);
    }
    async toggleStatus(id, isActive, role) {
        if (role !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('Solo los administradores pueden cambiar el estado del negocio');
        }
        const business = await this.findById(id);
        business.isActive = isActive;
        return this.businessRepository.save(business);
    }
    async getBusinessStats(businessId, ownerId, role) {
        const business = await this.findById(businessId);
        if (business.ownerId !== ownerId && role !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('No tienes permiso para ver las estadisticas de este negocio');
        }
        const [totalClients, totalScans, pendingScans, approvedScans, totalRewardsEarned, pendingRewards, claimedRewards,] = await Promise.all([
            this.cardRepository.count({ where: { businessId } }),
            this.scanRepository.count({ where: { businessId } }),
            this.scanRepository.count({ where: { businessId, status: scan_entity_1.ScanStatus.PENDING } }),
            this.scanRepository.count({ where: { businessId, status: scan_entity_1.ScanStatus.APPROVED } }),
            this.rewardRepository.count({ where: { businessId } }),
            this.rewardRepository.count({ where: { businessId, status: reward_entity_1.RewardStatus.PENDING } }),
            this.rewardRepository.count({ where: { businessId, status: reward_entity_1.RewardStatus.CLAIMED } }),
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
};
exports.BusinessesService = BusinessesService;
exports.BusinessesService = BusinessesService = BusinessesService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(business_entity_1.Business)),
    __param(1, (0, typeorm_1.InjectRepository)(business_category_entity_1.BusinessCategory)),
    __param(2, (0, typeorm_1.InjectRepository)(loyalty_card_entity_1.LoyaltyCard)),
    __param(3, (0, typeorm_1.InjectRepository)(scan_entity_1.Scan)),
    __param(4, (0, typeorm_1.InjectRepository)(reward_entity_1.Reward)),
    __param(5, (0, typeorm_1.InjectRepository)(profile_entity_1.Profile)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        notifications_service_1.NotificationsService])
], BusinessesService);
//# sourceMappingURL=businesses.service.js.map