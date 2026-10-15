import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { FeedbackKind, FeedbackStatus } from '../../../database/entities/feedback.entity';

export class CreateFeedbackDto {
  @IsUUID()
  businessId: string;

  /** Si no se envía se deduce: calificación baja = reclamo, con texto = sugerencia. */
  @IsOptional()
  @IsEnum(FeedbackKind)
  kind?: FeedbackKind;

  /** 1 = mal, 2 = regular, 3 = excelente. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(3)
  rating?: number;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  @IsString({ each: true })
  @MaxLength(40, { each: true })
  tags?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  message?: string;
}

export class ResolveFeedbackDto {
  /** Respuesta opcional para el cliente. */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reply?: string;
}

export class FeedbackFilterDto {
  @IsOptional()
  @IsEnum(FeedbackStatus)
  status?: FeedbackStatus;

  @IsOptional()
  @IsEnum(FeedbackKind)
  kind?: FeedbackKind;
}
