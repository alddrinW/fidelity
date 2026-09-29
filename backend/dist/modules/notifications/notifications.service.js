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
var NotificationsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificationsService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const admin = require("firebase-admin");
const fs = require("fs");
const profile_entity_1 = require("../../database/entities/profile.entity");
const business_entity_1 = require("../../database/entities/business.entity");
let NotificationsService = NotificationsService_1 = class NotificationsService {
    constructor(configService, profileRepository, businessRepository) {
        this.configService = configService;
        this.profileRepository = profileRepository;
        this.businessRepository = businessRepository;
        this.logger = new common_1.Logger(NotificationsService_1.name);
        this.firebaseApp = null;
    }
    onModuleInit() {
        this.initializeFirebase();
    }
    initializeFirebase() {
        try {
            const serviceAccountStr = this.configService.get('firebase.serviceAccount');
            const credentialsPath = this.configService.get('firebase.credentialsPath');
            let credential = null;
            if (serviceAccountStr && serviceAccountStr.trim().length > 0) {
                const parsed = JSON.parse(serviceAccountStr);
                credential = admin.credential.cert(parsed);
            }
            else if (credentialsPath && fs.existsSync(credentialsPath)) {
                const content = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
                credential = admin.credential.cert(content);
            }
            if (credential) {
                if (!admin.apps.length) {
                    this.firebaseApp = admin.initializeApp({ credential });
                }
                else {
                    this.firebaseApp = admin.app();
                }
                this.logger.log('Firebase Admin SDK initialized successfully');
            }
            else {
                this.logger.warn('Firebase credentials not provided. Push notifications will run in mock mode');
            }
        }
        catch (error) {
            this.logger.error(`Error initializing Firebase Admin SDK: ${error.message}`);
        }
    }
    async sendPushNotification(token, title, body, dataPayload = {}) {
        if (!token)
            return false;
        if (!this.firebaseApp) {
            this.logger.debug(`[Mock FCM Notification] To: ${token.substring(0, 15)}... | Title: ${title} | Body: ${body}`);
            return true;
        }
        try {
            await admin.messaging().send({
                token,
                notification: {
                    title,
                    body,
                },
                data: dataPayload,
                android: {
                    priority: 'high',
                    notification: {
                        sound: 'default',
                        channelId: 'high_importance_channel',
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: 'default',
                        },
                    },
                },
            });
            return true;
        }
        catch (error) {
            this.logger.error(`Failed to send push notification: ${error.message}`);
            return false;
        }
    }
    async sendToUser(userId, title, body, dataPayload = {}) {
        const user = await this.profileRepository.findOne({ where: { id: userId } });
        if (!user || !user.fcmToken)
            return false;
        return this.sendPushNotification(user.fcmToken, title, body, dataPayload);
    }
    async sendToBusinessOwner(businessId, title, body, dataPayload = {}) {
        const business = await this.businessRepository.findOne({
            where: { id: businessId },
            relations: ['owner'],
        });
        if (!business || !business.owner || !business.owner.fcmToken)
            return false;
        return this.sendPushNotification(business.owner.fcmToken, title, body, dataPayload);
    }
    async broadcastToAdmins(title, body, route = '/admin_dashboard') {
        const admins = await this.profileRepository.find({
            where: { role: profile_entity_1.UserRole.ADMIN },
        });
        const tokens = admins.map((a) => a.fcmToken).filter(Boolean);
        for (const token of tokens) {
            await this.sendPushNotification(token, title, body, { route });
        }
    }
};
exports.NotificationsService = NotificationsService;
exports.NotificationsService = NotificationsService = NotificationsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(1, (0, typeorm_1.InjectRepository)(profile_entity_1.Profile)),
    __param(2, (0, typeorm_1.InjectRepository)(business_entity_1.Business)),
    __metadata("design:paramtypes", [config_1.ConfigService,
        typeorm_2.Repository,
        typeorm_2.Repository])
], NotificationsService);
//# sourceMappingURL=notifications.service.js.map