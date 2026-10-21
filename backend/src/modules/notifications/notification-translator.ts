/**
 * Traducción de los avisos del servidor (notificaciones push y bandeja).
 *
 * El servidor escribe sus avisos en español, con datos dentro del texto
 * ("Café Aurora te reta a jugar"). Para el usuario que usa la app en inglés se
 * traducen con un diccionario, igual que hace la app con su interfaz:
 *   1. Texto exacto.
 *   2. Plantillas con `{}` para los textos con datos; cada `{}` toma un valor
 *      que a su vez se traduce, y en la traducción puede reordenarse con
 *      `{1}`, `{2}`...
 *   3. Listas separadas por comas y textos de varias líneas: se traduce cada parte.
 * Si un texto no tiene traducción se deja en español: nunca falla.
 *
 * Lo que escribió una persona (el nombre de un negocio, una opinión...) pasa
 * tal cual: solo se traduce el texto fijo del aviso.
 */
import { NOTIFICATION_PATTERNS_EN, NOTIFICATION_STRINGS_EN } from './notification-strings.en';

export type Language = 'es' | 'en';

export const SUPPORTED_LANGUAGES: Language[] = ['es', 'en'];

export function normalizeLanguage(value?: string | null): Language {
  return value === 'en' ? 'en' : 'es';
}

class Pattern {
  readonly regex: RegExp;
  readonly fixedLength: number;

  constructor(
    readonly source: string,
    readonly target: string,
  ) {
    const parts = source.split('{}').map((p) => p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
    this.regex = new RegExp(`^${parts.join('(.+?)')}$`, 's');
    this.fixedLength = source.replace(/\{\}/g, '').length;
  }

  apply(text: string, translate: (value: string) => string): string | null {
    const match = this.regex.exec(text);
    if (!match) return null;
    const values = match.slice(1).map((v) => translate(v));
    let sequential = 0;
    return this.target.replace(/\{(\d*)\}/g, (_, n: string) => {
      const index = n === '' ? sequential++ : parseInt(n, 10) - 1;
      return index < values.length ? values[index] : '';
    });
  }
}

export class NotificationTranslator {
  private readonly patterns: Pattern[];

  constructor(
    private readonly exact: Record<string, string>,
    patterns: Record<string, string>,
  ) {
    // Las plantillas con más texto fijo se prueban primero (son más específicas).
    this.patterns = Object.entries(patterns)
      .map(([source, target]) => new Pattern(source, target))
      .sort((a, b) => b.fixedLength - a.fixedLength);
  }

  toEnglish(text: string): string {
    if (!text || text.trim().length === 0) return text;

    const exact = this.exact[text];
    if (exact !== undefined) return exact;

    for (const pattern of this.patterns) {
      const result = pattern.apply(text, (value) => this.toEnglish(value));
      if (result !== null) return result;
    }

    if (text.includes('\n')) return text.split('\n').map((line) => this.toEnglish(line)).join('\n');
    // Listas como "Tres en raya, Ahorcado, Flappy Bird".
    if (text.includes(', ')) {
      const parts = text.split(', ');
      const translated = parts.map((part) => this.exact[part] ?? part);
      if (translated.some((part, i) => part !== parts[i])) return translated.join(', ');
    }
    return text;
  }
}

export const notificationTranslator = new NotificationTranslator(
  NOTIFICATION_STRINGS_EN,
  NOTIFICATION_PATTERNS_EN,
);

/** El texto de un aviso en el idioma del usuario (español si no hay traducción). */
export function translateNotification(text: string, language?: string | null): string {
  return normalizeLanguage(language) === 'en' ? notificationTranslator.toEnglish(text) : text;
}
