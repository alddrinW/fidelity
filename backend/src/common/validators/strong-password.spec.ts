import 'reflect-metadata';
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { passwordProblem } from './strong-password';
import { RegisterDto, ResetPasswordDto } from '../../modules/auth/dto/auth.dto';
import { ChangePasswordDto } from '../../modules/users/dto/users.dto';

describe('passwordProblem', () => {
  it.each(['Clave2026', 'mi-clave-segura-1', 'Zorro123', 'ñandú2026', 'a1b2c3d4'])('acepta "%s"', (password) => {
    expect(passwordProblem(password)).toBeNull();
  });

  it('exige al menos 8 caracteres', () => {
    expect(passwordProblem('Ab1')).toContain('al menos 8 caracteres');
    expect(passwordProblem('Abcde12')).toContain('al menos 8 caracteres');
  });

  it('exige letras y números', () => {
    expect(passwordProblem('sololetrasaqui')).toContain('letras y números');
    expect(passwordProblem('1234567890123')).toContain('letras y números');
  });

  it('rechaza las contraseñas más comunes (sin importar mayúsculas)', () => {
    for (const weak of ['password1', 'Password123', 'CONTRASENA123', 'fidelity123', 'qwerty123', 'hola1234']) {
      expect(passwordProblem(weak)).toContain('muy común');
    }
  });

  it('rechaza las que repiten el mismo carácter', () => {
    expect(passwordProblem('aaaaaaa1')).toContain('muy común');
  });

  it('no pasa de 72 caracteres (el límite de bcrypt)', () => {
    expect(passwordProblem('a1' + 'b'.repeat(70))).toBeNull();
    expect(passwordProblem('a1' + 'b'.repeat(71))).toContain('demasiado larga');
  });

  it('un valor que no es texto no sirve', () => {
    expect(passwordProblem(undefined)).not.toBeNull();
    expect(passwordProblem(12345678)).not.toBeNull();
  });
});

describe('las contraseñas se validan al registrarse, recuperar y cambiar', () => {
  const register = (password: string) =>
    plainToInstance(RegisterDto, { email: 'ana@mail.com', password, fullName: 'Ana' });

  it('registro: una clave débil se rechaza con el motivo', async () => {
    const errors = await validate(register('123456'));

    const message = Object.values(errors[0].constraints ?? {}).join(' ');
    expect(message).toContain('al menos 8 caracteres');
  });

  it('registro: una clave sin números se rechaza', async () => {
    const errors = await validate(register('sololetrasaqui'));

    expect(Object.values(errors[0].constraints ?? {}).join(' ')).toContain('letras y números');
  });

  it('registro: una clave buena pasa', async () => {
    expect(await validate(register('Clave2026'))).toHaveLength(0);
  });

  it('recuperación: la nueva clave sigue las mismas reglas', async () => {
    const weak = plainToInstance(ResetPasswordDto, { email: 'ana@mail.com', code: '123456', newPassword: 'abc' });
    const good = plainToInstance(ResetPasswordDto, { email: 'ana@mail.com', code: '123456', newPassword: 'Nueva2026' });

    expect((await validate(weak)).length).toBeGreaterThan(0);
    expect(await validate(good)).toHaveLength(0);
  });

  it('cambio de clave: la nueva sigue las mismas reglas', async () => {
    const weak = plainToInstance(ChangePasswordDto, { currentPassword: 'Anterior1', newPassword: 'corta' });
    const good = plainToInstance(ChangePasswordDto, { currentPassword: 'Anterior1', newPassword: 'Nueva2026' });

    expect((await validate(weak)).length).toBeGreaterThan(0);
    expect(await validate(good)).toHaveLength(0);
  });
});
