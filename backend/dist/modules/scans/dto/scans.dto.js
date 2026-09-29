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
exports.UpdateScanStatusDto = exports.AddManualPointsDto = exports.ValidateScanDto = void 0;
const class_validator_1 = require("class-validator");
const scan_entity_1 = require("../../../database/entities/scan.entity");
class ValidateScanDto {
}
exports.ValidateScanDto = ValidateScanDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)({ message: 'El codigo QR es requerido' }),
    __metadata("design:type", String)
], ValidateScanDto.prototype, "qr_code", void 0);
class AddManualPointsDto {
}
exports.AddManualPointsDto = AddManualPointsDto;
__decorate([
    (0, class_validator_1.IsUUID)('4', { message: 'El ID de usuario debe ser un UUID valido' }),
    __metadata("design:type", String)
], AddManualPointsDto.prototype, "userId", void 0);
__decorate([
    (0, class_validator_1.IsUUID)('4', { message: 'El ID de negocio debe ser un UUID valido' }),
    __metadata("design:type", String)
], AddManualPointsDto.prototype, "businessId", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(1, { message: 'Los puntos asignados deben ser mayores a 0' }),
    __metadata("design:type", Number)
], AddManualPointsDto.prototype, "points", void 0);
class UpdateScanStatusDto {
}
exports.UpdateScanStatusDto = UpdateScanStatusDto;
__decorate([
    (0, class_validator_1.IsEnum)(scan_entity_1.ScanStatus, { message: 'El estado debe ser pending, approved o rejected' }),
    __metadata("design:type", String)
], UpdateScanStatusDto.prototype, "status", void 0);
//# sourceMappingURL=scans.dto.js.map