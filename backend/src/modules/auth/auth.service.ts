import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomInt } from 'crypto';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { RegisterDto, LoginDto, ForgotPasswordDto, ResetPasswordDto } from './dto/auth.dto';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { NotificationsService } from '../notifications/notifications.service';
import { MailService } from '../mail/mail.service';
import { ReferralsService } from '../referrals/referrals.service';
import { passwordChangedEmail, passwordResetEmail } from '../mail/mail-templates';

/** Cuánto dura un código de recuperación, cada cuánto se puede pedir otro y cuántos fallos admite. */
const RESET_CODE_TTL_MS = 15 * 60 * 1000;
const RESET_RESEND_MS = 60 * 1000;
const RESET_MAX_ATTEMPTS = 5;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectRepository(Profile)
    private readonly profileRepository: Repository<Profile>,
    private readonly jwtService: JwtService,
    private readonly notificationsService: NotificationsService,
    private readonly mailService: MailService,
    private readonly referralsService: ReferralsService,
  ) {}

  async register(dto: RegisterDto) {
    const existing = await this.profileRepository.findOne({
      where: { email: dto.email.toLowerCase().trim() },
    });

    if (existing) {
      throw new ConflictException('El correo electronico ya esta registrado');
    }

    // Código de un amigo: se revisa antes de crear la cuenta, para avisar si no sirve.
    const referralCode = dto.referralCode?.trim();
    const useReferral = !!referralCode && (dto.role ?? UserRole.CLIENT) === UserRole.CLIENT;
    if (useReferral) await this.referralsService.validateCode(referralCode!);

    // Solo se puede registrar un cliente o un dueño de negocio. El administrador
    // lo asigna el sistema y el aprobador lo asigna un dueño desde su equipo.
    let roleToAssign = dto.role || UserRole.CLIENT;
    if (roleToAssign !== UserRole.CLIENT && roleToAssign !== UserRole.BUSINESS) {
      roleToAssign = UserRole.CLIENT;
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(dto.password, salt);

    const profile = this.profileRepository.create({
      email: dto.email.toLowerCase().trim(),
      fullName: dto.fullName.trim(),
      role: roleToAssign,
      passwordHash,
      phone: dto.phone || null,
      // Solo los clientes tienen cumpleaños que celebrar con sus locales.
      birthDate: roleToAssign === UserRole.CLIENT ? dto.birthDate || null : null,
      avatarUrl: dto.avatarUrl || null,
      fcmToken: dto.fcmToken || null,
      isDemo: dto.isDemo ?? false,
    });

    const savedProfile = await this.profileRepository.save(profile);

    // El amigo queda invitado: con su primer escaneo aprobado ganan los dos.
    if (useReferral) {
      try {
        await this.referralsService.redeem(savedProfile.id, referralCode!);
      } catch (error) {
        this.logger.warn(`No se pudo aplicar el código de amigo: ${error.message}`);
      }
    }

    // Notify admins
    const notificationTitle =
      roleToAssign === UserRole.BUSINESS ? 'Nueva Cuenta de Negocio' : 'Nuevo Cliente';
    const notificationBody = `${savedProfile.fullName} creo cuenta como ${roleToAssign}.`;
    await this.notificationsService.broadcastToAdmins(
      notificationTitle,
      notificationBody,
      '/admin_users',
    );

    const token = this.generateToken(savedProfile);

    return {
      user: {
        id: savedProfile.id,
        email: savedProfile.email,
        fullName: savedProfile.fullName,
        role: savedProfile.role,
        avatarUrl: savedProfile.avatarUrl,
        phone: savedProfile.phone,
        birthDate: savedProfile.birthDate,
        hasSeenWelcome: savedProfile.hasSeenWelcome ?? false,
        isDemo: savedProfile.isDemo,
      },
      accessToken: token,
    };
  }

  async login(dto: LoginDto) {
    const email = dto.email.toLowerCase().trim();
    const user = await this.profileRepository
      .createQueryBuilder('profile')
      .addSelect('profile.passwordHash')
      .where('profile.email = :email', { email })
      .getOne();

    if (!user) {
      throw new UnauthorizedException('Credenciales invalidas');
    }

    if (!user.passwordHash) {
      throw new UnauthorizedException('El usuario no tiene contrasena configurada');
    }

    const isMatch = await bcrypt.compare(dto.password, user.passwordHash);
    if (!isMatch) {
      throw new UnauthorizedException('Credenciales invalidas');
    }

    if (dto.fcmToken && dto.fcmToken !== user.fcmToken) {
      user.fcmToken = dto.fcmToken;
      await this.profileRepository.save(user);
    }

    const token = this.generateToken(user);

    return {
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        role: user.role,
        avatarUrl: user.avatarUrl,
        phone: user.phone,
        birthDate: user.birthDate,
        hasSeenWelcome: user.hasSeenWelcome ?? false,
        fcmToken: user.fcmToken,
        isDemo: user.isDemo,
      },
      accessToken: token,
    };
  }

  /**
   * Paso 1 de la recuperación: envía un código de 6 dígitos al correo. La
   * respuesta es la misma exista o no la cuenta (no revela qué correos están
   * registrados) y se espera un minuto entre envíos.
   */
  async forgotPassword(dto: ForgotPasswordDto) {
    const generic = {
      message: 'Si el correo está registrado, recibirás un código para restablecer tu contraseña',
    };
    const email = dto.email.toLowerCase().trim();
    const user = await this.profileRepository.findOne({
      where: { email },
      select: ['id', 'email', 'fullName', 'language', 'resetCodeExpiresAt'],
    });
    if (!user) return generic;

    const issuedAt = user.resetCodeExpiresAt
      ? user.resetCodeExpiresAt.getTime() - RESET_CODE_TTL_MS
      : 0;
    if (Date.now() - issuedAt < RESET_RESEND_MS) return generic;

    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    await this.profileRepository.update(
      { id: user.id },
      {
        resetCodeHash: await bcrypt.hash(code, 8),
        resetCodeExpiresAt: new Date(Date.now() + RESET_CODE_TTL_MS),
        resetAttempts: 0,
      },
    );

    const minutes = RESET_CODE_TTL_MS / 60000;
    // El correo sale en el idioma de la app de la persona.
    const sent = await this.mailService.sendContent(
      user.email,
      passwordResetEmail({ name: user.fullName, code, minutes, language: user.language }),
    );
    if (!sent) this.logger.error(`No se pudo enviar el código de recuperación a ${user.email}`);
    return generic;
  }

  /** Paso 2: con el código correcto y vigente se guarda la nueva contraseña. */
  async resetPassword(dto: ResetPasswordDto) {
    const invalid = new BadRequestException('Código inválido o vencido');
    const user = await this.profileRepository.findOne({
      where: { email: dto.email.toLowerCase().trim() },
      select: ['id', 'email', 'fullName', 'language', 'resetCodeHash', 'resetCodeExpiresAt', 'resetAttempts'],
    });

    if (
      !user ||
      !user.resetCodeHash ||
      !user.resetCodeExpiresAt ||
      user.resetCodeExpiresAt.getTime() < Date.now() ||
      user.resetAttempts >= RESET_MAX_ATTEMPTS
    ) {
      throw invalid;
    }

    if (!(await bcrypt.compare(dto.code, user.resetCodeHash))) {
      await this.profileRepository.update({ id: user.id }, { resetAttempts: user.resetAttempts + 1 });
      throw invalid;
    }

    await this.profileRepository.update(
      { id: user.id },
      {
        passwordHash: await bcrypt.hash(dto.newPassword, await bcrypt.genSalt(10)),
        resetCodeHash: null,
        resetCodeExpiresAt: null,
        resetAttempts: 0,
      },
    );

    // Aviso de seguridad: si no fue la persona, sabe que debe actuar. Un fallo
    // del correo no cambia el resultado.
    void this.mailService
      .sendContent(user.email, passwordChangedEmail({ name: user.fullName, language: user.language }))
      .catch((e) => this.logger.warn(`No se pudo avisar del cambio de contraseña: ${e.message}`));
    return { message: 'Contraseña actualizada. Ya puedes iniciar sesión' };
  }

  async getProfile(userId: string) {
    const user = await this.profileRepository.findOne({
      where: { id: userId },
    });

    if (!user) {
      throw new NotFoundException('Perfil de usuario no encontrado');
    }

    return user;
  }

  private generateToken(user: Profile): string {
    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      fullName: user.fullName,
    };

    return this.jwtService.sign(payload);
  }
}
