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
import { Business } from './business.entity';

/**
 * Sello de un cliente en un local de una ruta. Se otorga cuando un escaneo
 * suyo es aprobado en un negocio participante mientras la ruta está vigente.
 * Hay a lo sumo un sello por local en cada ruta.
 */
@Entity('campaign_stamps')
@Unique('uq_campaign_stamp', ['campaignId', 'userId', 'businessId'])
export class CampaignStamp {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'campaign_id', type: 'uuid', nullable: false })
  campaignId: string;

  @ManyToOne(() => Campaign, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'campaign_id' })
  campaign: Campaign;

  @Column({ name: 'user_id', type: 'uuid', nullable: false })
  userId: string;

  @Column({ name: 'business_id', type: 'uuid', nullable: false })
  businessId: string;

  @ManyToOne(() => Business, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'business_id' })
  business: Business;

  @Column({ name: 'scan_id', type: 'uuid', nullable: true })
  scanId: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
