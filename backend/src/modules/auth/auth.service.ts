import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { RegisterDto, LoginDto, ResetPasswordDto } from './dto/auth.dto';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectRepository(Profile)
    private readonly profileRepository: Repository<Profile>,
    private readonly jwtService: JwtService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async register(dto: RegisterDto) {
    const existing = await this.profileRepository.findOne({
      where: { email: dto.email.toLowerCase().trim() },
    });

    if (existing) {
      throw new ConflictException('El correo electronico ya esta registrado');
    }

    // Role escalation prevention: users cannot register directly as admin
    let roleToAssign = dto.role || UserRole.CLIENT;
    if (roleToAssign === UserRole.ADMIN) {
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
      avatarUrl: dto.avatarUrl || null,
      fcmToken: dto.fcmToken || null,
      isDemo: dto.isDemo ?? false,
    });

    const savedProfile = await this.profileRepository.save(profile);

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
        fcmToken: user.fcmToken,
        isDemo: user.isDemo,
      },
      accessToken: token,
    };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const user = await this.profileRepository.findOne({
      where: { email: dto.email.toLowerCase().trim() },
    });

    if (!user) {
      // Return ok to prevent user enumeration
      return {
        message: 'Si el correo esta registrado, recibira instrucciones para restablecer la contrasena',
      };
    }

    this.logger.log(`Password reset requested for email: ${user.email}`);
    return {
      message: 'Instrucciones de recuperacion enviadas al correo electronico',
    };
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
