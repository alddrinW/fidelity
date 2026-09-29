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
exports.BusinessesController = void 0;
const common_1 = require("@nestjs/common");
const businesses_service_1 = require("./businesses.service");
const businesses_dto_1 = require("./dto/businesses.dto");
const jwt_auth_guard_1 = require("../../common/guards/jwt-auth.guard");
const roles_guard_1 = require("../../common/guards/roles.guard");
const roles_decorator_1 = require("../../common/decorators/roles.decorator");
const public_decorator_1 = require("../../common/decorators/public.decorator");
const current_user_decorator_1 = require("../../common/decorators/current-user.decorator");
const profile_entity_1 = require("../../database/entities/profile.entity");
let BusinessesController = class BusinessesController {
    constructor(businessesService) {
        this.businessesService = businessesService;
    }
    async getCategories() {
        return this.businessesService.getCategories();
    }
    async createCategory(dto) {
        return this.businessesService.createCategory(dto);
    }
    async deleteCategory(id) {
        return this.businessesService.deleteCategory(parseInt(id, 10));
    }
    async getBusinesses(all) {
        const activeOnly = all !== 'true';
        return this.businessesService.findAll(activeOnly);
    }
    async getMyBusinesses(user) {
        return this.businessesService.findByOwner(user.id);
    }
    async getBusinessById(id) {
        return this.businessesService.findById(id);
    }
    async createBusiness(user, dto) {
        return this.businessesService.createBusiness(user.id, dto);
    }
    async updateBusiness(user, id, dto) {
        return this.businessesService.updateBusiness(id, user.id, user.role, dto);
    }
    async toggleStatus(user, id, dto) {
        return this.businessesService.toggleStatus(id, dto.isActive, user.role);
    }
    async getStats(user, id) {
        return this.businessesService.getBusinessStats(id, user.id, user.role);
    }
};
exports.BusinessesController = BusinessesController;
__decorate([
    (0, public_decorator_1.Public)(),
    (0, common_1.Get)('categories'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], BusinessesController.prototype, "getCategories", null);
__decorate([
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.ADMIN),
    (0, common_1.Post)('categories'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [businesses_dto_1.CreateCategoryDto]),
    __metadata("design:returntype", Promise)
], BusinessesController.prototype, "createCategory", null);
__decorate([
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.ADMIN),
    (0, common_1.Delete)('categories/:id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], BusinessesController.prototype, "deleteCategory", null);
__decorate([
    (0, public_decorator_1.Public)(),
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('all')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], BusinessesController.prototype, "getBusinesses", null);
__decorate([
    (0, common_1.Get)('my-businesses'),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], BusinessesController.prototype, "getMyBusinesses", null);
__decorate([
    (0, public_decorator_1.Public)(),
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], BusinessesController.prototype, "getBusinessById", null);
__decorate([
    (0, common_1.Post)(),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.CLIENT, profile_entity_1.UserRole.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, businesses_dto_1.CreateBusinessDto]),
    __metadata("design:returntype", Promise)
], BusinessesController.prototype, "createBusiness", null);
__decorate([
    (0, common_1.Put)(':id'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, businesses_dto_1.UpdateBusinessDto]),
    __metadata("design:returntype", Promise)
], BusinessesController.prototype, "updateBusiness", null);
__decorate([
    (0, common_1.Patch)(':id/status'),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, businesses_dto_1.ToggleBusinessStatusDto]),
    __metadata("design:returntype", Promise)
], BusinessesController.prototype, "toggleStatus", null);
__decorate([
    (0, common_1.Get)(':id/stats'),
    (0, roles_decorator_1.Roles)(profile_entity_1.UserRole.BUSINESS, profile_entity_1.UserRole.ADMIN),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], BusinessesController.prototype, "getStats", null);
exports.BusinessesController = BusinessesController = __decorate([
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, common_1.Controller)('businesses'),
    __metadata("design:paramtypes", [businesses_service_1.BusinessesService])
], BusinessesController);
//# sourceMappingURL=businesses.controller.js.map