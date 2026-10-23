import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppSetting } from '../../database/entities/app-setting.entity';
import { SettingsController } from './settings.controller';
import { SettingsService } from './settings.service';

/** Global: cualquier servicio puede leer los ajustes que fija el administrador. */
@Global()
@Module({
  imports: [TypeOrmModule.forFeature([AppSetting])],
  controllers: [SettingsController],
  providers: [SettingsService],
  exports: [SettingsService],
})
export class SettingsModule {}
