import { registerDecorator, ValidationOptions } from 'class-validator';

/** Largo mínimo y máximo (bcrypt solo lee los primeros 72 caracteres). */
export const PASSWORD_MIN_LENGTH = 8;
export const PASSWORD_MAX_LENGTH = 72;

/** Contraseñas que se prueban primero en cualquier ataque: no se aceptan. */
const COMMON_PASSWORDS = new Set([
  '12345678', '123456789', '1234567890', '11111111', '00000000', 'qwertyui', 'qwerty123',
  'qwertyuiop', 'password', 'password1', 'password12', 'password123', 'contrasena',
  'contrasena1', 'contrasena123', 'abc12345', 'abcd1234', 'abcdefg1', 'iloveyou1',
  'admin123', 'admin1234', 'administrador1', 'fidelity1', 'fidelity123', 'fidelity2026',
  'hola1234', 'hola12345', 'holamundo1', 'bienvenido1', 'ecuador123', 'quito1234',
  'guayaquil1', 'cuenca1234', 'test1234', 'user1234', 'welcome1', 'letmein123', 'a1234567',
  'a12345678', 'asdf1234', 'zxcvbnm1', '1q2w3e4r', '1q2w3e4r5t', 'q1w2e3r4', '123qweasd',
]);

/**
 * Qué le falta a una contraseña (o `null` si está bien): al menos 8 caracteres,
 * letras y números, y que no sea de las más usadas.
 */
export function passwordProblem(password: unknown): string | null {
  if (typeof password !== 'string') return 'La contraseña no es válida';
  if (password.length < PASSWORD_MIN_LENGTH) {
    return `La contraseña debe tener al menos ${PASSWORD_MIN_LENGTH} caracteres`;
  }
  if (password.length > PASSWORD_MAX_LENGTH) return 'La contraseña es demasiado larga';
  if (!/[A-Za-zÁÉÍÓÚáéíóúÑñÜü]/.test(password) || !/\d/.test(password)) {
    return 'La contraseña debe incluir letras y números';
  }
  if (new Set(password).size < 3 || COMMON_PASSWORDS.has(password.toLowerCase())) {
    return 'Esa contraseña es muy común. Elige otra más difícil de adivinar';
  }
  return null;
}

/** Valida con [passwordProblem]: el mensaje dice exactamente qué falta. */
export function IsStrongPassword(validationOptions?: ValidationOptions) {
  return (object: object, propertyName: string) => {
    registerDecorator({
      name: 'isStrongPassword',
      target: object.constructor,
      propertyName,
      options: validationOptions,
      validator: {
        validate: (value: unknown) => passwordProblem(value) === null,
        defaultMessage: (args) => passwordProblem(args?.value) ?? 'La contraseña no es válida',
      },
    });
  };
}
