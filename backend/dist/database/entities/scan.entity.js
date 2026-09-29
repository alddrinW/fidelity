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
exports.Scan = exports.ScanStatus = void 0;
const typeorm_1 = require("typeorm");
const profile_entity_1 = require("./profile.entity");
const business_entity_1 = require("./business.entity");
const loyalty_card_entity_1 = require("./loyalty-card.entity");
const qr_code_entity_1 = require("./qr-code.entity");
var ScanStatus;
(function (ScanStatus) {
    ScanStatus["PENDING"] = "pending";
    ScanStatus["APPROVED"] = "approved";
    ScanStatus["REJECTED"] = "rejected";
})(ScanStatus || (exports.ScanStatus = ScanStatus = {}));
let Scan = class Scan {
};
exports.Scan = Scan;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Scan.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'user_id', type: 'uuid', nullable: false }),
    __metadata("design:type", String)
], Scan.prototype, "userId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => profile_entity_1.Profile, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'user_id' }),
    __metadata("design:type", profile_entity_1.Profile)
], Scan.prototype, "user", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'business_id', type: 'uuid', nullable: false }),
    __metadata("design:type", String)
], Scan.prototype, "businessId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => business_entity_1.Business, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'business_id' }),
    __metadata("design:type", business_entity_1.Business)
], Scan.prototype, "business", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'loyalty_card_id', type: 'uuid', nullable: false }),
    __metadata("design:type", String)
], Scan.prototype, "loyaltyCardId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => loyalty_card_entity_1.LoyaltyCard, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'loyalty_card_id' }),
    __metadata("design:type", loyalty_card_entity_1.LoyaltyCard)
], Scan.prototype, "loyaltyCard", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'qr_code_id', type: 'uuid', nullable: true }),
    __metadata("design:type", String)
], Scan.prototype, "qrCodeId", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => qr_code_entity_1.QrCode, { nullable: true, onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'qr_code_id' }),
    __metadata("design:type", qr_code_entity_1.QrCode)
], Scan.prototype, "qrCode", void 0);
__decorate([
    (0, typeorm_1.Column)({
        type: 'varchar',
        length: 20,
        default: ScanStatus.APPROVED,
    }),
    __metadata("design:type", String)
], Scan.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_demo', type: 'boolean', default: false }),
    __metadata("design:type", Boolean)
], Scan.prototype, "isDemo", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'scanned_at' }),
    __metadata("design:type", Date)
], Scan.prototype, "scannedAt", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ name: 'created_at' }),
    __metadata("design:type", Date)
], Scan.prototype, "createdAt", void 0);
exports.Scan = Scan = __decorate([
    (0, typeorm_1.Entity)('scans')
], Scan);
//# sourceMappingURL=scan.entity.js.map