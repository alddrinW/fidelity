import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsIn,
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
  @IsEnum(CampaignType, { message: 'El tipo debe ser event, gift_card, route o scan_challenge' })
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

  /** Solo gift cards: la pone en venta a este precio, en centavos (p. ej. 25 = $0.25). */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100000)
  priceCents?: number;

  /** Tarjetas en venta: cuántas se pueden vender. */
  @IsOptional()
  @IsInt()
  @Min(1, { message: 'Pon al menos 1 tarjeta a la venta' })
  @Max(5000, { message: 'No puedes poner más de 5000 tarjetas a la venta' })
  stock?: number;

  /** Tarjetas en venta: cuántos días vale la tarjeta desde que se compra (30 por defecto). */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(365)
  cardValidDays?: number;

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

  /** Gift cards: `all` (por defecto) = todos mis clientes; `selected` = solo los elegidos. */
  @IsOptional()
  @IsIn(['all', 'selected'], { message: 'La audiencia debe ser all o selected' })
  audience?: 'all' | 'selected';

  /** Clientes elegidos (gift cards con audiencia `selected`). */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(1000)
  @IsUUID('all', { each: true })
  recipientIds?: string[];

  /** Sellos para completar la ruta (solo rutas). Por defecto, todos los locales. */
  @IsOptional()
  @IsInt()
  @Min(2)
  @Max(20)
  requiredStamps?: number;

  /** Escaneos que debe hacer el cliente para ganar (solo retos de escaneos). */
  @IsOptional()
  @IsInt()
  @Min(2, { message: 'El reto necesita al menos 2 escaneos' })
  @Max(100, { message: 'El reto no puede pedir más de 100 escaneos' })
  requiredScans?: number;
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

  /** Gift cards: nuevo porcentaje de descuento. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  benefitValue?: number;

  /** Gift cards: nuevo texto del beneficio. */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  benefitLabel?: string;

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
