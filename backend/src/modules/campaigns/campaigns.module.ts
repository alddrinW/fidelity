import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CampaignsService } from './campaigns.service';
import { CampaignsController } from './campaigns.controller';
import { CampaignSchedulerService } from './campaign-scheduler.service';
import { Campaign } from '../../database/entities/campaign.entity';
import { CampaignBusiness } from '../../database/entities/campaign-business.entity';
import { CampaignClaim } from '../../database/entities/campaign-claim.entity';
import { CampaignStamp } from '../../database/entities/campaign-stamp.entity';
import { CampaignRecipient } from '../../database/entities/campaign-recipient.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Scan } from '../../database/entities/scan.entity';
import { BusinessesModule } from '../businesses/businesses.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Campaign,
      CampaignBusiness,
      CampaignClaim,
      CampaignStamp,
      CampaignRecipient,
      Business,
      LoyaltyCard,
      Scan,
    ]),
    BusinessesModule,
  ],
  controllers: [CampaignsController],
  providers: [CampaignsService, CampaignSchedulerService],
  exports: [CampaignsService],
})
export class CampaignsModule {}
