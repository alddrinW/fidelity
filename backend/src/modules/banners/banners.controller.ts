import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Put, Query, UseGuards } from '@nestjs/common';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { UserRole } from '../../database/entities/profile.entity';
import { BannersService } from './banners.service';
import { CreateBannerDto, ReorderBannersDto, UpdateBannerDto } from './dto/banners.dto';

/** Los banners del inicio: el cliente los ve; el administrador los sube y los ordena. */
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('banners')
export class BannersController {
  constructor(private readonly banners: BannersService) {}

  /** Los que ve el cliente ahora. `lang=en` trae la imagen en inglés cuando existe. */
  @Get()
  @Roles(UserRole.CLIENT)
  list(@Query('lang') lang?: string) {
    return this.banners.listPublic(lang);
  }

  @Get('admin')
  @Roles(UserRole.ADMIN)
  listAdmin() {
    return this.banners.listAdmin();
  }

  @Post('admin')
  @Roles(UserRole.ADMIN)
  create(@Body() dto: CreateBannerDto) {
    return this.banners.create(dto);
  }

  @Put('admin/order')
  @Roles(UserRole.ADMIN)
  reorder(@Body() dto: ReorderBannersDto) {
    return this.banners.reorder(dto.ids);
  }

  @Patch('admin/:id')
  @Roles(UserRole.ADMIN)
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateBannerDto) {
    return this.banners.update(id, dto);
  }

  @Delete('admin/:id')
  @Roles(UserRole.ADMIN)
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.banners.remove(id);
  }
}
