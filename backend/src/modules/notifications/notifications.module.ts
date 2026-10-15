import { Module, Global } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NotificationsService } from './notifications.service';
import { Profile } from '../../database/entities/profile.entity';
import { Business } from '../../database/entities/business.entity';
import { BusinessMember } from '../../database/entities/business-member.entity';

@Global()
@Module({
  imports: [TypeOrmModule.forFeature([Profile, Business, BusinessMember])],
  providers: [NotificationsService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
