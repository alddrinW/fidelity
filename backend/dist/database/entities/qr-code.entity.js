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
exports.QrCode = void 0;
const typeorm_1 = require("typeorm");
const business_entity_1 = require("./business.entity");
let QrCode = class QrCode {
};
exports.QrCode = QrCode;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], QrCode.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'business_id', type: 'uuid', nullable: false }),
    __metadata("design:type", String)
], QrCode.prototype, "businessId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => business_entity_1.Business, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'business_id' }),
    __metadata("design:type", business_entity_1.Business)
], QrCode.prototype, "business", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'qr_code', type: 'varchar', length: 255, unique: true, nullable: false }),
    __metadata("design:type", String)
], QrCode.prototype, "qrCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 100, nullable: true }),
    __metadata("design:type", String)
], QrCode.prototype, "label", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_active', type: 'boolean', default: true }),
    __metadata("design:type", Boolean)
], QrCode.prototype, "isActive", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], QrCode.prototype, "createdAt", void 0);
exports.QrCode = QrCode = __decorate([
    (0, typeorm_1.Entity)('qr_codes')
], QrCode);
//# sourceMappingURL=qr-code.entity.js.map