import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Profile } from './profile.entity';
import { Business } from './business.entity';

@Entity('loyalty_cards')
@Unique(['userId', 'businessId'])
export class LoyaltyCard {
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

  @Column({ name: 'current_points', type: 'int', default: 0 })
  currentPoints: number;

  @Column({ name: 'total_points_lifetime', type: 'int', default: 0 })
  totalPointsLifetime: number;

  @Column({ name: 'rewards_claimed', type: 'int', default: 0 })
  rewardsClaimed: number;

  @Column({ name: 'last_scan_at', type: 'timestamp with time zone', nullable: true })
  lastScanAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
