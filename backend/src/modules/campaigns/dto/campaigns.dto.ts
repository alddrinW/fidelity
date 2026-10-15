import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { CampaignBenefit, CampaignType } from '../../../database/entities/campaign.entity';
import { IsImageSource } from '../../../common/validators/is-image-source.validator';

export class CreateCampaignDto {
  @IsEnum(CampaignType, { message: 'El tipo debe ser event, gift_card o route' })
  type: CampaignType;

  @IsString()
  @Length(3, 120, { message: 'El título debe tener entre 3 y 120 caracteres' })
  title: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @IsOptional()
  @IsImageSource()
  imageUrl?: string;

  /** Solo para tarjetas de regalo. */
  @IsOptional()
  @IsEnum(CampaignBenefit)
  benefitType?: CampaignBenefit;

  /** Porcentaje (1-100) cuando el beneficio es un descuento. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  benefitValue?: number;

  /** Texto del mini premio (o descripción del beneficio). */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  benefitLabel?: string;

  /** Cuándo empieza. Sin valor, empieza ahora. Una fecha futura la programa. */
  @IsOptional()
  @IsISO8601()
  startsAt?: string;

  @IsOptional()
  @IsISO8601()
  endsAt?: string;

  /** Negocios y sucursales participantes (deben ser del dueño). */
  @IsArray()
  @ArrayMinSize(1, { message: 'Elige al menos un negocio participante' })
  @ArrayMaxSize(20)
  @IsUUID('all', { each: true })
  businessIds: string[];

  /** Sellos para completar la ruta (solo rutas). Por defecto, todos los locales. */
  @IsOptional()
  @IsInt()
  @Min(2)
  @Max(20)
  requiredStamps?: number;
}

export class UpdateCampaignDto {
  @IsOptional()
  @IsString()
  @Length(3, 120)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @IsOptional()
  @IsImageSource()
  imageUrl?: string;

  /** Solo se puede cambiar mientras la campaña no haya empezado. */
  @IsOptional()
  @IsISO8601()
  startsAt?: string;

  @IsOptional()
  @IsISO8601()
  endsAt?: string;
}

export class RedeemCodeDto {
  @IsString()
  @Length(4, 20)
  code: string;
}
