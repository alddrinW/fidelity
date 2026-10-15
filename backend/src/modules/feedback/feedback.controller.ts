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
import { FeedbackService } from './feedback.service';
import { CreateFeedbackDto, FeedbackFilterDto, ResolveFeedbackDto } from './dto/feedback.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { UserRole } from '../../database/entities/profile.entity';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('feedback')
export class FeedbackController {
  constructor(private readonly feedbackService: FeedbackService) {}

  /** El cliente envía una calificación, sugerencia o reclamo de un local. */
  @Post()
  @Roles(UserRole.CLIENT)
  create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateFeedbackDto) {
    return this.feedbackService.create(user.id, dto);
  }

  @Get('mine')
  @Roles(UserRole.CLIENT)
  listMine(@CurrentUser() user: AuthenticatedUser) {
    return this.feedbackService.listMine(user.id);
  }

  @Get()
  @Roles(UserRole.ADMIN)
  listAll(@Query() filter: FeedbackFilterDto) {
    return this.feedbackService.listAll(filter);
  }

  @Get('business/:businessId')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN, UserRole.APPROVER)
  listForBusiness(
    @CurrentUser() user: AuthenticatedUser,
    @Param('businessId', ParseUUIDPipe) businessId: string,
    @Query() filter: FeedbackFilterDto,
  ) {
    return this.feedbackService.listForBusiness(businessId, user, filter);
  }

  @Patch(':id/resolve')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN, UserRole.APPROVER)
  resolve(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ResolveFeedbackDto,
  ) {
    return this.feedbackService.resolve(id, user, dto.reply);
  }
}
