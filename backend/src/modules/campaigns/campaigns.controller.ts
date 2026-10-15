import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { CampaignsService } from './campaigns.service';
import { CreateCampaignDto, RedeemCodeDto, UpdateCampaignDto } from './dto/campaigns.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { UserRole } from '../../database/entities/profile.entity';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('campaigns')
export class CampaignsController {
  constructor(private readonly campaignsService: CampaignsService) {}

  // --- Cliente (rutas fijas primero: no deben confundirse con ':id') ---

  /** Novedades: campañas vigentes de los locales del cliente. */
  @Get('feed')
  @Roles(UserRole.CLIENT)
  feed(@CurrentUser() user: AuthenticatedUser) {
    return this.campaignsService.feed(user.id);
  }

  /** Tarjetas de regalo y premios de ruta del cliente. */
  @Get('claims/mine')
  @Roles(UserRole.CLIENT)
  myClaims(@CurrentUser() user: AuthenticatedUser) {
    return this.campaignsService.myClaims(user.id);
  }

  @Post(':id/claim')
  @Roles(UserRole.CLIENT)
  claim(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.campaignsService.claim(user.id, id);
  }

  // --- Dueño / aprobador / administrador ---

  @Get('mine')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  listMine(@CurrentUser() user: AuthenticatedUser) {
    return this.campaignsService.listMine(user);
  }

  @Post()
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateCampaignDto) {
    return this.campaignsService.create(user, dto);
  }

  /** El local canjea el código de una tarjeta de regalo o de un premio de ruta. */
  @Post('redeem')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN, UserRole.APPROVER)
  redeem(@CurrentUser() user: AuthenticatedUser, @Body() dto: RedeemCodeDto) {
    return this.campaignsService.redeem(user, dto.code);
  }

  @Get(':id/claims')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN, UserRole.APPROVER)
  claims(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.campaignsService.claimsForCampaign(id, user);
  }

  @Patch(':id')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCampaignDto,
  ) {
    return this.campaignsService.update(id, user, dto);
  }

  @Patch(':id/cancel')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  cancel(@CurrentUser() user: AuthenticatedUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.campaignsService.cancel(id, user);
  }
}
