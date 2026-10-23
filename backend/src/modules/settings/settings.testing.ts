import { SETTING_BY_KEY } from './settings.definitions';

/**
 * Un `SettingsService` falso para las pruebas de otros módulos: devuelve el
 * valor por defecto de cada ajuste, salvo los que se pasen en `overrides`.
 */
export function fakeSettings(overrides: Record<string, number> = {}) {
  return {
    get: jest.fn(async (key: string) => overrides[key] ?? SETTING_BY_KEY[key].default),
  };
}
