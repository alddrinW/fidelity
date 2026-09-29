"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ScansModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const scans_service_1 = require("./scans.service");
const scans_controller_1 = require("./scans.controller");
const scan_entity_1 = require("../../database/entities/scan.entity");
const scan_attempt_entity_1 = require("../../database/entities/scan-attempt.entity");
const qr_code_entity_1 = require("../../database/entities/qr-code.entity");
const business_entity_1 = require("../../database/entities/business.entity");
const loyalty_card_entity_1 = require("../../database/entities/loyalty-card.entity");
const reward_entity_1 = require("../../database/entities/reward.entity");
const profile_entity_1 = require("../../database/entities/profile.entity");
let ScansModule = class ScansModule {
};
exports.ScansModule = ScansModule;
exports.ScansModule = ScansModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                scan_entity_1.Scan,
                scan_attempt_entity_1.ScanAttempt,
                qr_code_entity_1.QrCode,
                business_entity_1.Business,
                loyalty_card_entity_1.LoyaltyCard,
                reward_entity_1.Reward,
                profile_entity_1.Profile,
            ]),
        ],
        controllers: [scans_controller_1.ScansController],
        providers: [scans_service_1.ScansService],
        exports: [scans_service_1.ScansService],
    })
], ScansModule);
//# sourceMappingURL=scans.module.js.map