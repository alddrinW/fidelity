import { IsNotEmpty, IsString, IsOptional, IsUUID } from 'class-validator';

export class CreateSupportTicketDto {
  @IsString()
  @IsNotEmpty({ message: 'El asunto es requerido' })
  subject: string;

  @IsString()
  @IsNotEmpty({ message: 'El mensaje es requerido' })
  message: string;

  @IsUUID('4')
  @IsOptional()
  businessId?: string;
}

export class UpdateTicketStatusDto {
  @IsString()
  @IsNotEmpty()
  status: string;
}
