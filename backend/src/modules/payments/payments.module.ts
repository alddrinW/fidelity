import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PaymentsService } from './payments.service';
import { PaymentsController } from './payments.controller';
import { PayphoneReturnController } from './payphone-return.controller';
import { PayphoneService } from './payphone.service';
import { Payment } from '../../database/entities/payment.entity';
import { Business } from '../../database/entities/business.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Payment, Business])],
  controllers: [PaymentsController, PayphoneReturnController],
  providers: [PaymentsService, PayphoneService],
  exports: [PaymentsService, PayphoneService],
})
export class PaymentsModule {}
