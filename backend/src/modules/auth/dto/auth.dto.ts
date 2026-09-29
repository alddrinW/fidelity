import { IsEmail, IsNotEmpty, IsOptional, IsString, MinLength, IsEnum, IsBoolean } from 'class-validator';
import { UserRole } from '../../../database/entities/profile.entity';

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

  @IsString()
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

export class ResetPasswordDto {
  @IsEmail({}, { message: 'El correo electronico debe ser valido' })
  email: string;
}
