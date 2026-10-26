import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GamesService } from './games.service';
import { GamesSchedulerService } from './games-scheduler.service';
import { GamesController } from './games.controller';
import { GameAccess } from '../../database/entities/game-access.entity';
import { GameInvite } from '../../database/entities/game-invite.entity';
import { Campaign } from '../../database/entities/campaign.entity';
import { CampaignBusiness } from '../../database/entities/campaign-business.entity';
import { CampaignClaim } from '../../database/entities/campaign-claim.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { BusinessesModule } from '../businesses/businesses.module';
import { LoyaltyCardsModule } from '../loyalty-cards/loyalty-cards.module';
import { WeeklyGameController } from './weekly-game.controller';
import { WeeklyGameService } from './weekly-game.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      GameAccess,
      GameInvite,
      Campaign,
      CampaignBusiness,
      CampaignClaim,
      Business,
      LoyaltyCard,
    ]),
    BusinessesModule,
    LoyaltyCardsModule,
  ],
  controllers: [GamesController, WeeklyGameController],
  providers: [GamesService, GamesSchedulerService, WeeklyGameService],
})
export class GamesModule {}
