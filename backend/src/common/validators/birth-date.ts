import { registerDecorator, ValidationOptions } from 'class-validator';

/** La fecha más antigua que se acepta como nacimiento. */
export const MIN_BIRTH_YEAR = 1900;

/**
 * Revisa una fecha de nacimiento `AAAA-MM-DD`: que sea una fecha real (no el 30
 * de febrero), que no sea futura y que no sea absurdamente antigua. Devuelve el
 * motivo si no sirve, o `null` si está bien.
 */
export function birthDateProblem(value: unknown, now: Date = new Date()): string | null {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return 'La fecha de nacimiento debe tener el formato AAAA-MM-DD';
  }
  const [year, month, day] = value.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    return 'La fecha de nacimiento no existe';
  }
  if (year < MIN_BIRTH_YEAR) return 'La fecha de nacimiento no es válida';
  // Un día de margen por la diferencia de zona horaria entre el teléfono y el servidor.
  if (date.getTime() > now.getTime() + 24 * 60 * 60 * 1000) {
    return 'La fecha de nacimiento no puede ser futura';
  }
  return null;
}

/**
 * Una fecha de nacimiento válida. Con `allowEmpty` el texto vacío también pasa
 * (sirve para borrar la fecha guardada).
 */
export function IsBirthDate(options: { allowEmpty?: boolean } & ValidationOptions = {}) {
  const { allowEmpty, ...validationOptions } = options;
  return (object: object, propertyName: string) =>
    registerDecorator({
      name: 'isBirthDate',
      target: object.constructor,
      propertyName,
      options: validationOptions,
      validator: {
        validate: (value: unknown) => (allowEmpty && value === '' ? true : birthDateProblem(value) === null),
        defaultMessage: (args) =>
          (args && birthDateProblem(args.value)) || 'La fecha de nacimiento no es válida',
      },
    });
}
