import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BusinessesService } from './businesses.service';
import { BusinessesController } from './businesses.controller';
import { BusinessAccessService } from './business-access.service';
import { BusinessMembersService } from './business-members.service';
import { BusinessMembersController } from './business-members.controller';
import { BusinessMember } from '../../database/entities/business-member.entity';
import { Business } from '../../database/entities/business.entity';
import { BusinessCategory } from '../../database/entities/business-category.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Scan } from '../../database/entities/scan.entity';
import { Reward } from '../../database/entities/reward.entity';
import { Profile } from '../../database/entities/profile.entity';
import { PaymentsModule } from '../payments/payments.module';

@Module({
  imports: [
    PaymentsModule,
    TypeOrmModule.forFeature([
      Business,
      BusinessCategory,
      LoyaltyCard,
      Scan,
      Reward,
      Profile,
      BusinessMember,
    ]),
  ],
  controllers: [BusinessesController, BusinessMembersController],
  providers: [BusinessesService, BusinessAccessService, BusinessMembersService],
  exports: [BusinessesService, BusinessAccessService],
})
export class BusinessesModule {}
