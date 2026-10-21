import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Profile } from './profile.entity';
import { Business } from './business.entity';
import { QrCode } from './qr-code.entity';

@Entity('scan_attempts')
@Index('idx_scan_attempts_created', ['createdAt'])
export class ScanAttempt {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid', nullable: false })
  userId: string;

  @ManyToOne(() => Profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: Profile;

  @Column({ name: 'business_id', type: 'uuid', nullable: true })
  businessId: string;

  @ManyToOne(() => Business, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'business_id' })
  business: Business;

  @Column({ name: 'qr_code_id', type: 'uuid', nullable: true })
  qrCodeId: string;

  @ManyToOne(() => QrCode, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'qr_code_id' })
  qrCode: QrCode;

  @Column({ type: 'boolean', default: false })
  success: boolean;

  @Column({ name: 'failure_reason', type: 'varchar', length: 100, nullable: true })
  failureReason: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
