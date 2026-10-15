import { Column, Entity, PrimaryColumn, UpdateDateColumn } from 'typeorm';

/**
 * Ajustes del sistema que el administrador cambia desde la app (por ahora, los
 * precios del registro). Sin valor guardado, se usa el de la configuración.
 */
@Entity('app_settings')
export class AppSetting {
  @PrimaryColumn({ type: 'varchar', length: 60 })
  key: string;

  @Column({ type: 'text' })
  value: string;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
