import { ArrayMaxSize, IsArray, IsBoolean, IsInt, IsNotEmpty, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

export class RedeemReferralDto {
  /** El código de amigo (`AMG-XXXXXX`); se acepta sin guion y en minúsculas. */
  @IsString()
  @IsNotEmpty({ message: 'Escribe el código de tu amigo' })
  @MaxLength(20, { message: 'Ese código no es válido' })
  code: string;
}

/** Usar puntos de invitación en un local. */
export class UseReferralPointsDto {
  @IsUUID()
  businessId: string;

  /** Cuántos puntos usar (por defecto 1). */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(50)
  points?: number;
}

/** El administrador marca (o desmarca) un local como participante. */
export class SetReferralBusinessDto {
  @IsBoolean({ message: 'enabled debe ser true o false' })
  enabled: boolean;
}

/** Marcar o desmarcar varios locales de una vez. */
export class SetReferralBusinessesDto {
  @IsArray()
  @ArrayMaxSize(1000)
  @IsUUID('all', { each: true })
  ids: string[];

  @IsBoolean({ message: 'enabled debe ser true o false' })
  enabled: boolean;
}
