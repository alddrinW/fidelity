import { validate } from 'class-validator';
import { birthDateProblem, IsBirthDate } from './birth-date';

const now = new Date('2026-10-22T15:00:00Z');

describe('birthDateProblem', () => {
  it('acepta una fecha real del pasado', () => {
    expect(birthDateProblem('1998-03-14', now)).toBeNull();
    expect(birthDateProblem('2026-10-22', now)).toBeNull();
  });

  it('acepta el 29 de febrero solo en año bisiesto', () => {
    expect(birthDateProblem('2000-02-29', now)).toBeNull();
    expect(birthDateProblem('2001-02-29', now)).toBe('La fecha de nacimiento no existe');
  });

  it('rechaza fechas que no existen', () => {
    expect(birthDateProblem('1998-02-30', now)).toBe('La fecha de nacimiento no existe');
    expect(birthDateProblem('1998-13-01', now)).toBe('La fecha de nacimiento no existe');
    expect(birthDateProblem('1998-00-10', now)).toBe('La fecha de nacimiento no existe');
  });

  it('rechaza el formato incorrecto y lo que no es texto', () => {
    for (const bad of ['14/03/1998', '1998-3-4', '', 'hoy', 19980314, null, undefined]) {
      expect(birthDateProblem(bad as any, now)).toContain('formato');
    }
  });

  it('rechaza fechas futuras y demasiado antiguas', () => {
    expect(birthDateProblem('2026-10-25', now)).toBe('La fecha de nacimiento no puede ser futura');
    expect(birthDateProblem('2030-01-01', now)).toBe('La fecha de nacimiento no puede ser futura');
    expect(birthDateProblem('1899-12-31', now)).toBe('La fecha de nacimiento no es válida');
  });
});

describe('@IsBirthDate', () => {
  class Strict {
    @IsBirthDate()
    value: any;
  }
  class Lenient {
    @IsBirthDate({ allowEmpty: true })
    value: any;
  }
  const check = async (Cls: any, value: any) => {
    const o = new Cls();
    o.value = value;
    return (await validate(o)).length === 0;
  };

  it('valida con el decorador', async () => {
    expect(await check(Strict, '1990-05-05')).toBe(true);
    expect(await check(Strict, '1990-02-31')).toBe(false);
    expect(await check(Strict, '')).toBe(false);
  });

  it('con allowEmpty el texto vacío sirve para borrar la fecha', async () => {
    expect(await check(Lenient, '')).toBe(true);
    expect(await check(Lenient, '1990-05-05')).toBe(true);
    expect(await check(Lenient, 'xx')).toBe(false);
  });
});
