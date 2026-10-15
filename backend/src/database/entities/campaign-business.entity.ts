import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, Unique } from 'typeorm';
import { Campaign } from './campaign.entity';
import { Business } from './business.entity';

/** Negocio (o sucursal) que participa en una campaña. */
@Entity('campaign_businesses')
@Unique('uq_campaign_business', ['campaignId', 'businessId'])
export class CampaignBusiness {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'campaign_id', type: 'uuid', nullable: false })
  campaignId: string;

  @ManyToOne(() => Campaign, (c) => c.participants, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'campaign_id' })
  campaign: Campaign;

  @Column({ name: 'business_id', type: 'uuid', nullable: false })
  businessId: string;

  @ManyToOne(() => Business, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'business_id' })
  business: Business;
}
