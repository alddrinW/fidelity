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
exports.ScansController = void 0;
const common_1 = require("@nestjs/common");
const scans_service_1 = require("./scans.service");
const scans_dto_1 = require("./dto/scans.dto");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const current_user_decorator_1 = require("../../common/decorators/current-user.decorator");
const scan_entity_1 = require("../../database/entities/scan.entity");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
const roles_guard_1 = require("../../common/guards/roles.guard");
const profile_entity_1 = require("../../database/entities/profile.entity");
let ScansController = class ScansController {
    constructor(scansService) {
        this.scansService = scansService;
    }
    async validateScan(user, dto) {
        return this.scansService.validateScan(user.id, dto);
    }
    async addManualPoints(user, dto) {
        return this.scansService.addManualPoints(user.id, user.role, dto);
    }
    async getBusinessScans(user, businessId, status) {
        return this.scansService.getBusinessScans(businessId, user.id, user.role, status);
    }
    async updateScanStatus(user, scanId, dto) {
        return this.scansService.updateScanStatus(scanId, user.id, user.role, dto);
    }
};
exports.ScansController = ScansController;
__decorate([
    (0, common_1.Post)('validate'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, scans_dto_1.ValidateScanDto]),
    __metadata("design:returntype", Promise)
], ScansController.prototype, "validateScan", null);
__decorate([
    (0, common_1.Post)('manual-points'),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.ADMIN),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, scans_dto_1.AddManualPointsDto]),
    __metadata("design:returntype", Promise)
], ScansController.prototype, "addManualPoints", null);
__decorate([
    (0, common_1.Get)('business/:businessId'),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('businessId')),
    __param(2, (0, common_1.Query)('status')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String]),
    __metadata("design:returntype", Promise)
], ScansController.prototype, "getBusinessScans", null);
__decorate([
    (0, common_1.Patch)(':id/status'),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, scans_dto_1.UpdateScanStatusDto]),
    __metadata("design:returntype", Promise)
], ScansController.prototype, "updateScanStatus", null);
exports.ScansController = ScansController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, common_1.Controller)('scans'),
    __metadata("design:paramtypes", [scans_service_1.ScansService])
], ScansController);
//# sourceMappingURL=scans.controller.js.map