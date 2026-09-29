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
exports.QrCodesController = void 0;
const common_1 = require("@nestjs/common");
const qr_codes_service_1 = require("./qr-codes.service");
const qr_codes_dto_1 = require("./dto/qr-codes.dto");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const roles_guard_1 = require("../../common/guards/roles.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
const current_user_decorator_1 = require("../../common/decorators/current-user.decorator");
const profile_entity_1 = require("../../database/entities/profile.entity");
let QrCodesController = class QrCodesController {
    constructor(qrService) {
        this.qrService = qrService;
    }
    async createQrCode(user, dto) {
        return this.qrService.createQrCode(user.id, user.role, dto);
    }
    async getBusinessQrCodes(user, businessId) {
        return this.qrService.getBusinessQrCodes(businessId, user.id, user.role);
    }
    async updateQrCode(user, qrId, dto) {
        return this.qrService.updateQrCode(qrId, user.id, user.role, dto);
    }
    async toggleQrCode(user, qrId, dto) {
        return this.qrService.toggleQrCode(qrId, user.id, user.role, dto);
    }
    async getQrStats(user, qrId) {
        return this.qrService.getQrStats(qrId, user.id, user.role);
    }
};
exports.QrCodesController = QrCodesController;
__decorate([
    (0, common_1.Post)(),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, qr_codes_dto_1.CreateQrCodeDto]),
    __metadata("design:returntype", Promise)
], QrCodesController.prototype, "createQrCode", null);
__decorate([
    (0, common_1.Get)('business/:businessId'),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('businessId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], QrCodesController.prototype, "getBusinessQrCodes", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, qr_codes_dto_1.UpdateQrCodeDto]),
    __metadata("design:returntype", Promise)
], QrCodesController.prototype, "updateQrCode", null);
__decorate([
    (0, common_1.Patch)(':id/status'),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, qr_codes_dto_1.ToggleQrCodeDto]),
    __metadata("design:returntype", Promise)
], QrCodesController.prototype, "toggleQrCode", null);
__decorate([
    (0, common_1.Get)(':id/stats'),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], QrCodesController.prototype, "getQrStats", null);
exports.QrCodesController = QrCodesController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, common_1.Controller)('qr-codes'),
    __metadata("design:paramtypes", [qr_codes_service_1.QrCodesService])
], QrCodesController);
//# sourceMappingURL=qr-codes.controller.js.map