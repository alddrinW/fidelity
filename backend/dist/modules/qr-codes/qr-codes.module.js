"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.QrCodesModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const qr_codes_service_1 = require("./qr-codes.service");
const qr_codes_controller_1 = require("./qr-codes.controller");
const qr_code_entity_1 = require("../../database/entities/qr-code.entity");
const business_entity_1 = require("../../database/entities/business.entity");
const scan_entity_1 = require("../../database/entities/scan.entity");
let QrCodesModule = class QrCodesModule {
};
exports.QrCodesModule = QrCodesModule;
exports.QrCodesModule = QrCodesModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([qr_code_entity_1.QrCode, business_entity_1.Business, scan_entity_1.Scan])],
        controllers: [qr_codes_controller_1.QrCodesController],
        providers: [qr_codes_service_1.QrCodesService],
        exports: [qr_codes_service_1.QrCodesService],
    })
], QrCodesModule);
//# sourceMappingURL=qr-codes.module.js.map