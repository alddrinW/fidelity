import { IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';
import { IsImageSource } from '../../../common/validators/is-image-source.validator';

export class UpdateProfileDto {
  @IsString()
  @IsOptional()
  fullName?: string;

  @IsString()
  @IsOptional()
  phone?: string;

  @IsImageSource()
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

export class ChangePasswordDto {
  @IsString()
  @IsNotEmpty({ message: 'La contrasena actual es requerida' })
  currentPassword: string;

  @IsString()
  @MinLength(6, { message: 'La nueva contrasena debe tener al menos 6 caracteres' })
  newPassword: string;
}
