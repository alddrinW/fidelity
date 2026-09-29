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
import { LoyaltyCard } from './loyalty-card.entity';

export enum RewardStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  CLAIMED = 'claimed',
  REJECTED = 'rejected',
}

@Entity('rewards')
export class Reward {
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

  @Column({ name: 'loyalty_card_id', type: 'uuid', nullable: false })
  loyaltyCardId: string;

  @ManyToOne(() => LoyaltyCard, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'loyalty_card_id' })
  loyaltyCard: LoyaltyCard;

  @Column({ name: 'reward_description', type: 'text', nullable: true })
  rewardDescription: string;

  @Column({ name: 'description', type: 'text', nullable: true })
  description: string;

  @Column({ name: 'points_used', type: 'int', default: 10 })
  pointsUsed: number;

  @Column({
    type: 'varchar',
    length: 20,
    default: RewardStatus.PENDING,
  })
  status: RewardStatus;

  @Column({ name: 'is_demo', type: 'boolean', default: false })
  isDemo: boolean;

  @CreateDateColumn({ name: 'earned_at' })
  earnedAt: Date;

  @Column({ name: 'claimed_at', type: 'timestamp with time zone', nullable: true })
  claimedAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
