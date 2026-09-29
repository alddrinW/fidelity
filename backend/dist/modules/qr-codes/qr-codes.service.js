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
var QrCodesService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.QrCodesService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const uuid_1 = require("uuid");
const qr_code_entity_1 = require("../../database/entities/qr-code.entity");
const business_entity_1 = require("../../database/entities/business.entity");
const scan_entity_1 = require("../../database/entities/scan.entity");
const profile_entity_1 = require("../../database/entities/profile.entity");
let QrCodesService = QrCodesService_1 = class QrCodesService {
    constructor(qrRepository, businessRepository, scanRepository) {
        this.qrRepository = qrRepository;
        this.businessRepository = businessRepository;
        this.scanRepository = scanRepository;
        this.logger = new common_1.Logger(QrCodesService_1.name);
    }
    async createQrCode(callerId, callerRole, dto) {
        const business = await this.businessRepository.findOne({ where: { id: dto.businessId } });
        if (!business)
            throw new common_1.NotFoundException('Negocio no encontrado');
        if (business.ownerId !== callerId && callerRole !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('Solo el dueno del negocio puede generar codigos QR');
        }
        const qrToken = dto.qrCode || `FID-${dto.businessId.substring(0, 8)}-${(0, uuid_1.v4)().substring(0, 8)}`.toUpperCase();
        const qr = this.qrRepository.create({
            businessId: dto.businessId,
            qrCode: qrToken,
            label: dto.label || 'Mostrador Principal',
            isActive: true,
        });
        return this.qrRepository.save(qr);
    }
    async getBusinessQrCodes(businessId, callerId, callerRole) {
        const business = await this.businessRepository.findOne({ where: { id: businessId } });
        if (!business)
            throw new common_1.NotFoundException('Negocio no encontrado');
        if (business.ownerId !== callerId && callerRole !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('No autorizado para ver los codigos QR de este negocio');
        }
        return this.qrRepository.find({
            where: { businessId },
            order: { createdAt: 'DESC' },
        });
    }
    async toggleQrCode(qrId, callerId, callerRole, dto) {
        const qr = await this.qrRepository.findOne({
            where: { id: qrId },
            relations: ['business'],
        });
        if (!qr)
            throw new common_1.NotFoundException('Codigo QR no encontrado');
        if (qr.business.ownerId !== callerId && callerRole !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('No autorizado para modificar este codigo QR');
        }
        qr.isActive = dto.isActive;
        return this.qrRepository.save(qr);
    }
    async updateQrCode(qrId, callerId, callerRole, dto) {
        const qr = await this.qrRepository.findOne({
            where: { id: qrId },
            relations: ['business'],
        });
        if (!qr)
            throw new common_1.NotFoundException('Codigo QR no encontrado');
        if (qr.business.ownerId !== callerId && callerRole !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('No autorizado para modificar este codigo QR');
        }
        if (dto.qrCode !== undefined)
            qr.qrCode = dto.qrCode;
        if (dto.label !== undefined)
            qr.label = dto.label;
        if (dto.isActive !== undefined)
            qr.isActive = dto.isActive;
        return this.qrRepository.save(qr);
    }
    async getQrStats(qrId, callerId, callerRole) {
        const qr = await this.qrRepository.findOne({
            where: { id: qrId },
            relations: ['business'],
        });
        if (!qr)
            throw new common_1.NotFoundException('Codigo QR no encontrado');
        if (qr.business.ownerId !== callerId && callerRole !== profile_entity_1.UserRole.ADMIN) {
            throw new common_1.ForbiddenException('No autorizado para ver metricas');
        }
        const totalScans = await this.scanRepository.count({ where: { qrCodeId: qrId } });
        return {
            qrId: qr.id,
            qrCode: qr.qrCode,
            label: qr.label,
            isActive: qr.isActive,
            totalScans,
        };
    }
};
exports.QrCodesService = QrCodesService;
exports.QrCodesService = QrCodesService = QrCodesService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(qr_code_entity_1.QrCode)),
    __param(1, (0, typeorm_1.InjectRepository)(business_entity_1.Business)),
    __param(2, (0, typeorm_1.InjectRepository)(scan_entity_1.Scan)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], QrCodesService);
//# sourceMappingURL=qr-codes.service.js.map