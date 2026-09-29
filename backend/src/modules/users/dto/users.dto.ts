import { IsOptional, IsString, IsEnum } from 'class-validator';
import { UserRole } from '../../../database/entities/profile.entity';

export class UpdateProfileDto {
  @IsString()
  @IsOptional()
  fullName?: string;

  @IsString()
  @IsOptional()
  phone?: string;

  @IsString()
  @IsOptional()
  avatarUrl?: string;

  @IsString()
  @IsOptional()
  fcmToken?: string;
}

export class UpdateFcmTokenDto {
  @IsString()
  fcmToken: string;
}
