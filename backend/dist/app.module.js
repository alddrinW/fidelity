"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const typeorm_1 = require("@nestjs/typeorm");
const configuration_1 = require("./config/configuration");
const entities_1 = require("./database/entities");
const auth_module_1 = require("./modules/auth/auth.module");
const users_module_1 = require("./modules/users/users.module");
const businesses_module_1 = require("./modules/businesses/businesses.module");
const loyalty_cards_module_1 = require("./modules/loyalty-cards/loyalty-cards.module");
const scans_module_1 = require("./modules/scans/scans.module");
const rewards_module_1 = require("./modules/rewards/rewards.module");
const qr_codes_module_1 = require("./modules/qr-codes/qr-codes.module");
const support_tickets_module_1 = require("./modules/support-tickets/support-tickets.module");
const notifications_module_1 = require("./modules/notifications/notifications.module");
const realtime_module_1 = require("./modules/realtime/realtime.module");
const admin_module_1 = require("./modules/admin/admin.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({
                isGlobal: true,
                load: [configuration_1.configuration],
            }),
            typeorm_1.TypeOrmModule.forRootAsync({
                imports: [config_1.ConfigModule],
                useFactory: (configService) => ({
                    type: 'postgres',
                    host: configService.get('database.host'),
                    port: configService.get('database.port'),
                    username: configService.get('database.username'),
                    password: configService.get('database.password'),
                    database: configService.get('database.database'),
                    ssl: configService.get('database.ssl'),
                    synchronize: configService.get('database.synchronize'),
                    autoLoadEntities: true,
                    entities: [
                        entities_1.Profile,
                        entities_1.BusinessCategory,
                        entities_1.Business,
                        entities_1.LoyaltyCard,
                        entities_1.QrCode,
                        entities_1.Scan,
                        entities_1.ScanAttempt,
                        entities_1.Reward,
                        entities_1.RewardTransferHistory,
                        entities_1.SupportTicket,
                    ],
                }),
                inject: [config_1.ConfigService],
            }),
            notifications_module_1.NotificationsModule,
            realtime_module_1.RealtimeModule,
            auth_module_1.AuthModule,
            users_module_1.UsersModule,
            businesses_module_1.BusinessesModule,
            loyalty_cards_module_1.LoyaltyCardsModule,
            scans_module_1.ScansModule,
            rewards_module_1.RewardsModule,
            qr_codes_module_1.QrCodesModule,
            support_tickets_module_1.SupportTicketsModule,
            admin_module_1.AdminModule,
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map