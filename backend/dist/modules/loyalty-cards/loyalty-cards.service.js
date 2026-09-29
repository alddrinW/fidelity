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
var LoyaltyCardsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.LoyaltyCardsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const loyalty_card_entity_1 = require("../../database/entities/loyalty-card.entity");
const business_entity_1 = require("../../database/entities/business.entity");
const scan_entity_1 = require("../../database/entities/scan.entity");
const reward_entity_1 = require("../../database/entities/reward.entity");
const reward_transfer_history_entity_1 = require("../../database/entities/reward-transfer-history.entity");
const profile_entity_1 = require("../../database/entities/profile.entity");
let LoyaltyCardsService = LoyaltyCardsService_1 = class LoyaltyCardsService {
    constructor(cardRepository, businessRepository, scanRepository, rewardRepository, transferRepository) {
        this.cardRepository = cardRepository;
        this.businessRepository = businessRepository;
        this.scanRepository = scanRepository;
        this.rewardRepository = rewardRepository;
        this.transferRepository = transferRepository;
        this.logger = new common_1.Logger(LoyaltyCardsService_1.name);
    }
    async getOrCreateLoyaltyCard(userId, businessId) {
        const existing = await this.cardRepository.findOne({
            where: { userId, businessId },
            relations: ['business', 'business.categoryRef'],
        });
        if (existing) {
            return existing;
        }
        const business = await this.businessRepository.findOne({ where: { id: businessId } });
        if (!business) {
            throw new common_1.NotFoundException('Negocio no encontrado');
        }
        const newCard = this.cardRepository.create({
            userId,
            businessId,
            currentPoints: 0,
            totalPointsLifetime: 0,
            rewardsClaimed: 0,
            lastScanAt: null,
        });
        return this.cardRepository.save(newCard);
    }
    async getUserCards(userId) {
        return this.cardRepository.find({
            where: { userId },
            relations: ['business', 'business.categoryRef'],
            order: { updatedAt: 'DESC' },
        });
    }
    async getBusinessCards(businessId, ownerId, role) {
        const business = await this.businessRepository.findOne({ where: { id: businessId } });
        if (!business) {
            throw new common_1.NotFoundException('Negocio no encontrado');
        }
        if (business.ownerId !== ownerId && role !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('No tienes permiso para ver los clientes de este negocio');
        }
        return this.cardRepository.find({
            where: { businessId },
            relations: ['user'],
            order: { updatedAt: 'DESC' },
        });
    }
    async getCardHistory(cardId, userId, role) {
        const card = await this.cardRepository.findOne({
            where: { id: cardId },
            relations: ['business', 'user'],
        });
        if (!card) {
            throw new common_1.NotFoundException('Tarjeta de fidelizacion no encontrada');
        }
        if (card.userId !== userId && card.business.ownerId !== userId && role !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('No tienes permiso para ver el historial de esta tarjeta');
        }
        const [scans, rewards, transfers] = await Promise.all([
            this.scanRepository.find({
                where: { loyaltyCardId: cardId },
                order: { scannedAt: 'DESC' },
                take: 50,
            }),
            this.rewardRepository.find({
                where: { loyaltyCardId: cardId },
                order: { earnedAt: 'DESC' },
                take: 50,
            }),
            this.transferRepository.find({
                where: { businessId: card.businessId },
                relations: ['fromUser', 'toUser', 'reward'],
                order: { transferredAt: 'DESC' },
                take: 50,
            }),
        ]);
        return {
            card,
            scans,
            rewards,
            transfers,
        };
    }
};
exports.LoyaltyCardsService = LoyaltyCardsService;
exports.LoyaltyCardsService = LoyaltyCardsService = LoyaltyCardsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(loyalty_card_entity_1.LoyaltyCard)),
    __param(1, (0, typeorm_1.InjectRepository)(business_entity_1.Business)),
    __param(2, (0, typeorm_1.InjectRepository)(scan_entity_1.Scan)),
    __param(3, (0, typeorm_1.InjectRepository)(reward_entity_1.Reward)),
    __param(4, (0, typeorm_1.InjectRepository)(reward_transfer_history_entity_1.RewardTransferHistory)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], LoyaltyCardsService);
//# sourceMappingURL=loyalty-cards.service.js.map