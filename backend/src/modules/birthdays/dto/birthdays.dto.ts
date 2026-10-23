import { IsEnum, IsInt, IsOptional, IsString, IsUUID, Matches, Max, MaxLength, Min } from 'class-validator';
import { CampaignBenefit } from '../../../database/entities/campaign.entity';

/**
 * El regalo de cumpleaños (plantilla): el dueño solo elige el premio (un
 * descuento % o un mini premio), a quién y las horas. La fecha es siempre el
 * día del cumpleaños; el diseño y el texto ya vienen puestos.
 */
export class GiftBirthdayDto {
  @IsUUID()
  businessId: string;

  @IsUUID()
  userId: string;

  @IsEnum(CampaignBenefit, { message: 'El beneficio debe ser discount_percent o mini_prize' })
  benefitType: CampaignBenefit;

  /** Porcentaje de descuento (1 a 100), si el beneficio es un descuento. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  benefitValue?: number;

  /** Descripción del mini premio (o texto del descuento). */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  benefitLabel?: string;

  /** Desde qué hora vale ese día (`HH:mm`, hora de Ecuador). Por defecto, la del aviso. */
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'La hora de inicio debe tener el formato HH:mm' })
  startTime?: string;

  /** Hasta qué hora vale ese día (`HH:mm`). Por defecto, todo el día (23:59). */
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'La hora de fin debe tener el formato HH:mm' })
  endTime?: string;
}
