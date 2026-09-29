import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BusinessesService } from './businesses.service';
import { BusinessesController } from './businesses.controller';
import { Business } from '../../database/entities/business.entity';
import { BusinessCategory } from '../../database/entities/business-category.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Scan } from '../../database/entities/scan.entity';
import { Reward } from '../../database/entities/reward.entity';
import { Profile } from '../../database/entities/profile.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Business,
      BusinessCategory,
      LoyaltyCard,
      Scan,
      Reward,
      Profile,
    ]),
  ],
  controllers: [BusinessesController],
  providers: [BusinessesService],
  exports: [BusinessesService],
})
export class BusinessesModule {}
