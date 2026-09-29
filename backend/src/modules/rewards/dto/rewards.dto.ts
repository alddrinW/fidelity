import { IsNotEmpty, IsUUID, IsEnum, IsOptional, IsString } from 'class-validator';
import { RewardStatus } from '../../../database/entities/reward.entity';

export class UpdateRewardStatusDto {
  @IsEnum(RewardStatus, { message: 'El estado debe ser pending, approved, claimed o rejected' })
  status: RewardStatus;
}

export class TransferRewardDto {
  @IsUUID('4', { message: 'El ID del premio debe ser un UUID valido' })
  rewardId: string;

  @IsUUID('4', { message: 'El ID del destinatario debe ser un UUID valido' })
  @IsOptional()
  toUserId?: string;

  @IsString()
  @IsOptional()
  toEmail?: string;
}
