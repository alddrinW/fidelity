import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';

export enum UserRole {
  ADMIN = 'admin',
  BUSINESS = 'business',
  CLIENT = 'client',
  /** Supervisor de un local (asignado por su dueño): aprueba escaneos y premios. */
  APPROVER = 'approver',
}

@Entity('profiles')
export class Profile {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true, nullable: false })
  email: string;

  @Column({ name: 'full_name', nullable: true })
  fullName: string;

  @Column({
    type: 'varchar',
    length: 20,
    default: UserRole.CLIENT,
  })
  role: UserRole;

  @Column({ name: 'password_hash', nullable: true, select: false })
  passwordHash: string;

  @Column({ name: 'fcm_token', type: 'text', nullable: true })
  fcmToken: string;

  @Column({ name: 'avatar_url', type: 'text', nullable: true })
  avatarUrl: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  phone: string;

  @Column({ name: 'is_demo', type: 'boolean', default: false })
  isDemo: boolean;

  /**
   * Fecha de nacimiento (`AAAA-MM-DD`), opcional. Solo el día y el mes se
   * comparten con los locales donde el cliente tiene tarjeta, para su regalo.
   */
  @Column({ name: 'birth_date', type: 'date', nullable: true })
  birthDate: string | null;

  /**
   * Si ya vio el mensaje de bienvenida de su primera entrada. Se guarda aquí (y
   * no solo en el teléfono) para que no vuelva a salir al iniciar sesión de
   * nuevo ni desde otro dispositivo.
   */
  @Column({ name: 'has_seen_welcome', type: 'boolean', default: false })
  hasSeenWelcome: boolean;

  /** Su código para invitar amigos a la app (se crea la primera vez que lo pide). */
  @Column({ name: 'referral_code', type: 'varchar', length: 12, nullable: true, unique: true })
  referralCode: string | null;

  /** Puntos de invitación que ganó y todavía no usa: los gasta en el local que elija. */
  @Column({ name: 'referral_balance', type: 'int', default: 0 })
  referralBalance: number;

  /** Cuántos grupos de amigos ya le pagaron a quien invita (para no pagar dos veces el mismo). */
  @Column({ name: 'referral_groups_paid', type: 'int', default: 0 })
  referralGroupsPaid: number;

  /** Idioma de la app del usuario (`es` o `en`): los avisos del servidor salen en él. */
  @Column({ type: 'varchar', length: 5, default: 'es' })
  language: string;

  /** Código de recuperación de contraseña (solo su hash) y cuándo vence. */
  @Column({ name: 'reset_code_hash', type: 'varchar', length: 100, nullable: true, select: false })
  resetCodeHash: string | null;

  @Column({ name: 'reset_code_expires_at', type: 'timestamptz', nullable: true, select: false })
  resetCodeExpiresAt: Date | null;

  /** Intentos fallidos con el código vigente. */
  @Column({ name: 'reset_attempts', type: 'int', default: 0, select: false })
  resetAttempts: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
