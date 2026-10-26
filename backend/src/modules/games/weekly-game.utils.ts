import { CalendarDay, ecuadorInstant, ecuadorNow } from '../birthdays/birthday.utils';
import { GAME_KEYS, GameKey } from './games.logic';

/**
 * Funciones puras del juego semanal: qué semana es (de lunes a domingo, hora de
 * Ecuador), qué juego le toca a cada cliente y qué negocios tiene bloqueados.
 */

const DAY_MS = 24 * 60 * 60 * 1000;

export interface WeekInfo {
  /** El lunes de la semana, como `AAAA-MM-DD`. */
  key: string;
  /** Lunes 00:00 (hora de Ecuador). */
  startsAt: Date;
  /** El lunes siguiente 00:00: la semana termina justo antes. */
  endsAt: Date;
}

const pad = (n: number) => String(n).padStart(2, '0');
const keyOf = (d: CalendarDay) => `${d.year}-${pad(d.month)}-${pad(d.day)}`;

function addDays(day: CalendarDay, days: number): CalendarDay {
  const d = new Date(Date.UTC(day.year, day.month - 1, day.day) + days * DAY_MS);
  return { year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate() };
}

/** La semana (lunes a domingo, en Ecuador) a la que pertenece un instante. */
export function weekOf(now: Date = new Date()): WeekInfo {
  const today = ecuadorNow(now);
  const weekday = new Date(Date.UTC(today.year, today.month - 1, today.day)).getUTCDay(); // 0 = domingo
  const monday = addDays(today, -((weekday + 6) % 7));
  return {
    key: keyOf(monday),
    startsAt: ecuadorInstant(monday, '00:00'),
    endsAt: ecuadorInstant(addDays(monday, 7), '00:00'),
  };
}

/**
 * El juego que le toca a un cliente esa semana: siempre el mismo para la misma
 * persona y semana (no puede cambiarlo recargando), y distinto entre semanas.
 */
export function pickWeeklyGame(userId: string, weekKey: string): GameKey {
  let hash = 0;
  for (const ch of `${userId}:${weekKey}`) hash = (hash * 31 + ch.charCodeAt(0)) >>> 0;
  return GAME_KEYS[hash % GAME_KEYS.length];
}

/**
 * Los negocios que no puede elegir: aquellos donde ya ganó un punto en la ronda
 * actual. Al ganar en todos los negocios que tiene disponibles, la ronda
 * termina y la lista se abre de nuevo (así nunca se queda sin juego).
 *
 * [winsInOrder] son los negocios donde ganó, del más antiguo al más reciente.
 */
export function blockedBusinesses(winsInOrder: string[], eligible: ReadonlySet<string>): Set<string> {
  let round = new Set<string>();
  for (const businessId of winsInOrder) {
    round.add(businessId);
    if (eligible.size > 0 && [...eligible].every((id) => round.has(id))) round = new Set();
  }
  return new Set([...round].filter((id) => eligible.has(id)));
}
