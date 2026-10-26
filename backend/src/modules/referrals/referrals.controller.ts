import {
  Body,
  Controller,
  Get,
  Header,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import {
  RedeemReferralDto,
  SetReferralBusinessDto,
  SetReferralBusinessesDto,
  UseReferralPointsDto,
} from './dto/referrals.dto';
import { invitePage } from './invite-page';
import { normalizeReferralCode, ReferralsService } from './referrals.service';

/** Lo del cliente: su código, sus puntos de invitación y en qué local usarlos. */
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CLIENT)
@Controller('referrals')
export class ReferralsController {
  constructor(private readonly referralsService: ReferralsService) {}

  /** Mi código y mi enlace para invitar, mis puntos de invitación y cuántos amigos ya vinieron. */
  @Get('me')
  me(@CurrentUser() user: AuthenticatedUser) {
    return this.referralsService.me(user.id);
  }

  /** Los locales donde puedo usar mis puntos de invitación. */
  @Get('locals')
  locals(@CurrentUser() user: AuthenticatedUser) {
    return this.referralsService.eligibleLocals(user.id);
  }

  /** Usar mis puntos de invitación en el local que elijo. */
  @Post('use')
  use(@CurrentUser() user: AuthenticatedUser, @Body() dto: UseReferralPointsDto) {
    return this.referralsService.use(user.id, dto.businessId, dto.points ?? 1);
  }

  /** Usar el código de un amigo (para quien ya tiene cuenta). */
  @Post('redeem')
  redeem(@CurrentUser() user: AuthenticatedUser, @Body() dto: RedeemReferralDto) {
    return this.referralsService.redeem(user.id, dto.code);
  }
}

/** Lo del administrador: qué locales participan. */
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@Controller('referrals/admin')
export class ReferralsAdminController {
  constructor(private readonly referralsService: ReferralsService) {}

  /** Los locales activos con su marca de participación. */
  @Get('businesses')
  businesses(@Query('q') q?: string) {
    return this.referralsService.adminBusinesses(q);
  }

  /** Marcar o desmarcar varios locales de una vez. */
  @Put('businesses')
  setMany(@Body() dto: SetReferralBusinessesDto) {
    return this.referralsService.setManyEnabled(dto.ids, dto.enabled);
  }

  /** Marcar o desmarcar un local. */
  @Patch('businesses/:id')
  setOne(@Param('id', ParseUUIDPipe) id: string, @Body() dto: SetReferralBusinessDto) {
    return this.referralsService.setBusinessEnabled(id, dto.enabled);
  }
}

/**
 * El enlace de invitación que se comparte. Es público (lo abre quien recibe el
 * enlace, sin cuenta): solo muestra el código y botones para abrir o descargar la app.
 */
@Controller('invite')
export class InviteLandingController {
  constructor(
    private readonly referralsService: ReferralsService,
    private readonly config: ConfigService,
    @InjectRepository(Profile)
    private readonly profileRepository: Repository<Profile>,
  ) {}

  @Get(':code')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  async landing(@Param('code') raw: string) {
    const code = normalizeReferralCode(raw);
    const owner = code ? await this.profileRepository.findOne({ where: { referralCode: code }, select: ['id'] }) : null;
    const rules = await this.referralsService.rules();
    return invitePage({
      code: owner && rules.enabled ? code : null,
      friendPoints: rules.friendPoints,
      webUrl: this.config.get<string>('referrals.webUrl'),
      playStoreUrl: this.config.get<string>('referrals.playStoreUrl'),
      appStoreUrl: this.config.get<string>('referrals.appStoreUrl'),
    });
  }
}
