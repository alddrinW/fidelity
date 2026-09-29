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
var AuthService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const jwt_1 = require("@nestjs/jwt");
const bcrypt = require("bcrypt");
const profile_entity_1 = require("../../database/entities/profile.entity");
const notifications_service_1 = require("../notifications/notifications.service");
let AuthService = AuthService_1 = class AuthService {
    constructor(profileRepository, jwtService, notificationsService) {
        this.profileRepository = profileRepository;
        this.jwtService = jwtService;
        this.notificationsService = notificationsService;
        this.logger = new common_1.Logger(AuthService_1.name);
    }
    async register(dto) {
        const existing = await this.profileRepository.findOne({
            where: { email: dto.email.toLowerCase().trim() },
        });
        if (existing) {
            throw new common_1.ConflictException('El correo electronico ya esta registrado');
        }
        let roleToAssign = dto.role || profile_entity_1.UserRole.CLIENT;
        if (roleToAssign === profile_entity_1.UserRole.ADMIN) {
            roleToAssign = profile_entity_1.UserRole.CLIENT;
        }
        const salt = await bcrypt.genSalt(10);
        const passwordHash = await bcrypt.hash(dto.password, salt);
        const profile = this.profileRepository.create({
            email: dto.email.toLowerCase().trim(),
            fullName: dto.fullName.trim(),
            role: roleToAssign,
            passwordHash,
            phone: dto.phone || null,
            avatarUrl: dto.avatarUrl || null,
            fcmToken: dto.fcmToken || null,
            isDemo: dto.isDemo ?? false,
        });
        const savedProfile = await this.profileRepository.save(profile);
        const notificationTitle = roleToAssign === profile_entity_1.UserRole.BUSINESS ? 'Nueva Cuenta de Negocio' : 'Nuevo Cliente';
        const notificationBody = `${savedProfile.fullName} creo cuenta como ${roleToAssign}.`;
        await this.notificationsService.broadcastToAdmins(notificationTitle, notificationBody, '/admin_users');
        const token = this.generateToken(savedProfile);
        return {
            user: {
                id: savedProfile.id,
                email: savedProfile.email,
                fullName: savedProfile.fullName,
                role: savedProfile.role,
                avatarUrl: savedProfile.avatarUrl,
                phone: savedProfile.phone,
                isDemo: savedProfile.isDemo,
            },
            accessToken: token,
        };
    }
    async login(dto) {
        const email = dto.email.toLowerCase().trim();
        const user = await this.profileRepository
            .createQueryBuilder('profile')
            .addSelect('profile.passwordHash')
            .where('profile.email = :email', { email })
            .getOne();
        if (!user) {
            throw new common_1.UnauthorizedException('Credenciales invalidas');
        }
        if (!user.passwordHash) {
            throw new common_1.UnauthorizedException('El usuario no tiene contrasena configurada');
        }
        const isMatch = await bcrypt.compare(dto.password, user.passwordHash);
        if (!isMatch) {
            throw new common_1.UnauthorizedException('Credenciales invalidas');
        }
        if (dto.fcmToken && dto.fcmToken !== user.fcmToken) {
            user.fcmToken = dto.fcmToken;
            await this.profileRepository.save(user);
        }
        const token = this.generateToken(user);
        return {
            user: {
                id: user.id,
                email: user.email,
                fullName: user.fullName,
                role: user.role,
                avatarUrl: user.avatarUrl,
                phone: user.phone,
                fcmToken: user.fcmToken,
                isDemo: user.isDemo,
            },
            accessToken: token,
        };
    }
    async resetPassword(dto) {
        const user = await this.profileRepository.findOne({
            where: { email: dto.email.toLowerCase().trim() },
        });
        if (!user) {
            return {
                message: 'Si el correo esta registrado, recibira instrucciones para restablecer la contrasena',
            };
        }
        this.logger.log(`Password reset requested for email: ${user.email}`);
        return {
            message: 'Instrucciones de recuperacion enviadas al correo electronico',
        };
    }
    async getProfile(userId) {
        const user = await this.profileRepository.findOne({
            where: { id: userId },
        });
        if (!user) {
            throw new common_1.NotFoundException('Perfil de usuario no encontrado');
        }
        return user;
    }
    generateToken(user) {
        const payload = {
            sub: user.id,
            email: user.email,
            role: user.role,
            fullName: user.fullName,
        };
        return this.jwtService.sign(payload);
    }
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = AuthService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(profile_entity_1.Profile)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        jwt_1.JwtService,
        notifications_service_1.NotificationsService])
], AuthService);
//# sourceMappingURL=auth.service.js.map