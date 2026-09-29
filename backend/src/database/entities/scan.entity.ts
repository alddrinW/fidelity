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
import { QrCode } from './qr-code.entity';

export enum ScanStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

@Entity('scans')
export class Scan {
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

  @Column({ name: 'qr_code_id', type: 'uuid', nullable: true })
  qrCodeId: string;

  @ManyToOne(() => QrCode, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'qr_code_id' })
  qrCode: QrCode;

  @Column({
    type: 'varchar',
    length: 20,
    default: ScanStatus.APPROVED,
  })
  status: ScanStatus;

  @Column({ name: 'is_demo', type: 'boolean', default: false })
  isDemo: boolean;

  @CreateDateColumn({ name: 'scanned_at' })
  scannedAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
