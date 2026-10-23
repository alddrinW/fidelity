import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BirthdayNotice } from '../../database/entities/birthday-notice.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Profile } from '../../database/entities/profile.entity';
import { BusinessesModule } from '../businesses/businesses.module';
import { CampaignsModule } from '../campaigns/campaigns.module';
import { BirthdaysController } from './birthdays.controller';
import { BirthdaysSchedulerService } from './birthdays-scheduler.service';
import { BirthdaysService } from './birthdays.service';

/** Cumpleaños de los clientes: aviso al dueño y regalo de una gift card. */
@Module({
  imports: [
    TypeOrmModule.forFeature([Profile, LoyaltyCard, Business, BirthdayNotice]),
    BusinessesModule,
    CampaignsModule,
  ],
  controllers: [BirthdaysController],
  providers: [BirthdaysService, BirthdaysSchedulerService],
})
export class BirthdaysModule {}
