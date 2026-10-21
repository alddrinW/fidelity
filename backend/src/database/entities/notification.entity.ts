import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Profile } from './profile.entity';

/**
 * Una notificación de la bandeja de un usuario. Cada aviso que el sistema le
 * manda (escaneo aprobado, premio, gift card, pago...) queda guardado aquí
 * aunque el push no llegue, para que pueda revisar todos sus movimientos.
 */
@Entity('notifications')
@Index('idx_notifications_user_created', ['userId', 'createdAt'])
@Index('idx_notifications_created', ['createdAt'])
export class Notification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid', nullable: false })
  userId: string;

  @ManyToOne(() => Profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: Profile;

  /** Clase de movimiento (`gift_card`, `claim_redeemed`, `business_activated`...). */
  @Column({ type: 'varchar', length: 40, default: 'general' })
  type: string;

  @Column({ type: 'varchar', length: 160 })
  title: string;

  @Column({ type: 'text' })
  body: string;

  /** Datos extra para abrir el movimiento (ruta, ids). */
  @Column({ type: 'jsonb', nullable: true })
  data: Record<string, string> | null;

  @Column({ name: 'read_at', type: 'timestamptz', nullable: true })
  readAt: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
