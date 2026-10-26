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

export type ReferralStatus = 'pending' | 'rewarded';

/**
 * Un amigo que llegó a Fidelity con el código de otro cliente. Queda `pending`
 * hasta que un local le aprueba su primer escaneo; entonces los dos reciben sus
 * puntos de invitación y pasa a `rewarded`. Cada persona solo puede llegar por
 * invitación una vez.
 */
@Entity('referrals')
@Unique('uq_referral_friend', ['refereeId'])
export class Referral {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Quien invita (su código). */
  @Column({ name: 'referrer_id', type: 'uuid', nullable: false })
  referrerId: string;

  @ManyToOne(() => Profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'referrer_id' })
  referrer: Profile;

  /** El amigo que usó el código. */
  @Column({ name: 'referee_id', type: 'uuid', nullable: false })
  refereeId: string;

  @ManyToOne(() => Profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'referee_id' })
  referee: Profile;

  @Column({ type: 'varchar', length: 12, default: 'pending' })
  status: ReferralStatus;

  /** Los puntos que se dieron (los de ese momento, por si el administrador los cambia después). */
  @Column({ name: 'referrer_points', type: 'int', default: 0 })
  referrerPoints: number;

  @Column({ name: 'friend_points', type: 'int', default: 0 })
  friendPoints: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @Column({ name: 'rewarded_at', type: 'timestamptz', nullable: true })
  rewardedAt: Date | null;

  /**
   * Cuándo este amigo contó para la meta de quien invita (al registrarse con el
   * código o con su primer escaneo, según lo fije el administrador). Quien
   * invita gana sus puntos cada vez que junta los amigos que se piden.
   */
  @Column({ name: 'counted_at', type: 'timestamptz', nullable: true })
  countedAt: Date | null;
}

/** En qué local usó una persona sus puntos de invitación. */
@Entity('referral_uses')
export class ReferralUse {
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

  @Column({ type: 'int', nullable: false })
  points: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
