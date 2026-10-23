/** Zona horaria en la que se celebran los cumpleaños (Ecuador, sin horario de verano). */
export const BIRTHDAY_TIME_ZONE = 'America/Guayaquil';

const DAY_MS = 24 * 60 * 60 * 1000;

export interface CalendarDay {
  year: number;
  month: number; // 1 a 12
  day: number;
}

/** Fecha y hora de pared en Ecuador de un instante. */
export function ecuadorNow(now: Date = new Date()): CalendarDay & { hour: number } {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: BIRTHDAY_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value);
  return { year: get('year'), month: get('month'), day: get('day'), hour: get('hour') };
}

export function isLeapYear(year: number): boolean {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}

/** Mes y día de una fecha `AAAA-MM-DD` (el año de nacimiento no se usa ni se muestra). */
export function monthDay(birthDate: string): { month: number; day: number } {
  const [, month, day] = birthDate.split('-').map(Number);
  return { month, day };
}

/**
 * El día en que se celebra un cumpleaños en un año: quien nació un 29 de
 * febrero lo celebra el 28 en los años que no son bisiestos.
 */
export function celebrationDate(birthDate: string, year: number): CalendarDay {
  const { month, day } = monthDay(birthDate);
  if (month === 2 && day === 29 && !isLeapYear(year)) return { year, month: 2, day: 28 };
  return { year, month, day };
}

const utc = (d: CalendarDay) => Date.UTC(d.year, d.month - 1, d.day);

/**
 * Cuántos días faltan para el cumpleaños más cercano (negativo si ya pasó hace
 * poco). Elige entre el del año anterior, el de este año y el del siguiente.
 */
export function birthdayOffset(birthDate: string, today: CalendarDay): { days: number; year: number } {
  let best: { days: number; year: number } | null = null;
  for (const year of [today.year - 1, today.year, today.year + 1]) {
    const days = Math.round((utc(celebrationDate(birthDate, year)) - utc(today)) / DAY_MS);
    if (!best || Math.abs(days) < Math.abs(best.days) || (Math.abs(days) === Math.abs(best.days) && days > best.days)) {
      best = { days, year };
    }
  }
  return best!;
}

/** Ecuador está siempre 5 horas detrás de UTC (no hay horario de verano). */
const ECUADOR_UTC_OFFSET_HOURS = 5;

/** Lee una hora `HH:mm` (00:00 a 23:59); null si no es válida. */
export function parseClock(value: unknown): { hour: number; minute: number } | null {
  if (typeof value !== 'string') return null;
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(value);
  return match ? { hour: Number(match[1]), minute: Number(match[2]) } : null;
}

/** El instante en que son las [time] (`HH:mm`) de un día en Ecuador. */
export function ecuadorInstant(day: CalendarDay, time: string): Date {
  const clock = parseClock(time);
  if (!clock) throw new Error(`Hora no válida: ${time}`);
  return new Date(Date.UTC(day.year, day.month - 1, day.day, clock.hour + ECUADOR_UTC_OFFSET_HOURS, clock.minute));
}
