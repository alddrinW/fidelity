import {
  Controller,
  DefaultValuePipe,
  Get,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';

/** Bandeja de notificaciones del usuario con sesión (cualquier rol). */
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  /** Sus movimientos, del más nuevo al más viejo. `before` pagina (fecha ISO). */
  @Get()
  list(
    @CurrentUser() user: AuthenticatedUser,
    @Query('limit', new DefaultValuePipe(30), ParseIntPipe) limit: number,
    @Query('before') before?: string,
  ) {
    return this.notificationsService.listForUser(user.id, limit, before);
  }

  @Get('unread-count')
  async unreadCount(@CurrentUser() user: AuthenticatedUser) {
    return { count: await this.notificationsService.unreadCount(user.id) };
  }

  @Patch('read-all')
  async readAll(@CurrentUser() user: AuthenticatedUser) {
    return { updated: await this.notificationsService.markAllRead(user.id) };
  }

  @Patch(':id/read')
  async read(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return { updated: await this.notificationsService.markRead(user.id, id) };
  }
}
