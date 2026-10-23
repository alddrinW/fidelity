import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { Profile } from '../../database/entities/profile.entity';
import { Business } from '../../database/entities/business.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Scan } from '../../database/entities/scan.entity';
import { ScanAttempt } from '../../database/entities/scan-attempt.entity';
import { Reward } from '../../database/entities/reward.entity';
import { SupportTicket } from '../../database/entities/support-ticket.entity';
import { QrCode } from '../../database/entities/qr-code.entity';
import { MailModule } from '../mail/mail.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Profile,
      Business,
      LoyaltyCard,
      Scan,
      ScanAttempt,
      Reward,
      SupportTicket,
      QrCode,
    ]),
    MailModule,
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
