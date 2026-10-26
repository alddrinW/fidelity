import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Business } from '../../database/entities/business.entity';
import { Profile } from '../../database/entities/profile.entity';
import { Referral, ReferralUse } from '../../database/entities/referral.entity';
import { Scan } from '../../database/entities/scan.entity';
import { LoyaltyCardsModule } from '../loyalty-cards/loyalty-cards.module';
import { InviteLandingController, ReferralsAdminController, ReferralsController } from './referrals.controller';
import { ReferralsService } from './referrals.service';

/**
 * Invitar amigos a la app: un código y un enlace por cliente; el primer escaneo
 * del amigo da puntos de invitación a los dos, que usan en el local que elijan
 * entre los que el administrador marcó como participantes.
 */
@Module({
  imports: [TypeOrmModule.forFeature([Business, Profile, Referral, ReferralUse, Scan]), LoyaltyCardsModule],
  controllers: [ReferralsController, ReferralsAdminController, InviteLandingController],
  providers: [ReferralsService],
  exports: [ReferralsService],
})
export class ReferralsModule {}
