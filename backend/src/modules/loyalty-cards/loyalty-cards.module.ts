import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LoyaltyCardsService } from './loyalty-cards.service';
import { LoyaltyCardsController } from './loyalty-cards.controller';
import { FidelyService } from './fidely.service';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Business } from '../../database/entities/business.entity';
import { Scan } from '../../database/entities/scan.entity';
import { Reward } from '../../database/entities/reward.entity';
import { RewardTransferHistory } from '../../database/entities/reward-transfer-history.entity';
import { Profile } from '../../database/entities/profile.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      LoyaltyCard,
      Business,
      Scan,
      Reward,
      RewardTransferHistory,
      Profile,
    ]),
  ],
  controllers: [LoyaltyCardsController],
  providers: [LoyaltyCardsService, FidelyService],
  exports: [LoyaltyCardsService, FidelyService],
})
export class LoyaltyCardsModule {}
