import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Banner } from '../../database/entities/banner.entity';
import { BannersService, MAX_BANNERS } from './banners.service';

const IMG = 'data:image/png;base64,AAAA';

describe('BannersService', () => {
  let service: BannersService;
  let rows: any[];
  let repo: any;

  const row = (id: string, extra: any = {}) => ({
    id,
    title: `Banner ${id}`,
    imageUrl: IMG,
    imageUrlEn: null,
    action: 'none',
    linkUrl: null,
    blendWhite: true,
    isActive: true,
    startsAt: null,
    endsAt: null,
    position: rows.length,
    createdAt: new Date(rows.length),
    ...extra,
  });

  beforeEach(async () => {
    rows = [];
    repo = {
      find: jest.fn(async (opts: any = {}) => {
        let out = [...rows];
        if (opts.where?.isActive !== undefined) out = out.filter((r) => r.isActive === opts.where.isActive);
        out.sort((a, b) => a.position - b.position);
        if (opts.order?.position === 'DESC') out.reverse();
        return opts.take ? out.slice(0, opts.take) : out;
      }),
      findOne: jest.fn(async ({ where }: any) => rows.find((r) => r.id === where.id) ?? null),
      count: jest.fn(async () => rows.length),
      create: jest.fn((v: any) => ({ id: `n${rows.length + 1}`, createdAt: new Date(), ...v })),
      save: jest.fn(async (v: any) => {
        for (const item of Array.isArray(v) ? v : [v]) {
          if (!rows.includes(item) && !rows.find((r) => r.id === item.id)) rows.push(item);
        }
        return v;
      }),
      remove: jest.fn(async (v: any) => {
        rows = rows.filter((r) => r.id !== v.id);
      }),
    };
    const module = await Test.createTestingModule({
      providers: [BannersService, { provide: getRepositoryToken(Banner), useValue: repo }],
    }).compile();
    service = module.get(BannersService);
  });

  describe('listPublic', () => {
    const now = new Date('2026-10-26T12:00:00Z');

    it('trae solo los activos, en orden', async () => {
      rows = [row('b', { position: 1 }), row('a', { position: 0 }), row('off', { isActive: false, position: 2 })];

      const list = await service.listPublic('es', now);

      expect(list.map((b) => b.id)).toEqual(['a', 'b']);
    });

    it('respeta el horario: no antes de empezar ni después de terminar', async () => {
      rows = [
        row('pronto', { startsAt: new Date('2026-11-01T00:00:00Z') }),
        row('ya', { startsAt: new Date('2026-10-01T00:00:00Z'), endsAt: new Date('2026-11-01T00:00:00Z') }),
        row('pasado', { endsAt: new Date('2026-10-20T00:00:00Z') }),
      ];

      expect((await service.listPublic('es', now)).map((b) => b.id)).toEqual(['ya']);
    });

    it('en inglés usa la imagen en inglés si existe, y si no la principal', async () => {
      rows = [row('a', { imageUrlEn: 'https://x.test/en.png', position: 0 }), row('b', { position: 1 })];

      const en = await service.listPublic('en', now);
      expect(en.map((b) => b.imageUrl)).toEqual(['https://x.test/en.png', IMG]);
      const es = await service.listPublic('es', now);
      expect(es.map((b) => b.imageUrl)).toEqual([IMG, IMG]);
    });

    it('solo manda el enlace cuando la acción es enlace', async () => {
      rows = [
        row('a', { action: 'invite', linkUrl: 'https://viejo.test' }),
        row('b', { action: 'link', linkUrl: 'https://x.test', position: 1 }),
      ];

      const list = await service.listPublic('es', now);

      expect(list.map((b) => b.linkUrl)).toEqual([null, 'https://x.test']);
    });
  });

  describe('create', () => {
    it('lo agrega al final, activo y fundido con el blanco por defecto', async () => {
      rows = [row('a', { position: 3 })];

      const banner = await service.create({ title: '  Promo  ', imageUrl: IMG });

      expect(banner).toMatchObject({
        title: 'Promo',
        action: 'none',
        linkUrl: null,
        blendWhite: true,
        isActive: true,
        position: 4,
      });
    });

    it('con la acción enlace pide el enlace; con otra no lo guarda', async () => {
      await expect(service.create({ title: 'a', imageUrl: IMG, action: 'link' })).rejects.toThrow(BadRequestException);

      const ok = await service.create({ title: 'a', imageUrl: IMG, action: 'link', linkUrl: 'https://x.test' });
      expect(ok.linkUrl).toBe('https://x.test');
      const other = await service.create({ title: 'b', imageUrl: IMG, action: 'invite', linkUrl: 'https://x.test' });
      expect(other.linkUrl).toBeNull();
    });

    it('rechaza un horario que termina antes de empezar', async () => {
      await expect(
        service.create({ title: 'a', imageUrl: IMG, startsAt: new Date('2026-11-02'), endsAt: new Date('2026-11-01') }),
      ).rejects.toThrow(BadRequestException);
    });

    it(`no deja pasar de ${MAX_BANNERS} banners`, async () => {
      rows = Array.from({ length: MAX_BANNERS }, (_, i) => row(`b${i}`, { position: i }));

      await expect(service.create({ title: 'a', imageUrl: IMG })).rejects.toThrow(/hasta 12 banners/);
    });
  });

  describe('update', () => {
    it('cambia lo que se manda y deja el resto', async () => {
      rows = [row('a', { action: 'link', linkUrl: 'https://x.test' })];

      const banner = await service.update('a', { title: 'Nuevo', isActive: false });

      expect(banner).toMatchObject({ title: 'Nuevo', isActive: false, action: 'link', linkUrl: 'https://x.test' });
    });

    it('al pasar a otra acción borra el enlace; quitar la imagen en inglés la deja vacía', async () => {
      rows = [row('a', { action: 'link', linkUrl: 'https://x.test', imageUrlEn: 'https://x.test/en.png' })];

      const banner = await service.update('a', { action: 'scan', imageUrlEn: '' });

      expect(banner.linkUrl).toBeNull();
      expect(banner.imageUrlEn).toBeNull();
    });

    it('si no existe, 404', async () => {
      await expect(service.update('nada', { title: 'x' })).rejects.toThrow(NotFoundException);
    });
  });

  describe('reorder', () => {
    it('guarda el orden pedido', async () => {
      rows = [row('a', { position: 0 }), row('b', { position: 1 }), row('c', { position: 2 })];

      await service.reorder(['c', 'a', 'b']);

      expect(Object.fromEntries(rows.map((r) => [r.id, r.position]))).toEqual({ c: 0, a: 1, b: 2 });
    });

    it('los que no vienen en la lista quedan al final', async () => {
      rows = [row('a', { position: 0 }), row('b', { position: 1 }), row('c', { position: 2 })];

      await service.reorder(['b']);

      expect(Object.fromEntries(rows.map((r) => [r.id, r.position]))).toEqual({ b: 0, a: 1, c: 2 });
    });

    it('rechaza ids que no existen o repetidos', async () => {
      rows = [row('a')];

      await expect(service.reorder(['zzz'])).rejects.toThrow(BadRequestException);
      await expect(service.reorder(['a', 'a'])).rejects.toThrow(BadRequestException);
    });
  });

  it('remove borra el banner y avisa si no existe', async () => {
    rows = [row('a')];

    expect(await service.remove('a')).toEqual({ deleted: true });
    expect(rows).toHaveLength(0);
    await expect(service.remove('a')).rejects.toThrow(NotFoundException);
  });
});
