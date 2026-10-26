import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { configuration } from './config/configuration';

// Entities
import {
  Profile,
  BusinessCategory,
  Business,
  LoyaltyCard,
  QrCode,
  Scan,
  ScanAttempt,
  Reward,
  RewardTransferHistory,
  SupportTicket,
  Payment,
  Feedback,
  BusinessMember,
  Campaign,
  CampaignBusiness,
  CampaignClaim,
  CampaignStamp,
  AppSetting,
  Notification,
  CampaignRecipient,
  GameAccess,
  GameInvite,
  BirthdayNotice,
  Referral,
  ReferralUse,
  CardPurchase,
} from './database/entities';

// Feature Modules
import { AuthModule } from './modules/auth/auth.module';
import { GamesModule } from './modules/games/games.module';
import { MaintenanceModule } from './modules/maintenance/maintenance.module';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { AppThrottlerGuard } from './common/guards/app-throttler.guard';
import { UsersModule } from './modules/users/users.module';
import { BusinessesModule } from './modules/businesses/businesses.module';
import { LoyaltyCardsModule } from './modules/loyalty-cards/loyalty-cards.module';
import { ScansModule } from './modules/scans/scans.module';
import { RewardsModule } from './modules/rewards/rewards.module';
import { QrCodesModule } from './modules/qr-codes/qr-codes.module';
import { SupportTicketsModule } from './modules/support-tickets/support-tickets.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { RealtimeModule } from './modules/realtime/realtime.module';
import { AdminModule } from './modules/admin/admin.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { FeedbackModule } from './modules/feedback/feedback.module';
import { CampaignsModule } from './modules/campaigns/campaigns.module';
import { SettingsModule } from './modules/settings/settings.module';
import { BirthdaysModule } from './modules/birthdays/birthdays.module';
import { ReferralsModule } from './modules/referrals/referrals.module';
import { CardSalesModule } from './modules/card-sales/card-sales.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
    }),
    SettingsModule,
    MaintenanceModule,
    // Límite general: 120 peticiones por minuto por IP. Las rutas de contraseñas
    // tienen límites más estrictos (ver AuthController).
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        throttlers: [{ name: 'default', ttl: 60_000, limit: 120 }],
        skipIf: () => !!configService.get<boolean>('rateLimit.disabled'),
        errorMessage: 'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
      }),
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        host: configService.get<string>('database.host'),
        port: configService.get<number>('database.port'),
        username: configService.get<string>('database.username'),
        password: configService.get<string>('database.password'),
        database: configService.get<string>('database.database'),
        ssl: configService.get('database.ssl'),
        synchronize: configService.get<boolean>('database.synchronize'),
        autoLoadEntities: true,
        entities: [
          Profile,
          BusinessCategory,
          Business,
          LoyaltyCard,
          QrCode,
          Scan,
          ScanAttempt,
          Reward,
          RewardTransferHistory,
          SupportTicket,
          Payment,
          Feedback,
          BusinessMember,
          Campaign,
          CampaignBusiness,
          CampaignClaim,
          CampaignStamp,
          AppSetting,
          Notification,
          CampaignRecipient,
          GameAccess,
          GameInvite,
          BirthdayNotice,
          Referral,
          ReferralUse,
          CardPurchase,
        ],
      }),
      inject: [ConfigService],
    }),
    NotificationsModule,
    RealtimeModule,
    AuthModule,
    GamesModule,
    BirthdaysModule,
    ReferralsModule,
    CardSalesModule,
    UsersModule,
    BusinessesModule,
    LoyaltyCardsModule,
    ScansModule,
    RewardsModule,
    QrCodesModule,
    SupportTicketsModule,
    PaymentsModule,
    FeedbackModule,
    CampaignsModule,
    AdminModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: AppThrottlerGuard }],
})
export class AppModule {}
