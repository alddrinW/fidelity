import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Campaign } from './campaign.entity';
import { Profile } from './profile.entity';

export enum ClaimStatus {
  /** Vigente: el cliente aún no lo usa. */
  ACTIVE = 'active',
  /** Ya canjeado en el local. */
  REDEEMED = 'redeemed',
}

export enum ClaimSource {
  /** El cliente reclamó la tarjeta de regalo. */
  CLAIM = 'claim',
  /** Premio por completar una ruta (pasaporte). */
  ROUTE_COMPLETE = 'route_complete',
  /** Premio de un reto de escaneos completado. */
  CHALLENGE_COMPLETE = 'challenge_complete',
  /** El cliente compró la tarjeta (con PayPhone). */
  PURCHASE = 'purchase',
}

/**
 * Tarjeta de regalo o premio de ruta de un cliente. Lleva un código que el
 * local canjea. Cada cliente tiene a lo sumo uno por campaña.
 */
@Entity('campaign_claims')
@Unique('uq_campaign_claim_user', ['campaignId', 'userId'])
export class CampaignClaim {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'campaign_id', type: 'uuid', nullable: false })
  campaignId: string;

  @ManyToOne(() => Campaign, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'campaign_id' })
  campaign: Campaign;

  @Column({ name: 'user_id', type: 'uuid', nullable: false })
  userId: string;

  @ManyToOne(() => Profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: Profile;

  @Column({ type: 'varchar', length: 20, unique: true })
  code: string;

  @Column({ type: 'varchar', length: 20, default: ClaimStatus.ACTIVE })
  status: ClaimStatus;

  @Column({ type: 'varchar', length: 20, default: ClaimSource.CLAIM })
  source: ClaimSource;

  /** Tarjetas compradas: hasta cuándo vale. Las demás vencen con su campaña. */
  @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
  expiresAt: Date | null;

  @Column({ name: 'redeemed_by_id', type: 'uuid', nullable: true })
  redeemedById: string | null;

  @Column({ name: 'redeemed_at', type: 'timestamptz', nullable: true })
  redeemedAt: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
