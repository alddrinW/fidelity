import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Profile } from './profile.entity';
import { Business } from './business.entity';

export enum FeedbackKind {
  SUGGESTION = 'suggestion',
  COMPLAINT = 'complaint',
  PRAISE = 'praise',
}

export enum FeedbackStatus {
  OPEN = 'open',
  RESOLVED = 'resolved',
}

/**
 * Opinión de un cliente sobre un local donde ya escaneó: calificación rápida
 * (1 = mal, 2 = regular, 3 = excelente), etiquetas de motivo y, si quiere, un
 * comentario. Las sugerencias y reclamos llegan al administrador y al dueño.
 */
@Entity('feedbacks')
export class Feedback {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid', nullable: false })
  userId: string;

  @ManyToOne(() => Profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: Profile;

  @Column({ name: 'business_id', type: 'uuid', nullable: false })
  businessId: string;

  @ManyToOne(() => Business, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'business_id' })
  business: Business;

  @Column({ type: 'varchar', length: 20, default: FeedbackKind.SUGGESTION })
  kind: FeedbackKind;

  @Column({ type: 'smallint', nullable: true })
  rating: number | null;

  @Column('text', { array: true, default: () => "'{}'" })
  tags: string[];

  @Column({ type: 'text', nullable: true })
  message: string | null;

  @Column({ type: 'varchar', length: 20, default: FeedbackStatus.OPEN })
  status: FeedbackStatus;

  /** Respuesta de quien resolvió el caso; se le muestra al cliente. */
  @Column({ type: 'text', nullable: true })
  reply: string | null;

  @Column({ name: 'resolved_by_id', type: 'uuid', nullable: true })
  resolvedById: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @Column({ name: 'resolved_at', type: 'timestamptz', nullable: true })
  resolvedAt: Date | null;
}
