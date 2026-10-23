import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { IsObject } from 'class-validator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../../database/entities/profile.entity';
import { SettingsPatch, SettingsService } from './settings.service';

export class UpdateSettingsDto {
  /** `{ "game_max_attempts": 5, "branch_fee": null }`; null vuelve al valor por defecto. */
  @IsObject({ message: 'Envía los ajustes a cambiar' })
  values: SettingsPatch;
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@Controller('settings')
export class SettingsController {
  constructor(private readonly settingsService: SettingsService) {}

  @Get()
  list() {
    return this.settingsService.view();
  }

  @Patch()
  update(@Body() dto: UpdateSettingsDto) {
    return this.settingsService.update(dto.values);
  }
}
