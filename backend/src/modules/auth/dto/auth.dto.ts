import {
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
  IsEnum,
  IsBoolean,
} from 'class-validator';
import { UserRole } from '../../../database/entities/profile.entity';
import { IsImageSource } from '../../../common/validators/is-image-source.validator';

export class RegisterDto {
  @IsEmail({}, { message: 'El correo electronico debe ser valido' })
  email: string;

  @IsString()
  @MinLength(6, { message: 'La contrasena debe tener al menos 6 caracteres' })
  password: string;

  @IsString()
  @IsNotEmpty({ message: 'El nombre completo es requerido' })
  fullName: string;

  @IsEnum(UserRole, { message: 'El rol debe ser client o business' })
  @IsOptional()
  role?: UserRole;

  @IsString()
  @IsOptional()
  phone?: string;

  @IsImageSource()
  @IsOptional()
  avatarUrl?: string;

  @IsString()
  @IsOptional()
  fcmToken?: string;

  @IsBoolean()
  @IsOptional()
  isDemo?: boolean;
}

export class LoginDto {
  @IsEmail({}, { message: 'El correo electronico debe ser valido' })
  email: string;

  @IsString()
  @IsNotEmpty({ message: 'La contrasena es requerida' })
  password: string;

  @IsString()
  @IsOptional()
  fcmToken?: string;
}

/** Paso 1: pedir el código de recuperación. */
export class ForgotPasswordDto {
  @IsEmail({}, { message: 'El correo electronico debe ser valido' })
  email: string;
}

/** Paso 2: crear la nueva contraseña con el código recibido. */
export class ResetPasswordDto {
  @IsEmail({}, { message: 'El correo electronico debe ser valido' })
  email: string;

  @IsString()
  @Matches(/^\d{6}$/, { message: 'El código debe tener 6 dígitos' })
  code: string;

  @IsString()
  @MinLength(6, { message: 'La contrasena debe tener al menos 6 caracteres' })
  @MaxLength(72, { message: 'La contrasena es demasiado larga' })
  newPassword: string;
}
