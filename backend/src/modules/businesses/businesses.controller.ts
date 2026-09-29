import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { BusinessesService } from './businesses.service';
import {
  CreateBusinessDto,
  UpdateBusinessDto,
  CreateCategoryDto,
  ToggleBusinessStatusDto,
} from './dto/businesses.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { UserRole } from '../../database/entities/profile.entity';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('businesses')
export class BusinessesController {
  constructor(private readonly businessesService: BusinessesService) {}

  // Categories
  @Public()
  @Get('categories')
  async getCategories() {
    return this.businessesService.getCategories();
  }

  @Roles(UserRole.ADMIN)
  @Post('categories')
  async createCategory(@Body() dto: CreateCategoryDto) {
    return this.businessesService.createCategory(dto);
  }

  @Roles(UserRole.ADMIN)
  @Delete('categories/:id')
  async deleteCategory(@Param('id') id: string) {
    return this.businessesService.deleteCategory(parseInt(id, 10));
  }

  // Businesses CRUD
  @Public()
  @Get()
  async getBusinesses(@Query('all') all?: string) {
    const activeOnly = all !== 'true';
    return this.businessesService.findAll(activeOnly);
  }

  @Get('my-businesses')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  async getMyBusinesses(@CurrentUser() user: AuthenticatedUser) {
    return this.businessesService.findByOwner(user.id);
  }

  @Public()
  @Get(':id')
  async getBusinessById(@Param('id') id: string) {
    return this.businessesService.findById(id);
  }

  @Post()
  @Roles(UserRole.BUSINESS, UserRole.CLIENT, UserRole.ADMIN)
  async createBusiness(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateBusinessDto,
  ) {
    return this.businessesService.createBusiness(user.id, dto);
  }

  @Put(':id')
  async updateBusiness(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateBusinessDto,
  ) {
    return this.businessesService.updateBusiness(id, user.id, user.role, dto);
  }

  @Patch(':id/status')
  @Roles(UserRole.ADMIN)
  async toggleStatus(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: ToggleBusinessStatusDto,
  ) {
    return this.businessesService.toggleStatus(id, dto.isActive, user.role);
  }

  @Get(':id/stats')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  async getStats(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.businessesService.getBusinessStats(id, user.id, user.role);
  }
}
