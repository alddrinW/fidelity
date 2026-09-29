import { IsNotEmpty, IsString, IsUUID, IsNumber, Min, IsEnum } from 'class-validator';
import { ScanStatus } from '../../../database/entities/scan.entity';

export class ValidateScanDto {
  @IsString()
  @IsNotEmpty({ message: 'El codigo QR es requerido' })
  qr_code: string;
}

export class AddManualPointsDto {
  @IsUUID('4', { message: 'El ID de usuario debe ser un UUID valido' })
  userId: string;

  @IsUUID('4', { message: 'El ID de negocio debe ser un UUID valido' })
  businessId: string;

  @IsNumber()
  @Min(1, { message: 'Los puntos asignados deben ser mayores a 0' })
  points: number;
}

export class UpdateScanStatusDto {
  @IsEnum(ScanStatus, { message: 'El estado debe ser pending, approved o rejected' })
  status: ScanStatus;
}
