import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  UseGuards,
} from '@nestjs/common';
import { LoyaltyCardsService } from './loyalty-cards.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';

@UseGuards(JwtAuthGuard)
@Controller('loyalty-cards')
export class LoyaltyCardsController {
  constructor(private readonly cardsService: LoyaltyCardsService) {}

  @Get('my-cards')
  async getMyCards(@CurrentUser() user: AuthenticatedUser) {
    return this.cardsService.getUserCards(user.id);
  }

  @Post('get-or-create/:businessId')
  async getOrCreateCard(
    @CurrentUser() user: AuthenticatedUser,
    @Param('businessId') businessId: string,
  ) {
    return this.cardsService.getOrCreateLoyaltyCard(user.id, businessId);
  }

  @Get('business/:businessId')
  async getBusinessCards(
    @CurrentUser() user: AuthenticatedUser,
    @Param('businessId') businessId: string,
  ) {
    return this.cardsService.getBusinessCards(businessId, user.id, user.role);
  }

  @Get(':id/history')
  async getCardHistory(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') cardId: string,
  ) {
    return this.cardsService.getCardHistory(cardId, user.id, user.role);
  }
}
