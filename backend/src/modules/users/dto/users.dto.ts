import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { IsStrongPassword } from '../../../common/validators/strong-password';
import { IsImageSource } from '../../../common/validators/is-image-source.validator';
import { IsBirthDate } from '../../../common/validators/birth-date';

export class UpdateProfileDto {
  @IsString()
  @IsOptional()
  fullName?: string;

  @IsString()
  @IsOptional()
  phone?: string;

  /** `AAAA-MM-DD`; el texto vacío borra la fecha guardada. */
  @IsOptional()
  @IsBirthDate({ allowEmpty: true })
  birthDate?: string;

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

export class UpdateLanguageDto {
  @IsIn(['es', 'en'], { message: 'Idioma no válido' })
  language: 'es' | 'en';
}

export class ChangePasswordDto {
  @IsString()
  @IsNotEmpty({ message: 'La contrasena actual es requerida' })
  currentPassword: string;

  @IsString()
  @IsStrongPassword()
  newPassword: string;
}
