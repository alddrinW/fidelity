import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { UserRole } from '../../database/entities/profile.entity';
import { StartWeeklyGameDto } from './dto/weekly-game.dto';
import { WeeklyGameService } from './weekly-game.service';

/** El juego semanal del cliente: elige un negocio, juega y, si gana, suma puntos ahí. */
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('weekly-game')
@Roles(UserRole.CLIENT)
export class WeeklyGameController {
  constructor(private readonly weekly: WeeklyGameService) {}

  /** Si puede jugar esta semana y los negocios que tiene para elegir (los ya ganados salen bloqueados). */
  @Get('status')
  status(@CurrentUser() user: AuthenticatedUser) {
    return this.weekly.status(user.id);
  }

  /** Elige el negocio y arranca el juego de la semana; devuelve el reto para abrirlo. */
  @Post('start')
  start(@CurrentUser() user: AuthenticatedUser, @Body() dto: StartWeeklyGameDto) {
    return this.weekly.start(user.id, dto.businessId);
  }
}
