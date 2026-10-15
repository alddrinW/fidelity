import { IsEnum, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { PaymentMethod } from '../../../database/entities/payment.entity';
import { IsImageSource } from '../../../common/validators/is-image-source.validator';

export class ReportPaymentDto {
  @IsEnum(PaymentMethod, { message: 'El método debe ser card, transfer, deposit o cash' })
  method: PaymentMethod;

  /** Número de transferencia/depósito u otro dato para validar el pago. */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;

  @IsOptional()
  @IsImageSource()
  proofUrl?: string;
}

export class RejectPaymentDto {
  @IsString()
  @MaxLength(300)
  reason: string;
}

export class CreateOrderDto {
  @IsUUID()
  businessId: string;
}
