import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
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

/** Precios del registro que fija el administrador (en la moneda del plan). */
export class UpdatePricesDto {
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 }, { message: 'El precio debe tener máximo 2 decimales' })
  @Min(0.5, { message: 'El precio mínimo es 0.50' })
  @Max(10000, { message: 'El precio máximo es 10000' })
  registrationFee?: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 }, { message: 'El precio debe tener máximo 2 decimales' })
  @Min(0.5, { message: 'El precio mínimo es 0.50' })
  @Max(10000, { message: 'El precio máximo es 10000' })
  branchFee?: number;
}

/** Una cuenta a la que los dueños pueden transferir o depositar. */
export class BankAccountDto {
  @IsString()
  @MaxLength(80, { message: 'El nombre del banco es demasiado largo' })
  name: string;

  @IsString()
  @Matches(/^[0-9-]{4,30}$/, { message: 'El número de cuenta debe tener entre 4 y 30 dígitos' })
  accountNumber: string;

  @IsString()
  @MaxLength(80)
  accountType: string;

  @IsString()
  @MaxLength(120, { message: 'El nombre del titular es demasiado largo' })
  holder: string;

  @IsOptional()
  @IsString()
  @MaxLength(20, { message: 'La cédula o el RUC es demasiado largo' })
  taxId?: string;
}

/** Las cuentas bancarias que fija el administrador (reemplazan a las anteriores). */
export class UpdateBankAccountsDto {
  @IsArray()
  @ArrayMaxSize(5, { message: 'Puedes registrar hasta 5 cuentas' })
  @ValidateNested({ each: true })
  @Type(() => BankAccountDto)
  accounts: BankAccountDto[];
}
