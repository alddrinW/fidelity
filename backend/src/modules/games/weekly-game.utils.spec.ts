import { GAME_KEYS } from './games.logic';
import { blockedBusinesses, pickWeeklyGame, weekOf } from './weekly-game.utils';

describe('weekOf (la semana, de lunes a domingo en Ecuador)', () => {
  it('un miércoles pertenece a la semana que empezó el lunes', () => {
    // 2026-10-21 es miércoles; 12:00 en Ecuador = 17:00 UTC
    const week = weekOf(new Date('2026-10-21T17:00:00Z'));

    expect(week.key).toBe('2026-10-19');
    expect(week.startsAt.toISOString()).toBe('2026-10-19T05:00:00.000Z');
    expect(week.endsAt.toISOString()).toBe('2026-10-26T05:00:00.000Z');
  });

  it('el lunes a las 00:00 de Ecuador ya es la semana nueva', () => {
    expect(weekOf(new Date('2026-10-19T05:00:00Z')).key).toBe('2026-10-19');
    // un segundo antes todavía es la semana anterior
    expect(weekOf(new Date('2026-10-19T04:59:59Z')).key).toBe('2026-10-12');
  });

  it('el domingo por la noche todavía es de esa semana', () => {
    // domingo 2026-10-25 23:30 en Ecuador = lunes 04:30 UTC
    const week = weekOf(new Date('2026-10-26T04:30:00Z'));

    expect(week.key).toBe('2026-10-19');
    expect(week.endsAt.getTime()).toBeGreaterThan(new Date('2026-10-26T04:30:00Z').getTime());
  });

  it('cruza el fin de año', () => {
    // jueves 2026-01-01
    const week = weekOf(new Date('2026-01-01T15:00:00Z'));

    expect(week.key).toBe('2025-12-29');
    expect(week.endsAt.toISOString()).toBe('2026-01-05T05:00:00.000Z');
  });

  it('la semana dura exactamente 7 días', () => {
    const week = weekOf(new Date('2026-07-15T12:00:00Z'));

    expect(week.endsAt.getTime() - week.startsAt.getTime()).toBe(7 * 24 * 60 * 60 * 1000);
  });
});

describe('pickWeeklyGame', () => {
  it('siempre es el mismo para la misma persona y semana', () => {
    expect(pickWeeklyGame('u1', '2026-10-19')).toBe(pickWeeklyGame('u1', '2026-10-19'));
  });

  it('es un juego válido y varía entre personas y semanas', () => {
    const picks = new Set<string>();
    for (let i = 0; i < 40; i++) {
      const game = pickWeeklyGame(`usuario-${i}`, `2026-10-${10 + (i % 3)}`);
      expect(GAME_KEYS).toContain(game);
      picks.add(game);
    }
    expect(picks.size).toBe(GAME_KEYS.length);
  });
});

describe('blockedBusinesses (negocios donde ya ganó)', () => {
  const eligible = new Set(['a', 'b', 'c']);

  it('sin victorias no hay nada bloqueado', () => {
    expect([...blockedBusinesses([], eligible)]).toEqual([]);
  });

  it('el negocio donde ya ganó sale bloqueado', () => {
    expect([...blockedBusinesses(['a'], eligible)]).toEqual(['a']);
    expect([...blockedBusinesses(['a', 'b'], eligible)].sort()).toEqual(['a', 'b']);
  });

  it('al ganar en todos, la ronda termina y se abre de nuevo', () => {
    expect([...blockedBusinesses(['a', 'b', 'c'], eligible)]).toEqual([]);
  });

  it('después de reiniciar, lo ganado en la ronda nueva vuelve a bloquear', () => {
    expect([...blockedBusinesses(['a', 'b', 'c', 'b'], eligible)]).toEqual(['b']);
    expect([...blockedBusinesses(['a', 'b', 'c', 'b', 'a'], eligible)].sort()).toEqual(['a', 'b']);
  });

  it('una victoria en un negocio que ya no está disponible no bloquea a los demás ni cuenta para cerrar la ronda', () => {
    expect([...blockedBusinesses(['z'], eligible)]).toEqual([]);
    expect([...blockedBusinesses(['a', 'z', 'b'], eligible)].sort()).toEqual(['a', 'b']);
  });

  it('con un solo negocio disponible, ganar ahí reinicia enseguida (siempre puede jugar)', () => {
    expect([...blockedBusinesses(['a'], new Set(['a']))]).toEqual([]);
  });

  it('un negocio nuevo aparece libre aunque la ronda esté empezada', () => {
    expect([...blockedBusinesses(['a'], new Set(['a', 'b', 'c', 'd']))]).toEqual(['a']);
  });

  it('sin negocios disponibles no bloquea nada', () => {
    expect([...blockedBusinesses(['a'], new Set())]).toEqual([]);
  });
});
