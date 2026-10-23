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

/**
 * El cumpleaños de un cliente en un local, en un año: guarda que ya se le avisó
 * al dueño (para no avisar dos veces) y si el dueño ya le regaló su gift card.
 */
@Entity('birthday_notices')
@Unique('uq_birthday_notice', ['businessId', 'userId', 'year'])
export class BirthdayNotice {
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

  /** Año del cumpleaños (el de la fecha en que se celebra, no el de nacimiento). */
  @Column({ type: 'int', nullable: false })
  year: number;

  /** Cuándo se le avisó al dueño; vacío si el dueño se adelantó y regaló antes del aviso. */
  @Column({ name: 'notified_at', type: 'timestamptz', nullable: true })
  notifiedAt: Date | null;

  @Column({ name: 'gifted_at', type: 'timestamptz', nullable: true })
  giftedAt: Date | null;

  /** La campaña de gift card con que se le regaló. */
  @Column({ name: 'gift_campaign_id', type: 'uuid', nullable: true })
  giftCampaignId: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
