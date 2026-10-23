import { BadRequestException } from '@nestjs/common';
import { SETTING_DEFINITIONS, SETTING_KEYS } from './settings.definitions';
import { SettingsService } from './settings.service';

describe('SettingsService', () => {
  let repo: any;
  let stored: { key: string; value: string }[];
  const config = { get: (key: string) => ({ 'payments.registrationFee': 25, 'payments.branchFee': 12 } as any)[key] };

  const build = () => new SettingsService(repo, config as any);

  beforeEach(() => {
    stored = [];
    repo = {
      find: jest.fn(async () => stored),
      create: jest.fn((d) => d),
      save: jest.fn(async (rows: any[]) => {
        for (const row of rows) {
          stored = stored.filter((s) => s.key !== row.key);
          stored.push(row);
        }
        return rows;
      }),
      delete: jest.fn(async ({ key }: any) => {
        const keys: string[] = key._value ?? [];
        stored = stored.filter((s) => !keys.includes(s.key));
      }),
    };
  });

  describe('definiciones', () => {
    it('cada ajuste tiene una clave que cabe en la tabla y un valor por defecto dentro de su rango', () => {
      const keys = new Set<string>();
      for (const def of SETTING_DEFINITIONS) {
        expect(def.key.length).toBeLessThanOrEqual(60);
        expect(def.default).toBeGreaterThanOrEqual(def.min);
        expect(def.default).toBeLessThanOrEqual(def.max);
        expect(keys.has(def.key)).toBe(false);
        keys.add(def.key);
      }
    });
  });

  describe('get', () => {
    it('sin nada guardado usa el valor por defecto', async () => {
      expect(await build().get(SETTING_KEYS.gameMaxAttempts)).toBe(3);
      expect(await build().get(SETTING_KEYS.keepNotificationsDays)).toBe(90);
    });

    it('los precios toman primero la configuración del servidor', async () => {
      expect(await build().get(SETTING_KEYS.registrationFee)).toBe(25);
      expect(await build().get(SETTING_KEYS.branchFee)).toBe(12);
    });

    it('lo que fijó el administrador manda sobre lo demás', async () => {
      stored = [{ key: SETTING_KEYS.registrationFee, value: '35.5' }];

      expect(await build().get(SETTING_KEYS.registrationFee)).toBe(35.5);
    });

    it('un valor guardado roto o fuera de rango se ignora', async () => {
      stored = [
        { key: SETTING_KEYS.branchFee, value: 'basura' },
        { key: SETTING_KEYS.gameMaxAttempts, value: '99' },
      ];

      expect(await build().get(SETTING_KEYS.branchFee)).toBe(12);
      expect(await build().get(SETTING_KEYS.gameMaxAttempts)).toBe(3);
    });

    it('un ajuste que no existe es un error de programación', async () => {
      await expect(build().get('nada')).rejects.toThrow('Ajuste desconocido');
    });

    it('recuerda los valores un rato: una sola lectura a la base', async () => {
      const service = build();

      await service.get(SETTING_KEYS.gameMaxAttempts);
      await service.get(SETTING_KEYS.maxApprovers);

      expect(repo.find).toHaveBeenCalledTimes(1);
    });
  });

  describe('valores en lista (JSON)', () => {
    it('sin nada guardado devuelve null', async () => {
      expect(await build().getJson('bank_accounts')).toBeNull();
    });

    it('guarda y lee una lista, y la lectura siguiente ya la ve', async () => {
      const service = build();

      await service.setJson('bank_accounts', [{ accountNumber: '123' }]);

      expect(repo.save).toHaveBeenCalledWith([{ key: 'bank_accounts', value: '[{"accountNumber":"123"}]' }]);
      expect(await service.getJson('bank_accounts')).toEqual([{ accountNumber: '123' }]);
    });

    it('un valor roto da null y una clave que no es de lista es un error', async () => {
      stored = [{ key: 'bank_accounts', value: '{no es json' }];

      expect(await build().getJson('bank_accounts')).toBeNull();
      await expect(build().getJson('game_max_attempts')).rejects.toThrow('Ajuste desconocido');
      await expect(build().setJson('nada', [])).rejects.toThrow('Ajuste desconocido');
    });
  });

  describe('view', () => {
    it('lista todos los ajustes con su valor, su rango y si están personalizados', async () => {
      stored = [{ key: SETTING_KEYS.gameMaxAttempts, value: '5' }];

      const view = await build().view();

      expect(view.items).toHaveLength(SETTING_DEFINITIONS.length);
      expect(view.items.find((i) => i.key === SETTING_KEYS.gameMaxAttempts)).toMatchObject({
        value: 5,
        default: 3,
        isCustom: true,
        min: 1,
        max: 10,
        group: 'minijuegos',
      });
      expect(view.items.find((i) => i.key === SETTING_KEYS.maxApprovers)).toMatchObject({ value: 10, isCustom: false });
      expect(view.groups.map((g) => g.id)).toEqual(['precios', 'minijuegos', 'negocios', 'cumpleanos', 'datos']);
    });

    it('el valor por defecto de un precio es el de la configuración del servidor', async () => {
      const item = (await build().view()).items.find((i) => i.key === SETTING_KEYS.registrationFee);

      expect(item).toMatchObject({ value: 25, default: 25, isCustom: false });
    });
  });

  describe('update', () => {
    it('guarda los valores y los devuelve ya aplicados', async () => {
      const service = build();

      const view = await service.update({ [SETTING_KEYS.gameMaxAttempts]: 5, [SETTING_KEYS.branchFee]: 9.999 });

      expect(repo.save).toHaveBeenCalledWith([
        { key: SETTING_KEYS.gameMaxAttempts, value: '5' },
        { key: SETTING_KEYS.branchFee, value: '10' },
      ]);
      expect(view.items.find((i) => i.key === SETTING_KEYS.gameMaxAttempts)?.value).toBe(5);
      // La siguiente lectura ya ve el cambio (no espera a que caduque la memoria).
      expect(await service.get(SETTING_KEYS.gameMaxAttempts)).toBe(5);
    });

    it('null devuelve el ajuste a su valor por defecto', async () => {
      stored = [{ key: SETTING_KEYS.gameMaxAttempts, value: '5' }];
      const service = build();

      const view = await service.update({ [SETTING_KEYS.gameMaxAttempts]: null });

      expect(repo.delete).toHaveBeenCalled();
      expect(view.items.find((i) => i.key === SETTING_KEYS.gameMaxAttempts)).toMatchObject({ value: 3, isCustom: false });
    });

    it('rechaza lo que no existe, no es número, no es entero o se sale del rango', async () => {
      const service = build();

      await expect(service.update({ nada: 1 })).rejects.toThrow('no existe');
      await expect(service.update({ [SETTING_KEYS.gameMaxAttempts]: 'tres' as any })).rejects.toThrow('número');
      await expect(service.update({ [SETTING_KEYS.gameMaxAttempts]: 2.5 })).rejects.toThrow('entero');
      await expect(service.update({ [SETTING_KEYS.gameMaxAttempts]: 0 })).rejects.toThrow('entre 1 y 10');
      await expect(service.update({ [SETTING_KEYS.gameMaxAttempts]: 11 })).rejects.toThrow('entre 1 y 10');
      await expect(service.update({ [SETTING_KEYS.branchFee]: 0.1 })).rejects.toThrow('entre 0.5');
      await expect(service.update({})).rejects.toBeInstanceOf(BadRequestException);
      expect(repo.save).not.toHaveBeenCalled();
    });

    it('todo o nada: si uno no vale, no se guarda ninguno', async () => {
      await expect(
        build().update({ [SETTING_KEYS.gameMaxAttempts]: 4, [SETTING_KEYS.maxApprovers]: 500 }),
      ).rejects.toBeInstanceOf(BadRequestException);

      expect(repo.save).not.toHaveBeenCalled();
    });

    it('la duración por defecto de un reto no puede pasar de la máxima', async () => {
      await expect(
        build().update({ [SETTING_KEYS.gameDefaultDays]: 30, [SETTING_KEYS.gameMaxDays]: 10 }),
      ).rejects.toThrow('no puede ser mayor');
      // Tampoco bajando solo la máxima por debajo de la por defecto vigente (7).
      await expect(build().update({ [SETTING_KEYS.gameMaxDays]: 3 })).rejects.toThrow('no puede ser mayor');
    });

    it('los avisos leídos no pueden guardarse más que cualquier aviso', async () => {
      await expect(
        build().update({ [SETTING_KEYS.keepReadNotificationsDays]: 200, [SETTING_KEYS.keepNotificationsDays]: 100 }),
      ).rejects.toThrow('no pueden guardarse más tiempo');
    });
  });
});
