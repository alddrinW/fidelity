import {
  IsNotEmpty,
  IsOptional,
  IsString,
  IsNumber,
  IsBoolean,
  IsUUID,
  Matches,
  Min,
} from 'class-validator';
import { IsImageSource } from '../../../common/validators/is-image-source.validator';

const TAX_ID_PATTERN = /^(\d{10}|\d{13})$/;
const TAX_ID_MESSAGE = 'La cedula debe tener 10 digitos o el RUC 13 digitos';

export class CreateBusinessDto {
  @IsString()
  @IsNotEmpty({ message: 'El nombre del negocio es requerido' })
  name: string;

  /** Negocio principal del que este es una sucursal (debe ser del mismo dueño). */
  @IsUUID()
  @IsOptional()
  parentId?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsNumber()
  @IsOptional()
  categoryId?: number;

  @IsString()
  @IsOptional()
  category?: string;

  @IsImageSource()
  @IsOptional()
  logoUrl?: string;

  @IsString()
  @IsOptional()
  rewardDescription?: string;

  @IsString()
  @IsOptional()
  rewardLongDescription?: string;

  @IsNumber()
  @Min(1, { message: 'Los puntos requeridos deben ser al menos 1' })
  @IsOptional()
  pointsRequired?: number;

  @IsNumber()
  @Min(1, { message: 'El cooldown debe ser al menos 1 hora' })
  @IsOptional()
  cooldownHours?: number;

  @IsNumber()
  @IsOptional()
  latitude?: number;

  @IsNumber()
  @IsOptional()
  longitude?: number;

  @IsString()
  @IsOptional()
  address?: string;

  @IsString()
  @IsOptional()
  phone?: string;

  @Matches(TAX_ID_PATTERN, { message: TAX_ID_MESSAGE })
  @IsOptional()
  taxId?: string;
}

export class UpdateBusinessDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsNumber()
  @IsOptional()
  categoryId?: number;

  @IsString()
  @IsOptional()
  category?: string;

  @IsImageSource()
  @IsOptional()
  logoUrl?: string;

  @IsString()
  @IsOptional()
  rewardDescription?: string;

  @IsString()
  @IsOptional()
  rewardLongDescription?: string;

  @IsNumber()
  @Min(1)
  @IsOptional()
  pointsRequired?: number;

  @IsNumber()
  @Min(1)
  @IsOptional()
  cooldownHours?: number;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsNumber()
  @IsOptional()
  latitude?: number;

  @IsNumber()
  @IsOptional()
  longitude?: number;

  @IsString()
  @IsOptional()
  address?: string;

  @IsString()
  @IsOptional()
  phone?: string;

  @Matches(TAX_ID_PATTERN, { message: TAX_ID_MESSAGE })
  @IsOptional()
  taxId?: string;
}

export class CreateCategoryDto {
  @IsString()
  @IsNotEmpty({ message: 'El nombre de la categoria es requerido' })
  name: string;

  @IsString()
  @IsOptional()
  icon?: string;
}

export class ToggleBusinessStatusDto {
  @IsBoolean()
  isActive: boolean;
}
