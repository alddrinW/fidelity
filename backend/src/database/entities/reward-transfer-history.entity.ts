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
import { Reward } from './reward.entity';

@Entity('reward_transfer_history')
export class RewardTransferHistory {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'reward_id', type: 'uuid', nullable: false })
  rewardId: string;

  @ManyToOne(() => Reward, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'reward_id' })
  reward: Reward;

  @Column({ name: 'business_id', type: 'uuid', nullable: false })
  businessId: string;

  @ManyToOne(() => Business, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'business_id' })
  business: Business;

  @Column({ name: 'from_user_id', type: 'uuid', nullable: false })
  fromUserId: string;

  @ManyToOne(() => Profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'from_user_id' })
  fromUser: Profile;

  @Column({ name: 'to_user_id', type: 'uuid', nullable: false })
  toUserId: string;

  @ManyToOne(() => Profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'to_user_id' })
  toUser: Profile;

  @CreateDateColumn({ name: 'transferred_at' })
  transferredAt: Date;
}
