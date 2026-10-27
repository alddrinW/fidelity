import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Banner, BannerAction } from '../../database/entities/banner.entity';
import { CreateBannerDto, UpdateBannerDto } from './dto/banners.dto';

/** Cuántos banners puede tener el administrador (cada imagen pesa hasta ~1 MB). */
export const MAX_BANNERS = 12;

/** Lo que ve el cliente de cada banner. */
export interface PublicBanner {
  id: string;
  title: string;
  imageUrl: string;
  action: BannerAction;
  linkUrl: string | null;
  blendWhite: boolean;
}

@Injectable()
export class BannersService {
  constructor(@InjectRepository(Banner) private readonly banners: Repository<Banner>) {}

  /** Los banners que el cliente ve ahora: activos, dentro de su horario y en orden. */
  async listPublic(lang?: string, now: Date = new Date()): Promise<PublicBanner[]> {
    const all = await this.banners.find({ where: { isActive: true }, order: { position: 'ASC', createdAt: 'ASC' } });
    return all
      .filter((b) => (!b.startsAt || b.startsAt <= now) && (!b.endsAt || b.endsAt > now))
      .map((b) => ({
        id: b.id,
        title: b.title,
        imageUrl: lang === 'en' && b.imageUrlEn ? b.imageUrlEn : b.imageUrl,
        action: b.action,
        linkUrl: b.action === 'link' ? b.linkUrl : null,
        blendWhite: b.blendWhite,
      }));
  }

  /** Todos, para el panel del administrador. */
  listAdmin(): Promise<Banner[]> {
    return this.banners.find({ order: { position: 'ASC', createdAt: 'ASC' } });
  }

  async create(dto: CreateBannerDto): Promise<Banner> {
    const total = await this.banners.count();
    if (total >= MAX_BANNERS) {
      throw new BadRequestException(`Puedes tener hasta ${MAX_BANNERS} banners. Elimina alguno para subir otro.`);
    }
    const action = dto.action ?? 'none';
    const linkUrl = this.linkFor(action, dto.linkUrl);
    this.checkWindow(dto.startsAt, dto.endsAt);

    const last = await this.banners.find({ order: { position: 'DESC' }, take: 1 });
    return this.banners.save(
      this.banners.create({
        title: dto.title.trim(),
        imageUrl: dto.imageUrl,
        imageUrlEn: dto.imageUrlEn || null,
        action,
        linkUrl,
        blendWhite: dto.blendWhite ?? true,
        isActive: dto.isActive ?? true,
        startsAt: dto.startsAt ?? null,
        endsAt: dto.endsAt ?? null,
        position: (last[0]?.position ?? -1) + 1,
      }),
    );
  }

  async update(id: string, dto: UpdateBannerDto): Promise<Banner> {
    const banner = await this.find(id);
    if (dto.title !== undefined) banner.title = dto.title.trim();
    if (dto.imageUrl !== undefined) banner.imageUrl = dto.imageUrl;
    if (dto.imageUrlEn !== undefined) banner.imageUrlEn = dto.imageUrlEn || null;
    if (dto.blendWhite !== undefined) banner.blendWhite = dto.blendWhite;
    if (dto.isActive !== undefined) banner.isActive = dto.isActive;
    if (dto.startsAt !== undefined) banner.startsAt = dto.startsAt;
    if (dto.endsAt !== undefined) banner.endsAt = dto.endsAt;
    if (dto.action !== undefined) banner.action = dto.action;
    if (dto.action !== undefined || dto.linkUrl !== undefined) {
      banner.linkUrl = this.linkFor(banner.action, dto.linkUrl !== undefined ? dto.linkUrl : banner.linkUrl);
    }
    this.checkWindow(banner.startsAt, banner.endsAt);
    return this.banners.save(banner);
  }

  async remove(id: string): Promise<{ deleted: true }> {
    const banner = await this.find(id);
    await this.banners.remove(banner);
    return { deleted: true };
  }

  /** Guarda el orden que eligió el administrador (los que no vengan en la lista quedan al final). */
  async reorder(ids: string[]): Promise<Banner[]> {
    const all = await this.banners.find({ order: { position: 'ASC', createdAt: 'ASC' } });
    const byId = new Map(all.map((b) => [b.id, b]));
    if (ids.some((id) => !byId.has(id)) || new Set(ids).size !== ids.length) {
      throw new BadRequestException('La lista de banners no es válida');
    }
    const ordered = [...ids.map((id) => byId.get(id)!), ...all.filter((b) => !ids.includes(b.id))];
    ordered.forEach((b, i) => (b.position = i));
    return this.banners.save(ordered);
  }

  private async find(id: string): Promise<Banner> {
    const banner = await this.banners.findOne({ where: { id } });
    if (!banner) throw new NotFoundException('Banner no encontrado');
    return banner;
  }

  /** Con la acción "enlace" el enlace es obligatorio; con cualquier otra no se guarda. */
  private linkFor(action: BannerAction, linkUrl?: string | null): string | null {
    if (action !== 'link') return null;
    const link = (linkUrl ?? '').trim();
    if (!link) throw new BadRequestException('Escribe el enlace al que lleva el banner');
    return link;
  }

  private checkWindow(startsAt?: Date | null, endsAt?: Date | null): void {
    if (startsAt && endsAt && endsAt <= startsAt) {
      throw new BadRequestException('El banner debe terminar después de empezar');
    }
  }
}
