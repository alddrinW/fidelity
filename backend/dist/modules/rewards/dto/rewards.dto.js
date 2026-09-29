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
exports.TransferRewardDto = exports.UpdateRewardStatusDto = void 0;
const class_validator_1 = require("class-validator");
const reward_entity_1 = require("../../../database/entities/reward.entity");
class UpdateRewardStatusDto {
}
exports.UpdateRewardStatusDto = UpdateRewardStatusDto;
__decorate([
    (0, class_validator_1.IsEnum)(reward_entity_1.RewardStatus, { message: 'El estado debe ser pending, approved, claimed o rejected' }),
    __metadata("design:type", String)
], UpdateRewardStatusDto.prototype, "status", void 0);
class TransferRewardDto {
}
exports.TransferRewardDto = TransferRewardDto;
__decorate([
    (0, class_validator_1.IsUUID)('4', { message: 'El ID del premio debe ser un UUID valido' }),
    __metadata("design:type", String)
], TransferRewardDto.prototype, "rewardId", void 0);
__decorate([
    (0, class_validator_1.IsUUID)('4', { message: 'El ID del destinatario debe ser un UUID valido' }),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], TransferRewardDto.prototype, "toUserId", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", String)
], TransferRewardDto.prototype, "toEmail", void 0);
//# sourceMappingURL=rewards.dto.js.map