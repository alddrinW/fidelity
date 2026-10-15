import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FeedbackService } from './feedback.service';
import { FeedbackController } from './feedback.controller';
import { Feedback } from '../../database/entities/feedback.entity';
import { Business } from '../../database/entities/business.entity';
import { Scan } from '../../database/entities/scan.entity';
import { BusinessesModule } from '../businesses/businesses.module';

@Module({
  imports: [TypeOrmModule.forFeature([Feedback, Business, Scan]), BusinessesModule],
  controllers: [FeedbackController],
  providers: [FeedbackService],
  exports: [FeedbackService],
})
export class FeedbackModule {}
