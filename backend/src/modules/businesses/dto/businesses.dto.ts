import {
  IsNotEmpty,
  IsOptional,
  IsString,
  IsNumber,
  IsBoolean,
  Min,
} from 'class-validator';

export class CreateBusinessDto {
  @IsString()
  @IsNotEmpty({ message: 'El nombre del negocio es requerido' })
  name: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsNumber()
  @IsOptional()
  categoryId?: number;

  @IsString()
  @IsOptional()
  category?: string;

  @IsString()
  @IsOptional()
  logoUrl?: string;

  @IsString()
  @IsOptional()
  rewardDescription?: string;

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

  @IsString()
  @IsOptional()
  logoUrl?: string;

  @IsString()
  @IsOptional()
  rewardDescription?: string;

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
