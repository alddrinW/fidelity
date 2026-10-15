import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { IsEmail } from 'class-validator';
import { BusinessMembersService } from './business-members.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { UserRole } from '../../database/entities/profile.entity';

export class AddMemberDto {
  @IsEmail({}, { message: 'El correo electronico debe ser valido' })
  email: string;
}

/** Equipo de un negocio (rol Aprobador). Solo el dueño o un administrador. */
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.BUSINESS, UserRole.ADMIN)
@Controller('businesses/:businessId/members')
export class BusinessMembersController {
  constructor(private readonly membersService: BusinessMembersService) {}

  @Get()
  list(
    @CurrentUser() user: AuthenticatedUser,
    @Param('businessId', ParseUUIDPipe) businessId: string,
  ) {
    return this.membersService.list(businessId, user);
  }

  @Post()
  add(
    @CurrentUser() user: AuthenticatedUser,
    @Param('businessId', ParseUUIDPipe) businessId: string,
    @Body() dto: AddMemberDto,
  ) {
    return this.membersService.add(businessId, user, dto.email);
  }

  @Delete(':userId')
  remove(
    @CurrentUser() user: AuthenticatedUser,
    @Param('businessId', ParseUUIDPipe) businessId: string,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.membersService.remove(businessId, userId, user);
  }
}
