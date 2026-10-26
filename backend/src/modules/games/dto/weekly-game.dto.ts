import { IsUUID } from 'class-validator';

export class StartWeeklyGameDto {
  /** El negocio donde el cliente quiere ganar su punto. */
  @IsUUID()
  businessId: string;
}
