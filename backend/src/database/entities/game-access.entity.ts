import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { Business } from './business.entity';
import { Profile } from './profile.entity';

export type GameAccessStatus = 'pending' | 'approved' | 'rejected';

/**
 * Permiso de un negocio para usar los minijuegos. El dueño lo solicita y el
 * administrador lo aprueba: elige cuáles juegos le asigna y el premio que
 * ganan los clientes. Un negocio tiene a lo sumo uno.
 */
@Entity('game_access')
@Unique('uq_game_access_business', ['businessId'])
export class GameAccess {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'business_id', type: 'uuid', nullable: false })
  businessId: string;

  @ManyToOne(() => Business, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'business_id' })
  business: Business;

  @Column({ name: 'owner_id', type: 'uuid', nullable: false })
  ownerId: string;

  @ManyToOne(() => Profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'owner_id' })
  owner: Profile;

  @Column({ type: 'varchar', length: 20, default: 'pending' })
  status: GameAccessStatus;

  /** Mensaje del dueño al solicitar. */
  @Column({ type: 'varchar', length: 300, nullable: true })
  note: string | null;

  /** Motivo del rechazo. */
  @Column({ name: 'admin_note', type: 'varchar', length: 300, nullable: true })
  adminNote: string | null;

  /** Juegos asignados (`tictactoe`, `hangman`, `flappy`). */
  @Column('simple-array', { nullable: true })
  games: string[] | null;

  /** Premio que fija el administrador: descuento o mini premio. */
  @Column({ name: 'prize_type', type: 'varchar', length: 20, nullable: true })
  prizeType: 'discount_percent' | 'mini_prize' | null;

  @Column({ name: 'prize_value', type: 'int', nullable: true })
  prizeValue: number | null;

  @Column({ name: 'prize_label', type: 'varchar', length: 120, nullable: true })
  prizeLabel: string | null;

  /** Gift card (campaña oculta) que entrega el premio de cada juego: { juego: id }. */
  @Column({ name: 'prize_campaigns', type: 'jsonb', nullable: true })
  prizeCampaigns: Record<string, string> | null;

  @CreateDateColumn({ name: 'requested_at' })
  requestedAt: Date;

  @Column({ name: 'resolved_at', type: 'timestamptz', nullable: true })
  resolvedAt: Date | null;

  @Column({ name: 'resolved_by_id', type: 'uuid', nullable: true })
  resolvedById: string | null;
}
