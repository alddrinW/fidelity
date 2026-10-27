import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';

/** Qué pasa cuando el cliente toca el banner. */
export const BANNER_ACTIONS = ['none', 'invite', 'weekly_game', 'offers', 'scan', 'link'] as const;
export type BannerAction = (typeof BANNER_ACTIONS)[number];

/**
 * Un banner del inicio del cliente que sube el administrador: la imagen ya
 * diseñada (con su texto) y a dónde lleva al tocarla. El administrador decide cuáles
 * se ven, en qué orden y hasta cuándo.
 */
@Entity('banners')
@Index('idx_banners_active_position', ['isActive', 'position'])
export class Banner {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** Nombre para reconocerlo en el panel y para los lectores de pantalla. */
  @Column({ type: 'varchar', length: 80 })
  title: string;

  /** La imagen (URL o data URI base64), recomendada de 2000 × 648 px. */
  @Column({ name: 'image_url', type: 'text' })
  imageUrl: string;

  /** La misma imagen para quien usa la app en inglés (si no hay, se usa la principal). */
  @Column({ name: 'image_url_en', type: 'text', nullable: true })
  imageUrlEn: string | null;

  @Column({ type: 'varchar', length: 20, default: 'none' })
  action: BannerAction;

  /** Solo con la acción `link`: la dirección que se abre. */
  @Column({ name: 'link_url', type: 'text', nullable: true })
  linkUrl: string | null;

  /** Con `true`, los bordes de la imagen se funden con el fondo blanco de la pantalla. */
  @Column({ name: 'blend_white', type: 'boolean', default: true })
  blendWhite: boolean;

  /** Orden en el carrusel (de menor a mayor). */
  @Column({ type: 'int', default: 0 })
  position: number;

  @Column({ name: 'is_active', type: 'boolean', default: true })
  isActive: boolean;

  /** Desde cuándo se ve (vacío = ya). */
  @Column({ name: 'starts_at', type: 'timestamptz', nullable: true })
  startsAt: Date | null;

  /** Hasta cuándo se ve (vacío = sin fin). */
  @Column({ name: 'ends_at', type: 'timestamptz', nullable: true })
  endsAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
