import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Business } from './business.entity';
import { Profile } from './profile.entity';

export type GameInviteStatus = 'sent' | 'playing' | 'finished';
export type GameResult = 'won' | 'lost';

/**
 * Un juego que el dueño le manda a un cliente, con su horario (`startsAt` a
 * `expiresAt`) y hasta 3 intentos para ganar. El estado de la partida vive aquí
 * (en el servidor), así el cliente no puede adelantarse ni hacer trampa.
 */
@Entity('game_invites')
@Index('idx_game_invites_user_created', ['userId', 'createdAt'])
@Index('idx_game_invites_expires', ['expiresAt'])
// Un cliente tiene como máximo un juego semanal por semana.
@Index('uq_game_invites_weekly', ['userId', 'weekStart'], { unique: true, where: '"weekly" = true' })
export class GameInvite {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'business_id', type: 'uuid', nullable: false })
  businessId: string;

  @ManyToOne(() => Business, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'business_id' })
  business: Business;

  @Column({ name: 'user_id', type: 'uuid', nullable: false })
  userId: string;

  @ManyToOne(() => Profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: Profile;

  @Column({ name: 'sent_by_id', type: 'uuid', nullable: true })
  sentById: string | null;

  @Column({ type: 'varchar', length: 20 })
  game: string;

  @Column({ type: 'varchar', length: 20, default: 'sent' })
  status: GameInviteStatus;

  @Column({ type: 'varchar', length: 10, nullable: true })
  result: GameResult | null;

  @Column({ type: 'int', nullable: true })
  score: number | null;

  /** Estado de la partida (la palabra del ahorcado, el tablero...). */
  @Column({ type: 'jsonb', nullable: true })
  state: Record<string, any> | null;

  /**
   * Es el juego semanal de Fidelity (el cliente lo empieza eligiendo un negocio
   * y, si gana, suma un punto ahí), no un juego que mandó un dueño.
   */
  @Column({ type: 'boolean', default: false })
  weekly: boolean;

  /** Juego semanal: el lunes de su semana (hora de Ecuador), `AAAA-MM-DD`. */
  @Column({ name: 'week_start', type: 'date', nullable: true })
  weekStart: string | null;

  /** Gift card que ganó (si ganó y era la primera vez). */
  @Column({ name: 'claim_id', type: 'uuid', nullable: true })
  claimId: string | null;

  /** Desde cuándo se puede jugar (la fija el dueño al enviarlo). */
  @Column({ name: 'starts_at', type: 'timestamptz', default: () => 'NOW()' })
  startsAt: Date;

  /** Hasta cuándo se puede jugar (la fija el dueño al enviarlo). */
  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt: Date;

  /** Intentos que el cliente ya empezó (hasta MAX_GAME_ATTEMPTS). */
  @Column({ type: 'int', default: 0 })
  attempts: number;

  /** Cuándo se le avisó al cliente que ya puede jugar (null = aún no). */
  @Column({ name: 'notified_at', type: 'timestamptz', nullable: true })
  notifiedAt: Date | null;

  @Column({ name: 'started_at', type: 'timestamptz', nullable: true })
  startedAt: Date | null;

  @Column({ name: 'finished_at', type: 'timestamptz', nullable: true })
  finishedAt: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
