import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { Profile } from './profile.entity';
import { BusinessCategory } from './business-category.entity';
import { LoyaltyCard } from './loyalty-card.entity';

@Entity('businesses')
export class Business {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'owner_id', type: 'uuid', nullable: false })
  ownerId: string;

  @ManyToOne(() => Profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'owner_id' })
  owner: Profile;

  @Column({ name: 'category_id', type: 'int', nullable: true })
  categoryId: number;

  @ManyToOne(() => BusinessCategory, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'category_id' })
  categoryRef: BusinessCategory;

  @Column({ type: 'varchar', length: 150, nullable: false })
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  category: string;

  @Column({ name: 'logo_url', type: 'text', nullable: true })
  logoUrl: string;

  @Column({
    name: 'reward_description',
    type: 'text',
    default: 'Premio Fidelity por puntos completados',
  })
  rewardDescription: string;

  @Column({ name: 'reward_long_description', type: 'text', nullable: true })
  rewardLongDescription: string;

  @Column({ name: 'points_required', type: 'int', default: 10 })
  pointsRequired: number;

  @Column({ name: 'cooldown_hours', type: 'int', default: 24 })
  cooldownHours: number;

  /**
   * Un negocio nuevo nace inactivo: el administrador lo activa cuando valida
   * el pago del registro. Mientras esté inactivo no se pueden escanear sus QR.
   */
  @Column({ name: 'is_active', type: 'boolean', default: false })
  isActive: boolean;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  latitude: number;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  longitude: number;

  @Column({ type: 'text', nullable: true })
  address: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  phone: string;

  /** Cedula (10 digitos) o RUC (13 digitos) del propietario. */
  @Column({ name: 'tax_id', type: 'varchar', length: 13, nullable: true })
  taxId: string;

  /**
   * Si este negocio es una sucursal, el negocio principal al que pertenece
   * (siempre del mismo dueño). Un negocio principal tiene `parentId = null`.
   */
  @Column({ name: 'parent_id', type: 'uuid', nullable: true })
  parentId: string | null;

  @ManyToOne(() => Business, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'parent_id' })
  parent: Business | null;

  @OneToMany(() => LoyaltyCard, (card) => card.business)
  loyaltyCards: LoyaltyCard[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
