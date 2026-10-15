import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { Business } from './business.entity';
import { CampaignBusiness } from './campaign-business.entity';

export enum CampaignType {
  /** Anuncio o evento para los clientes fidelizados (sin cupón). */
  EVENT = 'event',
  /** Tarjeta de regalo: descuento o mini premio que el cliente reclama. */
  GIFT_CARD = 'gift_card',
  /** Ruta tipo pasaporte: visitar varios locales para juntar sellos. */
  ROUTE = 'route',
}

export enum CampaignBenefit {
  DISCOUNT_PERCENT = 'discount_percent',
  MINI_PRIZE = 'mini_prize',
}

export type CampaignPhase = 'scheduled' | 'active' | 'ended' | 'cancelled';

/**
 * Campaña de un negocio (o de varias sucursales del mismo dueño). Se puede
 * programar: empieza en `startsAt` y termina en `endsAt` (opcional). Llega a
 * los clientes con tarjeta en alguno de los negocios participantes.
 */
@Entity('campaigns')
export class Campaign {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Negocio que la creó (el primero de los participantes). */
  @Column({ name: 'business_id', type: 'uuid', nullable: false })
  businessId: string;

  @ManyToOne(() => Business, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'business_id' })
  business: Business;

  @Column({ type: 'varchar', length: 20 })
  type: CampaignType;

  @Column({ type: 'varchar', length: 120 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ name: 'image_url', type: 'text', nullable: true })
  imageUrl: string | null;

  @Column({ name: 'benefit_type', type: 'varchar', length: 20, nullable: true })
  benefitType: CampaignBenefit | null;

  /** Porcentaje de descuento (1-100) cuando `benefitType` es descuento. */
  @Column({ name: 'benefit_value', type: 'int', nullable: true })
  benefitValue: number | null;

  /** Texto del beneficio: "20% de descuento", "Café pequeño gratis". */
  @Column({ name: 'benefit_label', type: 'varchar', length: 120, nullable: true })
  benefitLabel: string | null;

  /** Sellos necesarios para completar una ruta. */
  @Column({ name: 'required_stamps', type: 'int', nullable: true })
  requiredStamps: number | null;

  @Column({ name: 'starts_at', type: 'timestamptz' })
  startsAt: Date;

  @Column({ name: 'ends_at', type: 'timestamptz', nullable: true })
  endsAt: Date | null;

  @Column({ name: 'cancelled_at', type: 'timestamptz', nullable: true })
  cancelledAt: Date | null;

  /** Cuándo se avisó a los clientes de que la campaña empezó. */
  @Column({ name: 'notified_at', type: 'timestamptz', nullable: true })
  notifiedAt: Date | null;

  @OneToMany(() => CampaignBusiness, (p) => p.campaign)
  participants: CampaignBusiness[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}

/** Estado de una campaña en el instante [now], según sus fechas. */
export function campaignPhase(
  campaign: Pick<Campaign, 'startsAt' | 'endsAt' | 'cancelledAt'>,
  now: Date = new Date(),
): CampaignPhase {
  if (campaign.cancelledAt) return 'cancelled';
  if (new Date(campaign.startsAt) > now) return 'scheduled';
  if (campaign.endsAt && new Date(campaign.endsAt) <= now) return 'ended';
  return 'active';
}
