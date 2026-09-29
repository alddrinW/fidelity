import {
  Controller,
  Post,
  Get,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ScansService } from './scans.service';
import { ValidateScanDto, AddManualPointsDto, UpdateScanStatusDto } from './dto/scans.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { ScanStatus } from '../../database/entities/scan.entity';
import { Roles } from '../../common/decorators/roles.decorator';
import { RolesGuard } from '../../common/guards/roles.guard';
import { UserRole } from '../../database/entities/profile.entity';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('scans')
export class ScansController {
  constructor(private readonly scansService: ScansService) {}

  @Post('validate')
  @HttpCode(HttpStatus.OK)
  async validateScan(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: ValidateScanDto,
  ) {
    return this.scansService.validateScan(user.id, dto);
  }

  @Post('manual-points')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  async addManualPoints(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: AddManualPointsDto,
  ) {
    return this.scansService.addManualPoints(user.id, user.role, dto);
  }

  @Get('business/:businessId')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  async getBusinessScans(
    @CurrentUser() user: AuthenticatedUser,
    @Param('businessId') businessId: string,
    @Query('status') status?: ScanStatus,
  ) {
    return this.scansService.getBusinessScans(businessId, user.id, user.role, status);
  }

  @Patch(':id/status')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  async updateScanStatus(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') scanId: string,
    @Body() dto: UpdateScanStatusDto,
  ) {
    return this.scansService.updateScanStatus(scanId, user.id, user.role, dto);
  }
}
