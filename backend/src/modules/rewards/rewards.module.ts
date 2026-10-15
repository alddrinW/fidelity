import { Module } from '@nestjs/common';
import { BusinessesModule } from '../businesses/businesses.module';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RewardsService } from './rewards.service';
import { RewardsController } from './rewards.controller';
import { Reward } from '../../database/entities/reward.entity';
import { RewardTransferHistory } from '../../database/entities/reward-transfer-history.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Profile } from '../../database/entities/profile.entity';

@Module({
  imports: [
    BusinessesModule,
    TypeOrmModule.forFeature([
      Reward,
      RewardTransferHistory,
      Business,
      LoyaltyCard,
      Profile,
    ]),
  ],
  controllers: [RewardsController],
  providers: [RewardsService],
  exports: [RewardsService],
})
export class RewardsModule {}
