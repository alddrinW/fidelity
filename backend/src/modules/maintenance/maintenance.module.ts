import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GameInvite } from '../../database/entities/game-invite.entity';
import { Notification } from '../../database/entities/notification.entity';
import { ScanAttempt } from '../../database/entities/scan-attempt.entity';
import { RetentionService } from './retention.service';

/** Tareas de mantenimiento que corren solas dentro del servidor. */
@Module({
  imports: [TypeOrmModule.forFeature([Notification, ScanAttempt, GameInvite])],
  providers: [RetentionService],
})
export class MaintenanceModule {}
