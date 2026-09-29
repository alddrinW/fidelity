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
exports.ScanAttempt = void 0;
const typeorm_1 = require("typeorm");
const profile_entity_1 = require("./profile.entity");
const business_entity_1 = require("./business.entity");
const qr_code_entity_1 = require("./qr-code.entity");
let ScanAttempt = class ScanAttempt {
};
exports.ScanAttempt = ScanAttempt;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], ScanAttempt.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_id', type: 'uuid', nullable: false }),
    __metadata("design:type", String)
], ScanAttempt.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => profile_entity_1.Profile, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'user_id' }),
    __metadata("design:type", profile_entity_1.Profile)
], ScanAttempt.prototype, "user", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'business_id', type: 'uuid', nullable: true }),
    __metadata("design:type", String)
], ScanAttempt.prototype, "businessId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => business_entity_1.Business, { nullable: true, onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'business_id' }),
    __metadata("design:type", business_entity_1.Business)
], ScanAttempt.prototype, "business", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'qr_code_id', type: 'uuid', nullable: true }),
    __metadata("design:type", String)
], ScanAttempt.prototype, "qrCodeId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => qr_code_entity_1.QrCode, { nullable: true, onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'qr_code_id' }),
    __metadata("design:type", qr_code_entity_1.QrCode)
], ScanAttempt.prototype, "qrCode", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'boolean', default: false }),
    __metadata("design:type", Boolean)
], ScanAttempt.prototype, "success", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'failure_reason', type: 'varchar', length: 100, nullable: true }),
    __metadata("design:type", String)
], ScanAttempt.prototype, "failureReason", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], ScanAttempt.prototype, "createdAt", void 0);
exports.ScanAttempt = ScanAttempt = __decorate([
    (0, typeorm_1.Entity)('scan_attempts')
], ScanAttempt);
//# sourceMappingURL=scan-attempt.entity.js.map