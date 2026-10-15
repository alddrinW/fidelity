import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Profile } from './profile.entity';
import { Business } from './business.entity';

/** Rol que un colaborador tiene dentro de un negocio. */
export enum BusinessMemberRole {
  /**
   * Supervisor del local: aprueba o rechaza escaneos, valida la entrega de
   * premios y modera las opiniones de los clientes. No edita el negocio ni ve
   * pagos, QR o estadísticas.
   */
  APPROVER = 'approver',
}

/** Colaborador asignado por el dueño a un negocio. */
@Entity('business_members')
@Unique('uq_business_member', ['businessId', 'userId'])
export class BusinessMember {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'business_id', type: 'uuid', nullable: false })
  businessId: string;

  @ManyToOne(() => Business, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'business_id' })
  business: Business;

  @Column({ name: 'user_id', type: 'uuid', nullable: false })
  userId: string;

  @ManyToOne(() => Profile, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: Profile;

  @Column({ type: 'varchar', length: 20, default: BusinessMemberRole.APPROVER })
  role: BusinessMemberRole;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
