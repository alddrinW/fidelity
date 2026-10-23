import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { AppSetting } from '../../database/entities/app-setting.entity';
import {
  JSON_SETTING_KEYS,
  SETTING_BY_KEY,
  SETTING_DEFINITIONS,
  SETTING_GROUPS,
  SETTING_KEYS,
  SettingDefinition,
} from './settings.definitions';

/** Los valores guardados se recuerdan este tiempo para no ir a la base en cada petición. */
const CACHE_TTL_MS = 15_000;

/** Pares "el primero no puede pasar del segundo". */
const ORDERED_PAIRS: [string, string, string][] = [
  [
    SETTING_KEYS.gameDefaultDays,
    SETTING_KEYS.gameMaxDays,
    'La duración por defecto de un reto no puede ser mayor que la duración máxima',
  ],
  [
    SETTING_KEYS.keepReadNotificationsDays,
    SETTING_KEYS.keepNotificationsDays,
    'Los avisos leídos no pueden guardarse más tiempo que cualquier aviso',
  ],
];

export type SettingsPatch = Record<string, number | null>;

/**
 * Ajustes del sistema que controla el administrador. Sin valor guardado (o con
 * uno fuera de rango) se usa el de la configuración del servidor y, si no hay,
 * el por defecto de cada ajuste.
 */
@Injectable()
export class SettingsService {
  private cache: { at: number; values: Map<string, string> } | null = null;

  constructor(
    @InjectRepository(AppSetting)
    private readonly settingRepository: Repository<AppSetting>,
    private readonly configService: ConfigService,
  ) {}

  private async saved(): Promise<Map<string, string>> {
    if (this.cache && Date.now() - this.cache.at < CACHE_TTL_MS) return this.cache.values;
    const rows = await this.settingRepository.find({
      where: { key: In([...SETTING_DEFINITIONS.map((d) => d.key), ...JSON_SETTING_KEYS]) },
    });
    const values = new Map(rows.map((r) => [r.key, r.value]));
    this.cache = { at: Date.now(), values };
    return values;
  }

  private fallback(def: SettingDefinition): number {
    const fromConfig = def.configPath ? Number(this.configService.get(def.configPath)) : NaN;
    return Number.isFinite(fromConfig) && fromConfig >= def.min && fromConfig <= def.max
      ? fromConfig
      : def.default;
  }

  private resolve(def: SettingDefinition, saved: Map<string, string>) {
    const raw = saved.get(def.key);
    const n = raw == null ? NaN : Number(raw);
    const valid = Number.isFinite(n) && n >= def.min && n <= def.max;
    return { value: valid ? n : this.fallback(def), isCustom: valid };
  }

  /** Valor vigente de un ajuste. */
  async get(key: string): Promise<number> {
    const def = SETTING_BY_KEY[key];
    if (!def) throw new Error(`Ajuste desconocido: ${key}`);
    return this.resolve(def, await this.saved()).value;
  }

  /** Un ajuste con forma de lista u objeto (p. ej. las cuentas bancarias); null si no se ha guardado. */
  async getJson<T>(key: string): Promise<T | null> {
    this.assertJsonKey(key);
    const raw = (await this.saved()).get(key);
    if (raw == null) return null;
    try {
      return JSON.parse(raw) as T;
    } catch {
      return null;
    }
  }

  async setJson(key: string, value: unknown): Promise<void> {
    this.assertJsonKey(key);
    await this.settingRepository.save([this.settingRepository.create({ key, value: JSON.stringify(value) })]);
    this.cache = null;
  }

  private assertJsonKey(key: string) {
    if (!JSON_SETTING_KEYS.includes(key)) throw new Error(`Ajuste desconocido: ${key}`);
  }

  /** Todos los ajustes con su valor vigente, agrupados para mostrarlos. */
  async view() {
    const saved = await this.saved();
    return {
      groups: SETTING_GROUPS,
      items: SETTING_DEFINITIONS.map((def) => {
        const { value, isCustom } = this.resolve(def, saved);
        return {
          key: def.key,
          group: def.group,
          kind: def.kind,
          label: def.label,
          description: def.description,
          unit: def.unit,
          min: def.min,
          max: def.max,
          default: this.fallback(def),
          value,
          isCustom,
        };
      }),
    };
  }

  /**
   * Guarda los valores que manda el administrador. `null` vuelve el ajuste a su
   * valor por defecto. Todo o nada: si uno no vale, no se guarda ninguno.
   */
  async update(patch: SettingsPatch) {
    const keys = Object.keys(patch ?? {});
    if (keys.length === 0) throw new BadRequestException('No hay nada que cambiar');

    const toSave: AppSetting[] = [];
    const toReset: string[] = [];
    const next = new Map<string, number>();
    const saved = await this.saved();

    for (const key of keys) {
      const def = SETTING_BY_KEY[key];
      if (!def) throw new BadRequestException(`El ajuste "${key}" no existe`);
      const raw = patch[key];

      if (raw === null) {
        toReset.push(key);
        next.set(key, this.fallback(def));
        continue;
      }
      const n = typeof raw === 'number' ? raw : Number.NaN;
      if (!Number.isFinite(n)) throw new BadRequestException(`"${def.label}" debe ser un número`);
      if (def.kind === 'int' && !Number.isInteger(n)) {
        throw new BadRequestException(`"${def.label}" debe ser un número entero`);
      }
      if (n < def.min || n > def.max) {
        throw new BadRequestException(`"${def.label}" debe estar entre ${def.min} y ${def.max}`);
      }
      const value = def.kind === 'money' ? Math.round(n * 100) / 100 : n;
      toSave.push(this.settingRepository.create({ key, value: String(value) }));
      next.set(key, value);
    }

    const current = (key: string) =>
      next.get(key) ?? this.resolve(SETTING_BY_KEY[key], saved).value;
    for (const [low, high, message] of ORDERED_PAIRS) {
      if (current(low) > current(high)) throw new BadRequestException(message);
    }

    if (toSave.length) await this.settingRepository.save(toSave);
    if (toReset.length) await this.settingRepository.delete({ key: In(toReset) });
    this.cache = null;
    return this.view();
  }
}
