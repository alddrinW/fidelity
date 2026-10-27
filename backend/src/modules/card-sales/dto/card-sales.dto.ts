import { IsIn, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { IsImageSource } from '../../../common/validators/is-image-source.validator';

/** Lo que anota el administrador al registrar un pago a un local o una devolución. */
export class SettlePayoutDto {
  /** Referencia de la transferencia o comentario. */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}

/** Cómo quiere pagar el cliente (por defecto, con tarjeta en PayPhone). */
export class PurchaseDto {
  @IsOptional()
  @IsIn(['card', 'transfer'], { message: 'El método debe ser card o transfer' })
  method?: 'card' | 'transfer';
}

/** El comprobante de una transferencia: la foto y, si quiere, el número de la transferencia. */
export class SubmitProofDto {
  @IsString()
  @IsNotEmpty({ message: 'Adjunta la foto del comprobante de la transferencia' })
  @IsImageSource()
  proofUrl: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}

/** Por qué el administrador no acepta un comprobante. */
export class RejectProofDto {
  @IsString()
  @IsNotEmpty({ message: 'Escribe el motivo para que el cliente sepa qué corregir' })
  @MaxLength(300)
  reason: string;
}
