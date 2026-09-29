import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AdminService } from './admin.service';
import { AdminController } from './admin.controller';
import { Profile } from '../../database/entities/profile.entity';
import { Business } from '../../database/entities/business.entity';
import { Scan } from '../../database/entities/scan.entity';
import { Reward } from '../../database/entities/reward.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { RewardTransferHistory } from '../../database/entities/reward-transfer-history.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Profile,
      Business,
      Scan,
      Reward,
      LoyaltyCard,
      RewardTransferHistory,
    ]),
  ],
  controllers: [AdminController],
  providers: [AdminService],
  exports: [AdminService],
})
export class AdminModule {}
