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
exports.LoyaltyCardsController = void 0;
const common_1 = require("@nestjs/common");
const loyalty_cards_service_1 = require("./loyalty-cards.service");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const current_user_decorator_1 = require("../../common/decorators/current-user.decorator");
let LoyaltyCardsController = class LoyaltyCardsController {
    constructor(cardsService) {
        this.cardsService = cardsService;
    }
    async getMyCards(user) {
        return this.cardsService.getUserCards(user.id);
    }
    async getOrCreateCard(user, businessId) {
        return this.cardsService.getOrCreateLoyaltyCard(user.id, businessId);
    }
    async getBusinessCards(user, businessId) {
        return this.cardsService.getBusinessCards(businessId, user.id, user.role);
    }
    async getCardHistory(user, cardId) {
        return this.cardsService.getCardHistory(cardId, user.id, user.role);
    }
};
exports.LoyaltyCardsController = LoyaltyCardsController;
__decorate([
    (0, common_1.Get)('my-cards'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], LoyaltyCardsController.prototype, "getMyCards", null);
__decorate([
    (0, common_1.Post)('get-or-create/:businessId'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('businessId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], LoyaltyCardsController.prototype, "getOrCreateCard", null);
__decorate([
    (0, common_1.Get)('business/:businessId'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('businessId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], LoyaltyCardsController.prototype, "getBusinessCards", null);
__decorate([
    (0, common_1.Get)(':id/history'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], LoyaltyCardsController.prototype, "getCardHistory", null);
exports.LoyaltyCardsController = LoyaltyCardsController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('loyalty-cards'),
    __metadata("design:paramtypes", [loyalty_cards_service_1.LoyaltyCardsService])
], LoyaltyCardsController);
//# sourceMappingURL=loyalty-cards.controller.js.map