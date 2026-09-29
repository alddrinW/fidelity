import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { RewardsService } from './rewards.service';
import { UpdateRewardStatusDto, TransferRewardDto } from './dto/rewards.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { RewardStatus } from '../../database/entities/reward.entity';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../database/entities/profile.entity';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('rewards')
export class RewardsController {
  constructor(private readonly rewardsService: RewardsService) {}

  @Get('my-rewards')
  async getMyRewards(
    @CurrentUser() user: AuthenticatedUser,
    @Query('status') status?: RewardStatus,
  ) {
    return this.rewardsService.getUserRewards(user.id, status);
  }

  @Get('business/:businessId')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  async getBusinessRewards(
    @CurrentUser() user: AuthenticatedUser,
    @Param('businessId') businessId: string,
    @Query('status') status?: RewardStatus,
  ) {
    return this.rewardsService.getBusinessRewards(businessId, user.id, user.role, status);
  }

  @Patch(':id/status')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  async updateRewardStatus(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') rewardId: string,
    @Body() dto: UpdateRewardStatusDto,
  ) {
    return this.rewardsService.updateRewardStatus(rewardId, user.id, user.role, dto);
  }

  @Post('transfer')
  @HttpCode(HttpStatus.OK)
  async transferReward(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: TransferRewardDto,
  ) {
    return this.rewardsService.transferReward(user.id, dto);
  }

  @Get('transfers')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  async getTransfers(@Query('businessId') businessId?: string) {
    return this.rewardsService.getTransferHistory(businessId);
  }
}
