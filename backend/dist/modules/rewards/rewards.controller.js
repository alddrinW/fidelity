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
Object.defineProperty(exports, "__esModule", { value: true });
exports.RewardsController = void 0;
const common_1 = require("@nestjs/common");
const rewards_service_1 = require("./rewards.service");
const rewards_dto_1 = require("./dto/rewards.dto");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const current_user_decorator_1 = require("../../common/decorators/current-user.decorator");
const reward_entity_1 = require("../../database/entities/reward.entity");
const roles_guard_1 = require("../../common/guards/roles.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
const profile_entity_1 = require("../../database/entities/profile.entity");
let RewardsController = class RewardsController {
    constructor(rewardsService) {
        this.rewardsService = rewardsService;
    }
    async getMyRewards(user, status) {
        return this.rewardsService.getUserRewards(user.id, status);
    }
    async getBusinessRewards(user, businessId, status) {
        return this.rewardsService.getBusinessRewards(businessId, user.id, user.role, status);
    }
    async updateRewardStatus(user, rewardId, dto) {
        return this.rewardsService.updateRewardStatus(rewardId, user.id, user.role, dto);
    }
    async transferReward(user, dto) {
        return this.rewardsService.transferReward(user.id, dto);
    }
    async getTransfers(businessId) {
        return this.rewardsService.getTransferHistory(businessId);
    }
};
exports.RewardsController = RewardsController;
__decorate([
    (0, common_1.Get)('my-rewards'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Query)('status')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], RewardsController.prototype, "getMyRewards", null);
__decorate([
    (0, common_1.Get)('business/:businessId'),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('businessId')),
    __param(2, (0, common_1.Query)('status')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String]),
    __metadata("design:returntype", Promise)
], RewardsController.prototype, "getBusinessRewards", null);
__decorate([
    (0, common_1.Patch)(':id/status'),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, rewards_dto_1.UpdateRewardStatusDto]),
    __metadata("design:returntype", Promise)
], RewardsController.prototype, "updateRewardStatus", null);
__decorate([
    (0, common_1.Post)('transfer'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, rewards_dto_1.TransferRewardDto]),
    __metadata("design:returntype", Promise)
], RewardsController.prototype, "transferReward", null);
__decorate([
    (0, common_1.Get)('transfers'),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.ADMIN),
    __param(0, (0, common_1.Query)('businessId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], RewardsController.prototype, "getTransfers", null);
exports.RewardsController = RewardsController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, common_1.Controller)('rewards'),
    __metadata("design:paramtypes", [rewards_service_1.RewardsService])
], RewardsController);
//# sourceMappingURL=rewards.controller.js.map