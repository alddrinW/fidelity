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
exports.RewardTransferHistory = void 0;
const typeorm_1 = require("typeorm");
const profile_entity_1 = require("./profile.entity");
const business_entity_1 = require("./business.entity");
const reward_entity_1 = require("./reward.entity");
let RewardTransferHistory = class RewardTransferHistory {
};
exports.RewardTransferHistory = RewardTransferHistory;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], RewardTransferHistory.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'reward_id', type: 'uuid', nullable: false }),
    __metadata("design:type", String)
], RewardTransferHistory.prototype, "rewardId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => reward_entity_1.Reward, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'reward_id' }),
    __metadata("design:type", reward_entity_1.Reward)
], RewardTransferHistory.prototype, "reward", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'business_id', type: 'uuid', nullable: false }),
    __metadata("design:type", String)
], RewardTransferHistory.prototype, "businessId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => business_entity_1.Business, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'business_id' }),
    __metadata("design:type", business_entity_1.Business)
], RewardTransferHistory.prototype, "business", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'from_user_id', type: 'uuid', nullable: false }),
    __metadata("design:type", String)
], RewardTransferHistory.prototype, "fromUserId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => profile_entity_1.Profile, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'from_user_id' }),
    __metadata("design:type", profile_entity_1.Profile)
], RewardTransferHistory.prototype, "fromUser", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'to_user_id', type: 'uuid', nullable: false }),
    __metadata("design:type", String)
], RewardTransferHistory.prototype, "toUserId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => profile_entity_1.Profile, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'to_user_id' }),
    __metadata("design:type", profile_entity_1.Profile)
], RewardTransferHistory.prototype, "toUser", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'transferred_at' }),
    __metadata("design:type", Date)
], RewardTransferHistory.prototype, "transferredAt", void 0);
exports.RewardTransferHistory = RewardTransferHistory = __decorate([
    (0, typeorm_1.Entity)('reward_transfer_history')
], RewardTransferHistory);
//# sourceMappingURL=reward-transfer-history.entity.js.map