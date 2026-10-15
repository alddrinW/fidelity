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
} from './database/entities';

// Feature Modules
import { AuthModule } from './modules/auth/auth.module';
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

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
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
        ],
      }),
      inject: [ConfigService],
    }),
    NotificationsModule,
    RealtimeModule,
    AuthModule,
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
})
export class AppModule {}
