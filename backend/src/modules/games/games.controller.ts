import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { GamesService } from './games.service';
import {
  ApproveGamesDto,
  FinishFlappyDto,
  GuessLetterDto,
  RejectGamesDto,
  RequestGamesDto,
  SendGameDto,
  TttMoveDto,
} from './dto/games.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { UserRole } from '../../database/entities/profile.entity';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('games')
export class GamesController {
  constructor(private readonly gamesService: GamesService) {}

  // --- Administrador ---

  @Get('requests')
  @Roles(UserRole.ADMIN)
  listRequests(@Query('status') status?: string) {
    return this.gamesService.listRequests(status);
  }

  @Patch('requests/:id/approve')
  @Roles(UserRole.ADMIN)
  approve(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ApproveGamesDto,
  ) {
    return this.gamesService.approve(user.id, id, dto);
  }

  @Patch('requests/:id/reject')
  @Roles(UserRole.ADMIN)
  reject(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectGamesDto,
  ) {
    return this.gamesService.reject(user.id, id, dto.reason);
  }

  // --- Dueño ---

  @Post('requests')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  request(@CurrentUser() user: AuthenticatedUser, @Body() dto: RequestGamesDto) {
    return this.gamesService.request(user, dto);
  }

  @Get('access/:businessId')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  access(
    @CurrentUser() user: AuthenticatedUser,
    @Param('businessId', ParseUUIDPipe) businessId: string,
  ) {
    return this.gamesService.getAccess(user, businessId);
  }

  @Post('invites')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  send(@CurrentUser() user: AuthenticatedUser, @Body() dto: SendGameDto) {
    return this.gamesService.sendInvites(user, dto);
  }

  @Get('sent/:businessId')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  sent(
    @CurrentUser() user: AuthenticatedUser,
    @Param('businessId', ParseUUIDPipe) businessId: string,
  ) {
    return this.gamesService.listSent(user, businessId);
  }

  // --- Cliente ---

  @Get('my-invites')
  @Roles(UserRole.CLIENT)
  myInvites(@CurrentUser() user: AuthenticatedUser) {
    return this.gamesService.myInvites(user.id);
  }

  @Get('invites/:id')
  @Roles(UserRole.CLIENT)
  invite(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.gamesService.getInvite(user.id, id);
  }

  @Post('invites/:id/start')
  @Roles(UserRole.CLIENT)
  start(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.gamesService.start(user.id, id);
  }

  @Post('invites/:id/guess')
  @Roles(UserRole.CLIENT)
  guess(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: GuessLetterDto,
  ) {
    return this.gamesService.guess(user.id, id, dto.letter);
  }

  @Post('invites/:id/move')
  @Roles(UserRole.CLIENT)
  move(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: TttMoveDto,
  ) {
    return this.gamesService.move(user.id, id, dto.cell);
  }

  @Post('invites/:id/finish')
  @Roles(UserRole.CLIENT)
  finish(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: FinishFlappyDto,
  ) {
    return this.gamesService.finishFlappy(user.id, id, dto);
  }
}
