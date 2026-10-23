import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { UserRole } from '../../database/entities/profile.entity';
import { BirthdaysService } from './birthdays.service';
import { GiftBirthdayDto } from './dto/birthdays.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.BUSINESS, UserRole.ADMIN)
@Controller('birthdays')
export class BirthdaysController {
  constructor(private readonly birthdaysService: BirthdaysService) {}

  /** Cumpleaños de hoy, próximos y recientes de los clientes de mis negocios. */
  @Get('upcoming')
  upcoming(@CurrentUser() user: AuthenticatedUser, @Query('businessId') businessId?: string) {
    return this.birthdaysService.upcoming(user, businessId || undefined);
  }

  /** Regalar una gift card a un cliente por su cumpleaños. */
  @Post('gift')
  gift(@CurrentUser() user: AuthenticatedUser, @Body() dto: GiftBirthdayDto) {
    return this.birthdaysService.gift(user, dto);
  }
}
