import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Business } from '../../database/entities/business.entity';
import { Campaign } from '../../database/entities/campaign.entity';
import { CampaignClaim } from '../../database/entities/campaign-claim.entity';
import { CardPurchase } from '../../database/entities/card-purchase.entity';
import { CampaignsModule } from '../campaigns/campaigns.module';
import { PaymentsModule } from '../payments/payments.module';
import { CardSalesController, CardSalesPayphoneController } from './card-sales.controller';
import { CardSalesService } from './card-sales.service';

/**
 * Tarjetas en venta: gift cards con precio que el cliente compra con PayPhone.
 * Fidelity retiene una comisión y le paga al local lo de las tarjetas canjeadas.
 */
@Module({
  imports: [
    TypeOrmModule.forFeature([CardPurchase, Campaign, CampaignClaim, Business]),
    CampaignsModule,
    PaymentsModule,
  ],
  controllers: [CardSalesController, CardSalesPayphoneController],
  providers: [CardSalesService],
  exports: [CardSalesService],
})
export class CardSalesModule {}
