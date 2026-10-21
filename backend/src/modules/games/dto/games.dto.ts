import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsIn,
  IsISO8601,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { GAME_KEYS } from '../games.logic';

export class RequestGamesDto {
  @IsUUID()
  businessId: string;

  /** Mensaje opcional del dueño al administrador. */
  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

export class ApproveGamesDto {
  @IsArray()
  @ArrayMinSize(1, { message: 'Asigna al menos un juego' })
  @ArrayUnique()
  @IsIn(GAME_KEYS, { each: true, message: 'Juego no válido' })
  games: string[];

  @IsIn(['discount_percent', 'mini_prize'], { message: 'El premio debe ser descuento o mini premio' })
  prizeType: 'discount_percent' | 'mini_prize';

  /** Porcentaje (1-100) cuando el premio es un descuento. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  prizeValue?: number;

  /** Texto del mini premio (o del descuento). */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  prizeLabel?: string;
}

export class RejectGamesDto {
  @IsString()
  @Length(1, 300)
  reason: string;
}

export class SendGameDto {
  @IsUUID()
  businessId: string;

  @IsIn(GAME_KEYS, { message: 'Juego no válido' })
  game: string;

  /** `all` = todos mis clientes (por defecto); `selected` = solo los elegidos. */
  @IsOptional()
  @IsIn(['all', 'selected'])
  audience?: 'all' | 'selected';

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(1000)
  @IsUUID('all', { each: true })
  recipientIds?: string[];

  /** Desde cuándo se puede jugar (ISO 8601). Por defecto, ahora mismo. */
  @IsOptional()
  @IsISO8601({}, { message: 'La hora de inicio no es válida' })
  startsAt?: string;

  /** Hasta cuándo se puede jugar (ISO 8601). Por defecto, 7 días después del inicio. */
  @IsOptional()
  @IsISO8601({}, { message: 'La hora de fin no es válida' })
  endsAt?: string;
}

export class GuessLetterDto {
  @IsString()
  @Length(1, 2)
  letter: string;
}

export class TttMoveDto {
  @IsInt()
  @Min(0)
  @Max(8)
  cell: number;
}

export class FinishFlappyDto {
  @IsInt()
  @Min(0)
  @Max(1000)
  score: number;
}
