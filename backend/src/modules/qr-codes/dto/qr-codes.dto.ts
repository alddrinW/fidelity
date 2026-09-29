import { IsNotEmpty, IsUUID, IsString, IsOptional, IsBoolean } from 'class-validator';

export class CreateQrCodeDto {
  @IsUUID('4', { message: 'El ID de negocio debe ser un UUID valido' })
  businessId: string;

  @IsString()
  @IsOptional()
  label?: string;

  @IsString()
  @IsOptional()
  qrCode?: string;
}

export class ToggleQrCodeDto {
  @IsBoolean()
  isActive: boolean;
}

export class UpdateQrCodeDto {
  @IsString()
  @IsOptional()
  qrCode?: string;

  @IsString()
  @IsOptional()
  label?: string;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}
