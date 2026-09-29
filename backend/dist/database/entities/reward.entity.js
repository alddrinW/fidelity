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
Object.defineProperty(exports, "__esModule", { value: true });
exports.Reward = exports.RewardStatus = void 0;
const typeorm_1 = require("typeorm");
const profile_entity_1 = require("./profile.entity");
const business_entity_1 = require("./business.entity");
const loyalty_card_entity_1 = require("./loyalty-card.entity");
var RewardStatus;
(function (RewardStatus) {
    RewardStatus["PENDING"] = "pending";
    RewardStatus["APPROVED"] = "approved";
    RewardStatus["CLAIMED"] = "claimed";
    RewardStatus["REJECTED"] = "rejected";
})(RewardStatus || (exports.RewardStatus = RewardStatus = {}));
let Reward = class Reward {
};
exports.Reward = Reward;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Reward.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_id', type: 'uuid', nullable: false }),
    __metadata("design:type", String)
], Reward.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => profile_entity_1.Profile, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'user_id' }),
    __metadata("design:type", profile_entity_1.Profile)
], Reward.prototype, "user", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'business_id', type: 'uuid', nullable: false }),
    __metadata("design:type", String)
], Reward.prototype, "businessId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => business_entity_1.Business, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'business_id' }),
    __metadata("design:type", business_entity_1.Business)
], Reward.prototype, "business", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'loyalty_card_id', type: 'uuid', nullable: false }),
    __metadata("design:type", String)
], Reward.prototype, "loyaltyCardId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => loyalty_card_entity_1.LoyaltyCard, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'loyalty_card_id' }),
    __metadata("design:type", loyalty_card_entity_1.LoyaltyCard)
], Reward.prototype, "loyaltyCard", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reward_description', type: 'text', nullable: true }),
    __metadata("design:type", String)
], Reward.prototype, "rewardDescription", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'description', type: 'text', nullable: true }),
    __metadata("design:type", String)
], Reward.prototype, "description", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'points_used', type: 'int', default: 10 }),
    __metadata("design:type", Number)
], Reward.prototype, "pointsUsed", void 0);
__decorate([
    (0, typeorm_1.Column)({
        type: 'varchar',
        length: 20,
        default: RewardStatus.PENDING,
    }),
    __metadata("design:type", String)
], Reward.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_demo', type: 'boolean', default: false }),
    __metadata("design:type", Boolean)
], Reward.prototype, "isDemo", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'earned_at' }),
    __metadata("design:type", Date)
], Reward.prototype, "earnedAt", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'claimed_at', type: 'timestamp with time zone', nullable: true }),
    __metadata("design:type", Date)
], Reward.prototype, "claimedAt", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], Reward.prototype, "createdAt", void 0);
exports.Reward = Reward = __decorate([
    (0, typeorm_1.Entity)('rewards')
], Reward);
//# sourceMappingURL=reward.entity.js.map