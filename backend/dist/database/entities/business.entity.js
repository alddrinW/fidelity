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
exports.Business = void 0;
const typeorm_1 = require("typeorm");
const profile_entity_1 = require("./profile.entity");
const business_category_entity_1 = require("./business-category.entity");
const loyalty_card_entity_1 = require("./loyalty-card.entity");
let Business = class Business {
};
exports.Business = Business;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Business.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'owner_id', type: 'uuid', nullable: false }),
    __metadata("design:type", String)
], Business.prototype, "ownerId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => profile_entity_1.Profile, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'owner_id' }),
    __metadata("design:type", profile_entity_1.Profile)
], Business.prototype, "owner", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'category_id', type: 'int', nullable: true }),
    __metadata("design:type", Number)
], Business.prototype, "categoryId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => business_category_entity_1.BusinessCategory, { nullable: true, onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'category_id' }),
    __metadata("design:type", business_category_entity_1.BusinessCategory)
], Business.prototype, "categoryRef", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 150, nullable: false }),
    __metadata("design:type", String)
], Business.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', nullable: true }),
    __metadata("design:type", String)
], Business.prototype, "description", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 100, nullable: true }),
    __metadata("design:type", String)
], Business.prototype, "category", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'logo_url', type: 'text', nullable: true }),
    __metadata("design:type", String)
], Business.prototype, "logoUrl", void 0);
__decorate([
    (0, typeorm_1.Column)({
        name: 'reward_description',
        type: 'text',
        default: 'Premio Fidelity por puntos completados',
    }),
    __metadata("design:type", String)
], Business.prototype, "rewardDescription", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'points_required', type: 'int', default: 10 }),
    __metadata("design:type", Number)
], Business.prototype, "pointsRequired", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'cooldown_hours', type: 'int', default: 24 }),
    __metadata("design:type", Number)
], Business.prototype, "cooldownHours", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_active', type: 'boolean', default: true }),
    __metadata("design:type", Boolean)
], Business.prototype, "isActive", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 10, scale: 7, nullable: true }),
    __metadata("design:type", Number)
], Business.prototype, "latitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'decimal', precision: 10, scale: 7, nullable: true }),
    __metadata("design:type", Number)
], Business.prototype, "longitude", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', nullable: true }),
    __metadata("design:type", String)
], Business.prototype, "address", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 50, nullable: true }),
    __metadata("design:type", String)
], Business.prototype, "phone", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => loyalty_card_entity_1.LoyaltyCard, (card) => card.business),
    __metadata("design:type", Array)
], Business.prototype, "loyaltyCards", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], Business.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ name: 'updated_at' }),
    __metadata("design:type", Date)
], Business.prototype, "updatedAt", void 0);
exports.Business = Business = __decorate([
    (0, typeorm_1.Entity)('businesses')
], Business);
//# sourceMappingURL=business.entity.js.map