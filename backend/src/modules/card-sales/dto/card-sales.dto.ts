import { IsOptional, IsString, MaxLength } from 'class-validator';

/** Lo que anota el administrador al registrar un pago a un local o una devolución. */
export class SettlePayoutDto {
  /** Referencia de la transferencia o comentario. */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}
