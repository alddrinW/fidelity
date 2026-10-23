import { generatePassword } from './create-admin';
import { passwordProblem } from '../../common/validators/strong-password';

describe('clave generada para el administrador', () => {
  it('siempre cumple las reglas de contraseña de la app', () => {
    for (let i = 0; i < 200; i++) {
      expect(passwordProblem(generatePassword())).toBeNull();
    }
  });

  it('tiene 18 caracteres por defecto, con letras, números y símbolos', () => {
    for (let i = 0; i < 50; i++) {
      const password = generatePassword();
      expect(password).toHaveLength(18);
      expect(password).toMatch(/[A-Za-z]/);
      expect(password).toMatch(/\d/);
      expect(password).toMatch(/[!#$%*+\-=?@]/);
    }
  });

  it('no usa caracteres que se confunden al copiarla a mano (0, O, 1, l, I)', () => {
    for (let i = 0; i < 100; i++) {
      expect(generatePassword()).not.toMatch(/[0OIl1]/);
    }
  });

  it('es distinta cada vez (no hay clave por defecto)', () => {
    const passwords = new Set(Array.from({ length: 50 }, () => generatePassword()));
    expect(passwords.size).toBe(50);
  });

  it('el largo se puede pedir', () => {
    expect(generatePassword(30)).toHaveLength(30);
  });
});
