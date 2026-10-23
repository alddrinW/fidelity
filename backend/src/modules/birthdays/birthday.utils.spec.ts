import { birthdayOffset, celebrationDate, ecuadorInstant, ecuadorNow, isLeapYear, monthDay, parseClock } from './birthday.utils';

describe('ecuadorNow', () => {
  it('convierte a la hora de Ecuador (UTC-5)', () => {
    expect(ecuadorNow(new Date('2026-10-22T15:00:00Z'))).toEqual({ year: 2026, month: 10, day: 22, hour: 10 });
  });

  it('de madrugada en UTC todavía es el día anterior en Ecuador', () => {
    expect(ecuadorNow(new Date('2026-01-01T03:30:00Z'))).toEqual({ year: 2025, month: 12, day: 31, hour: 22 });
  });

  it('la medianoche es la hora 0 (no 24)', () => {
    expect(ecuadorNow(new Date('2026-10-22T05:10:00Z')).hour).toBe(0);
  });
});

describe('fechas de cumpleaños', () => {
  it('años bisiestos', () => {
    expect([2000, 2024, 2028].every(isLeapYear)).toBe(true);
    expect([1900, 2025, 2026].some(isLeapYear)).toBe(false);
  });

  it('mes y día salen sin el año de nacimiento', () => {
    expect(monthDay('1998-03-14')).toEqual({ month: 3, day: 14 });
  });

  it('el 29 de febrero se celebra el 28 en años no bisiestos', () => {
    expect(celebrationDate('2000-02-29', 2026)).toEqual({ year: 2026, month: 2, day: 28 });
    expect(celebrationDate('2000-02-29', 2028)).toEqual({ year: 2028, month: 2, day: 29 });
    expect(celebrationDate('1998-03-14', 2026)).toEqual({ year: 2026, month: 3, day: 14 });
  });
});

describe('birthdayOffset', () => {
  const today = { year: 2026, month: 10, day: 22 };

  it('hoy es 0', () => {
    expect(birthdayOffset('1990-10-22', today)).toEqual({ days: 0, year: 2026 });
  });

  it('faltan días', () => {
    expect(birthdayOffset('1990-10-25', today)).toEqual({ days: 3, year: 2026 });
  });

  it('ya pasó hace poco: negativo', () => {
    expect(birthdayOffset('1990-10-20', today)).toEqual({ days: -2, year: 2026 });
  });

  it('cruza el fin de año: el 2 de enero visto desde el 30 de diciembre', () => {
    expect(birthdayOffset('1990-01-02', { year: 2026, month: 12, day: 30 })).toEqual({ days: 3, year: 2027 });
  });

  it('cruza el inicio de año: el 30 de diciembre visto desde el 1 de enero', () => {
    expect(birthdayOffset('1990-12-30', { year: 2027, month: 1, day: 1 })).toEqual({ days: -2, year: 2026 });
  });

  it('el 29 de febrero se acerca el 28 en año no bisiesto', () => {
    expect(birthdayOffset('2000-02-29', { year: 2026, month: 2, day: 26 })).toEqual({ days: 2, year: 2026 });
    expect(birthdayOffset('2000-02-29', { year: 2026, month: 2, day: 28 })).toEqual({ days: 0, year: 2026 });
  });

  it('uno lejano da muchos días', () => {
    expect(Math.abs(birthdayOffset('1990-04-22', today).days)).toBeGreaterThan(150);
  });
});

describe('horas de Ecuador', () => {
  it('lee HH:mm y rechaza lo demás', () => {
    expect(parseClock('08:05')).toEqual({ hour: 8, minute: 5 });
    expect(parseClock('23:59')).toEqual({ hour: 23, minute: 59 });
    for (const bad of ['24:00', '8:00', '12:60', '', 'mediodía', null, 900]) {
      expect(parseClock(bad as any)).toBeNull();
    }
  });

  it('el instante de una hora de Ecuador (UTC-5)', () => {
    expect(ecuadorInstant({ year: 2026, month: 10, day: 22 }, '08:00').toISOString()).toBe('2026-10-22T13:00:00.000Z');
    // De noche ya es el día siguiente en UTC.
    expect(ecuadorInstant({ year: 2026, month: 12, day: 31 }, '23:30').toISOString()).toBe('2027-01-01T04:30:00.000Z');
  });

  it('ida y vuelta con ecuadorNow', () => {
    const instant = ecuadorInstant({ year: 2026, month: 3, day: 9 }, '15:00');

    expect(ecuadorNow(instant)).toEqual({ year: 2026, month: 3, day: 9, hour: 15 });
  });

  it('una hora inválida es un error de programación', () => {
    expect(() => ecuadorInstant({ year: 2026, month: 1, day: 1 }, '25:00')).toThrow('Hora no válida');
  });
});
