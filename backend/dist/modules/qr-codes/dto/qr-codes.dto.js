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
exports.UpdateQrCodeDto = exports.ToggleQrCodeDto = exports.CreateQrCodeDto = void 0;
const class_validator_1 = require("class-validator");
class CreateQrCodeDto {
}
exports.CreateQrCodeDto = CreateQrCodeDto;
__decorate([
    (0, class_validator_1.IsUUID)('4', { message: 'El ID de negocio debe ser un UUID valido' }),
    __metadata("design:type", String)
], CreateQrCodeDto.prototype, "businessId", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], CreateQrCodeDto.prototype, "label", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], CreateQrCodeDto.prototype, "qrCode", void 0);
class ToggleQrCodeDto {
}
exports.ToggleQrCodeDto = ToggleQrCodeDto;
__decorate([
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], ToggleQrCodeDto.prototype, "isActive", void 0);
class UpdateQrCodeDto {
}
exports.UpdateQrCodeDto = UpdateQrCodeDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], UpdateQrCodeDto.prototype, "qrCode", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], UpdateQrCodeDto.prototype, "label", void 0);
__decorate([
    (0, class_validator_1.IsBoolean)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", Boolean)
], UpdateQrCodeDto.prototype, "isActive", void 0);
//# sourceMappingURL=qr-codes.dto.js.map