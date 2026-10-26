import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Business } from './business.entity';
import { Campaign } from './campaign.entity';
import { CampaignClaim } from './campaign-claim.entity';
import { Profile } from './profile.entity';

export enum CardPurchaseStatus {
  /** El cliente fue a pagar y aún no vuelve de PayPhone (reserva un cupo un rato). */
  PENDING = 'pending',
  /** PayPhone cobró y el servidor lo verificó: ya tiene su tarjeta. */
  PAID = 'paid',
  /** El cliente canceló, PayPhone no aprobó el cobro o la reserva venció. */
  FAILED = 'failed',
  /** PayPhone cobró pero el cliente ya tenía esa tarjeta: hay que devolverle el dinero. */
  REFUND_DUE = 'refund_due',
}

/**
 * La compra de una tarjeta en venta (una gift card con precio). El cobro lo
 * hace PayPhone y lo confirma el servidor. Fidelity retiene su comisión; el
 * resto se le paga al local cuando el cliente canjea la tarjeta.
 */
@Entity('card_purchases')
export class CardPurchase {
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

  /** El local que vende (y al que se le paga). */
  @Column({ name: 'business_id', type: 'uuid', nullable: false })
  businessId: string;

  @ManyToOne(() => Business, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'business_id' })
  business: Business;

  /** Lo que pagó el cliente, en centavos. */
  @Column({ name: 'amount_cents', type: 'int' })
  amountCents: number;

  /** Lo que se queda Fidelity, en centavos (se fija al comprar, con el % de ese momento). */
  @Column({ name: 'commission_cents', type: 'int', default: 0 })
  commissionCents: number;

  @Column({ type: 'varchar', length: 12, default: CardPurchaseStatus.PENDING })
  status: CardPurchaseStatus;

  /** Referencia que ve el cliente en su comprobante (p. ej. TJ-7K2M9Q). */
  @Column({ type: 'varchar', length: 12, unique: true })
  reference: string;

  /** Id único que se envía a PayPhone. */
  @Column({ name: 'gateway_client_tx_id', type: 'varchar', length: 20, unique: true })
  gatewayClientTxId: string;

  @Column({ name: 'gateway_pay_url', type: 'varchar', length: 300, nullable: true })
  gatewayPayUrl: string | null;

  @Column({ name: 'gateway_transaction_id', type: 'varchar', length: 40, nullable: true })
  gatewayTransactionId: string | null;

  @Column({ name: 'gateway_auth_code', type: 'varchar', length: 40, nullable: true })
  gatewayAuthCode: string | null;

  /** La tarjeta (gift card) que recibió al pagar. */
  @Column({ name: 'claim_id', type: 'uuid', nullable: true })
  claimId: string | null;

  @ManyToOne(() => CampaignClaim, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'claim_id' })
  claim: CampaignClaim | null;

  /** Hasta cuándo la compra pendiente guarda el cupo. */
  @Column({ name: 'reserved_until', type: 'timestamptz' })
  reservedUntil: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @Column({ name: 'paid_at', type: 'timestamptz', nullable: true })
  paidAt: Date | null;

  /** Cuándo el administrador le pagó al local lo que le tocaba por esta venta. */
  @Column({ name: 'settled_at', type: 'timestamptz', nullable: true })
  settledAt: Date | null;

  @Column({ name: 'settled_by_id', type: 'uuid', nullable: true })
  settledById: string | null;

  /** Referencia de la transferencia con la que se le pagó al local. */
  @Column({ name: 'settlement_note', type: 'varchar', length: 200, nullable: true })
  settlementNote: string | null;
}
