import { Module, Global } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NotificationsService } from './notifications.service';
import { Profile } from '../../database/entities/profile.entity';
import { Business } from '../../database/entities/business.entity';

@Global()
@Module({
  imports: [TypeOrmModule.forFeature([Profile, Business])],
  providers: [NotificationsService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
