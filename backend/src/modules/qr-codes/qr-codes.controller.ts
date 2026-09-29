import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { QrCodesService } from './qr-codes.service';
import { CreateQrCodeDto, ToggleQrCodeDto, UpdateQrCodeDto } from './dto/qr-codes.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { UserRole } from '../../database/entities/profile.entity';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('qr-codes')
export class QrCodesController {
  constructor(private readonly qrService: QrCodesService) {}

  @Post()
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  async createQrCode(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateQrCodeDto,
  ) {
    return this.qrService.createQrCode(user.id, user.role, dto);
  }

  @Get('business/:businessId')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  async getBusinessQrCodes(
    @CurrentUser() user: AuthenticatedUser,
    @Param('businessId') businessId: string,
  ) {
    return this.qrService.getBusinessQrCodes(businessId, user.id, user.role);
  }

  @Patch(':id')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  async updateQrCode(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') qrId: string,
    @Body() dto: UpdateQrCodeDto,
  ) {
    return this.qrService.updateQrCode(qrId, user.id, user.role, dto);
  }

  @Patch(':id/status')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  async toggleQrCode(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') qrId: string,
    @Body() dto: ToggleQrCodeDto,
  ) {
    return this.qrService.toggleQrCode(qrId, user.id, user.role, dto);
  }

  @Get(':id/stats')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  async getQrStats(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') qrId: string,
  ) {
    return this.qrService.getQrStats(qrId, user.id, user.role);
  }
}
