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

export enum PaymentConcept {
  /** Alta de un negocio nuevo (cuenta principal). */
  REGISTRATION = 'registration',
  /** Alta de una sucursal adicional de un negocio existente. */
  BRANCH = 'branch',
}

export enum PaymentStatus {
  /** Orden creada; el dueño aún no avisa que pagó. */
  PENDING = 'pending',
  /** El dueño avisó que pagó (con método y referencia); espera validación. */
  REPORTED = 'reported',
  /** El administrador validó el pago: la cuenta queda activa y hay comprobante. */
  PAID = 'paid',
  /** El administrador no pudo validar el pago; el dueño puede reportarlo de nuevo. */
  REJECTED = 'rejected',
}

export enum PaymentMethod {
  /** Pago con tarjeta en la pasarela de pago (enlace configurado). */
  CARD = 'card',
  TRANSFER = 'transfer',
  DEPOSIT = 'deposit',
  CASH = 'cash',
}

/**
 * Orden de pago por registrar un negocio o una sucursal. No hay pasarela de
 * pago: el dueño paga por fuera (transferencia, depósito, efectivo), lo
 * reporta y el administrador valida y activa la cuenta.
 */
@Entity('payments')
export class Payment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'business_id', type: 'uuid', nullable: false })
  businessId: string;

  @ManyToOne(() => Business, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'business_id' })
  business: Business;

  @Column({ name: 'owner_id', type: 'uuid', nullable: false })
  ownerId: string;

  @ManyToOne(() => Profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'owner_id' })
  owner: Profile;

  @Column({ type: 'varchar', length: 20, default: PaymentConcept.REGISTRATION })
  concept: PaymentConcept;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    transformer: { to: (v: number) => v, from: (v: string | null) => (v == null ? v : Number(v)) },
  })
  amount: number;

  @Column({ type: 'varchar', length: 3, default: 'USD' })
  currency: string;

  @Column({ type: 'varchar', length: 20, default: PaymentStatus.PENDING })
  status: PaymentStatus;

  /** Código que el dueño pone como referencia al pagar (p. ej. FID-7K2M9Q). */
  @Column({ type: 'varchar', length: 20, unique: true })
  reference: string;

  @Column({ type: 'varchar', length: 20, nullable: true })
  method: PaymentMethod | null;

  /** Número de transferencia/depósito u otro dato que ayude a validar. */
  @Column({ type: 'varchar', length: 200, nullable: true })
  note: string | null;

  /** Foto del comprobante de pago (data URI base64 o URL). */
  @Column({ name: 'proof_url', type: 'text', nullable: true })
  proofUrl: string | null;

  /** Motivo del rechazo o comentario del administrador. */
  @Column({ name: 'admin_note', type: 'varchar', length: 300, nullable: true })
  adminNote: string | null;

  @Column({ name: 'receipt_number', type: 'varchar', length: 30, nullable: true, unique: true })
  receiptNumber: string | null;

  @Column({ name: 'validated_by_id', type: 'uuid', nullable: true })
  validatedById: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @Column({ name: 'reported_at', type: 'timestamptz', nullable: true })
  reportedAt: Date | null;

  @Column({ name: 'paid_at', type: 'timestamptz', nullable: true })
  paidAt: Date | null;
}
