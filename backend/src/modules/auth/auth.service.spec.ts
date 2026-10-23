import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { BadRequestException, ConflictException, UnauthorizedException } from '@nestjs/common';
import { MailService } from '../mail/mail.service';
import * as bcrypt from 'bcrypt';

describe('AuthService', () => {
  let service: AuthService;
  let profileRepo: any;
  let jwtService: any;
  let notificationsService: any;
  let mailService: any;

  beforeEach(async () => {
    profileRepo = {
      findOne: jest.fn(),
      create: jest.fn((dto) => ({ id: 'uuid-1', ...dto })),
      save: jest.fn((entity) => Promise.resolve({ id: 'uuid-1', ...entity })),
      createQueryBuilder: jest.fn(),
    };

    jwtService = {
      sign: jest.fn(() => 'test.jwt.token'),
    };

    notificationsService = {
      broadcastToAdmins: jest.fn().mockResolvedValue(undefined),
    };

    mailService = {
      send: jest.fn().mockResolvedValue(true),
      sendContent: jest.fn().mockResolvedValue(true),
    };
    profileRepo.update = jest.fn().mockResolvedValue(undefined);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: getRepositoryToken(Profile),
          useValue: profileRepo,
        },
        {
          provide: JwtService,
          useValue: jwtService,
        },
        {
          provide: NotificationsService,
          useValue: notificationsService,
        },
        { provide: MailService, useValue: mailService },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should register a new client user and return JWT token', async () => {
    profileRepo.findOne.mockResolvedValue(null);

    const result = await service.register({
      email: 'client@fidelity.test',
      password: 'password123',
      fullName: 'Juan Perez',
      role: UserRole.CLIENT,
    });

    expect(result).toBeDefined();
    expect(result.accessToken).toBe('test.jwt.token');
    expect(result.user.email).toBe('client@fidelity.test');
    expect(result.user.role).toBe(UserRole.CLIENT);
    expect(notificationsService.broadcastToAdmins).toHaveBeenCalled();
  });

  it('should prevent direct escalation to admin upon registration', async () => {
    profileRepo.findOne.mockResolvedValue(null);

    const result = await service.register({
      email: 'attacker@fidelity.test',
      password: 'password123',
      fullName: 'Attacker',
      role: UserRole.ADMIN,
    });

    expect(result.user.role).toBe(UserRole.CLIENT);
  });

  it('should throw ConflictException if email is already registered', async () => {
    profileRepo.findOne.mockResolvedValue({ id: 'existing-id', email: 'client@fidelity.test' });

    await expect(
      service.register({
        email: 'client@fidelity.test',
        password: 'password123',
        fullName: 'Juan Perez',
      }),
    ).rejects.toThrow(ConflictException);
  });
  describe('fecha de nacimiento', () => {
    it('un cliente puede dar su fecha al registrarse y vuelve en su perfil', async () => {
      profileRepo.findOne.mockResolvedValue(null);

      const result = await service.register({
        email: 'ana@mail.com',
        password: 'secret123',
        fullName: 'Ana',
        birthDate: '1998-03-14',
      });

      expect(profileRepo.create).toHaveBeenCalledWith(expect.objectContaining({ birthDate: '1998-03-14' }));
      expect(result.user.birthDate).toBe('1998-03-14');
    });

    it('es opcional', async () => {
      profileRepo.findOne.mockResolvedValue(null);

      const result = await service.register({ email: 'ana@mail.com', password: 'secret123', fullName: 'Ana' });

      expect(profileRepo.create).toHaveBeenCalledWith(expect.objectContaining({ birthDate: null }));
      expect(result.user.birthDate).toBeNull();
    });

    it('un dueño de negocio no guarda fecha: no tiene cumpleaños que celebrar con locales', async () => {
      profileRepo.findOne.mockResolvedValue(null);

      await service.register({
        email: 'dueno@mail.com',
        password: 'secret123',
        fullName: 'Dueño',
        role: UserRole.BUSINESS,
        birthDate: '1980-01-01',
      });

      expect(profileRepo.create).toHaveBeenCalledWith(expect.objectContaining({ birthDate: null }));
    });
  });

  it('no permite registrarse directamente como aprobador', async () => {
    profileRepo.findOne.mockResolvedValue(null);

    const result = await service.register({
      email: 'x@mail.com',
      password: 'secret123',
      fullName: 'X',
      role: UserRole.APPROVER,
    });

    expect(result.user.role).toBe(UserRole.CLIENT);
  });

  describe('recuperación de contraseña', () => {
    const sentMail = () => mailService.sendContent.mock.calls[0];
    const codeFromMail = () => /es: (\d{6})/.exec(sentMail()[1].text)![1];

    it('envía un código de 6 dígitos y guarda solo su hash', async () => {
      profileRepo.findOne.mockResolvedValue({ id: 'u1', email: 'ana@mail.com', fullName: 'Ana', resetCodeExpiresAt: null });

      const result = await service.forgotPassword({ email: ' ANA@mail.com ' });

      expect(result.message).toContain('Si el correo está registrado');
      const code = codeFromMail();
      expect(code).toMatch(/^\d{6}$/);
      const update = profileRepo.update.mock.calls[0][1];
      expect(update.resetCodeHash).not.toContain(code);
      expect(await bcrypt.compare(code, update.resetCodeHash)).toBe(true);
      expect(update.resetCodeExpiresAt.getTime()).toBeGreaterThan(Date.now() + 14 * 60000);
      expect(update.resetAttempts).toBe(0);
    });

    it('el correo sale con la plantilla de marca, a su dueño y en su idioma', async () => {
      profileRepo.findOne.mockResolvedValue({ id: 'u1', email: 'ana@mail.com', fullName: 'Ana', language: 'en', resetCodeExpiresAt: null });

      await service.forgotPassword({ email: 'ana@mail.com' });

      const [to, content] = sentMail();
      expect(to).toBe('ana@mail.com');
      expect(content.subject).toBe('Your Fidelity password reset code');
      expect(content.html).toContain('FIDELITY');
      expect(content.text).toContain('15 minutes');
    });

    it('en español por defecto', async () => {
      profileRepo.findOne.mockResolvedValue({ id: 'u1', email: 'ana@mail.com', fullName: 'Ana', resetCodeExpiresAt: null });

      await service.forgotPassword({ email: 'ana@mail.com' });

      expect(sentMail()[1].subject).toBe('Tu código para restablecer la contraseña de Fidelity');
    });

    it('responde igual si el correo no existe (no revela cuentas) y no envía nada', async () => {
      profileRepo.findOne.mockResolvedValue(null);

      const result = await service.forgotPassword({ email: 'nadie@mail.com' });

      expect(result.message).toContain('Si el correo está registrado');
      expect(mailService.sendContent).not.toHaveBeenCalled();
      expect(profileRepo.update).not.toHaveBeenCalled();
    });

    it('no reenvía otro código antes de un minuto', async () => {
      // Emitido hace 10 segundos: vence en 15 min - 10 s.
      profileRepo.findOne.mockResolvedValue({
        id: 'u1',
        email: 'ana@mail.com',
        resetCodeExpiresAt: new Date(Date.now() + 15 * 60000 - 10000),
      });

      await service.forgotPassword({ email: 'ana@mail.com' });

      expect(mailService.sendContent).not.toHaveBeenCalled();
    });

    const withCode = async (overrides: any = {}) => ({
      id: 'u1',
      resetCodeHash: await bcrypt.hash('123456', 4),
      resetCodeExpiresAt: new Date(Date.now() + 5 * 60000),
      resetAttempts: 0,
      ...overrides,
    });

    it('con el código correcto cambia la contraseña y borra el código', async () => {
      profileRepo.findOne.mockResolvedValue(await withCode());

      const result = await service.resetPassword({ email: 'ana@mail.com', code: '123456', newPassword: 'nueva-clave' });

      expect(result.message).toContain('actualizada');
      const update = profileRepo.update.mock.calls[0][1];
      expect(await bcrypt.compare('nueva-clave', update.passwordHash)).toBe(true);
      expect(update.resetCodeHash).toBeNull();
      expect(update.resetCodeExpiresAt).toBeNull();
    });

    it('al cambiarla avisa por correo (aviso de seguridad) y un fallo del correo no la deshace', async () => {
      profileRepo.findOne.mockResolvedValue(await withCode({ email: 'ana@mail.com', fullName: 'Ana', language: 'es' }));
      mailService.sendContent.mockRejectedValueOnce(new Error('smtp caído'));

      const result = await service.resetPassword({ email: 'ana@mail.com', code: '123456', newPassword: 'nueva-clave' });
      await new Promise((r) => setImmediate(r));

      expect(result.message).toContain('actualizada');
      const [to, content] = mailService.sendContent.mock.calls[0];
      expect(to).toBe('ana@mail.com');
      expect(content.subject).toBe('Cambiaste la contraseña de tu cuenta de Fidelity');
    });

    it('un código incorrecto se rechaza y suma un intento', async () => {
      profileRepo.findOne.mockResolvedValue(await withCode({ resetAttempts: 2 }));

      await expect(
        service.resetPassword({ email: 'ana@mail.com', code: '000000', newPassword: 'nueva-clave' }),
      ).rejects.toBeInstanceOf(BadRequestException);

      expect(profileRepo.update).toHaveBeenCalledWith({ id: 'u1' }, { resetAttempts: 3 });
    });

    it('tras 5 intentos fallidos el código ya no sirve, ni siquiera el correcto', async () => {
      profileRepo.findOne.mockResolvedValue(await withCode({ resetAttempts: 5 }));

      await expect(
        service.resetPassword({ email: 'ana@mail.com', code: '123456', newPassword: 'nueva-clave' }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(profileRepo.update).not.toHaveBeenCalled();
    });

    it('un código vencido se rechaza', async () => {
      profileRepo.findOne.mockResolvedValue(await withCode({ resetCodeExpiresAt: new Date(Date.now() - 1000) }));

      await expect(
        service.resetPassword({ email: 'ana@mail.com', code: '123456', newPassword: 'nueva-clave' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('sin código pedido o con correo desconocido da el mismo error', async () => {
      for (const found of [null, { id: 'u1', resetCodeHash: null, resetCodeExpiresAt: null, resetAttempts: 0 }]) {
        profileRepo.findOne.mockResolvedValue(found);
        await expect(
          service.resetPassword({ email: 'ana@mail.com', code: '123456', newPassword: 'nueva-clave' }),
        ).rejects.toThrow('Código inválido o vencido');
      }
    });
  });
});
