import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Business } from '../../database/entities/business.entity';
import {
  BusinessMember,
  BusinessMemberRole,
} from '../../database/entities/business-member.entity';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { BusinessAccessService } from './business-access.service';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { SettingsService } from '../settings/settings.service';

/** Máximo de aprobadores por negocio. */
export const MAX_APPROVERS_PER_BUSINESS = 10;

export interface BusinessMemberView {
  id: string;
  userId: string;
  role: BusinessMemberRole;
  fullName: string | null;
  email: string;
  phone: string | null;
  createdAt: Date;
}

/**
 * Equipo de un negocio: el dueño asigna el **rol Aprobador** a una persona ya
 * registrada (por su correo). Al aceptar el rol, la persona usa la app como
 * supervisor del local en vez de como cliente.
 */
@Injectable()
export class BusinessMembersService {
  private readonly logger = new Logger(BusinessMembersService.name);

  constructor(
    @InjectRepository(BusinessMember)
    private readonly memberRepository: Repository<BusinessMember>,
    @InjectRepository(Profile)
    private readonly profileRepository: Repository<Profile>,
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    private readonly businessAccess: BusinessAccessService,
    private readonly notificationsService: NotificationsService,
    private readonly settings: SettingsService,
  ) {}

  async list(businessId: string, requester: { id: string; role: UserRole }) {
    await this.assertCanManage(requester, businessId);
    const members = await this.memberRepository.find({
      where: { businessId },
      relations: ['user'],
      order: { createdAt: 'ASC' },
    });
    return members.map((m) => this.toView(m));
  }

  async add(businessId: string, requester: { id: string; role: UserRole }, email: string) {
    await this.assertCanManage(requester, businessId);

    const business = await this.businessRepository.findOne({
      where: { id: businessId },
      select: ['id', 'name', 'ownerId'],
    });
    if (!business) throw new NotFoundException('Negocio no encontrado');

    const profile = await this.profileRepository
      .createQueryBuilder('profile')
      .where('LOWER(profile.email) = LOWER(:email)', { email: email.trim() })
      .getOne();
    if (!profile) {
      throw new NotFoundException(
        'No existe un usuario con ese correo. Pídele que se registre en la app primero.',
      );
    }
    if (profile.id === business.ownerId) {
      throw new BadRequestException('El dueño del negocio ya tiene todos los permisos');
    }
    if (profile.role !== UserRole.CLIENT && profile.role !== UserRole.APPROVER) {
      throw new BadRequestException(
        'Ese correo pertenece a una cuenta de negocio o de administrador y no puede ser aprobador',
      );
    }

    const existing = await this.memberRepository.exists({
      where: { businessId, userId: profile.id },
    });
    if (existing) throw new ConflictException('Esa persona ya es aprobador de este negocio');

    const count = await this.memberRepository.count({ where: { businessId } });
    const maxApprovers = await this.settings.get(SETTING_KEYS.maxApprovers);
    if (count >= maxApprovers) {
      throw new BadRequestException(
        `Un negocio puede tener hasta ${maxApprovers} aprobadores`,
      );
    }

    if (profile.role === UserRole.CLIENT) {
      profile.role = UserRole.APPROVER;
      await this.profileRepository.save(profile);
    }

    const member = await this.memberRepository.save(
      this.memberRepository.create({
        businessId,
        userId: profile.id,
        role: BusinessMemberRole.APPROVER,
      }),
    );
    member.user = profile;

    try {
      await this.notificationsService.sendToUser(
        profile.id,
        'Ahora eres aprobador',
        `${business.name} te asignó como aprobador. Vuelve a iniciar sesión para ver su panel.`,
        { type: 'approver_assigned' },
      );
    } catch (error) {
      this.logger.warn(`No se pudo notificar al nuevo aprobador: ${error.message}`);
    }

    return this.toView(member);
  }

  async remove(businessId: string, userId: string, requester: { id: string; role: UserRole }) {
    await this.assertCanManage(requester, businessId);

    const member = await this.memberRepository.findOne({ where: { businessId, userId } });
    if (!member) throw new NotFoundException('Esa persona no es parte del equipo');
    await this.memberRepository.remove(member);

    // Sin ningún negocio asignado, vuelve a ser un cliente normal.
    const remaining = await this.memberRepository.count({ where: { userId } });
    if (remaining === 0) {
      await this.profileRepository.update(
        { id: userId, role: UserRole.APPROVER },
        { role: UserRole.CLIENT },
      );
    }
    return { success: true };
  }

  private toView(member: BusinessMember): BusinessMemberView {
    return {
      id: member.id,
      userId: member.userId,
      role: member.role,
      fullName: member.user?.fullName ?? null,
      email: member.user?.email,
      phone: member.user?.phone ?? null,
      createdAt: member.createdAt,
    };
  }

  private async assertCanManage(requester: { id: string; role: UserRole }, businessId: string) {
    const allowed = await this.businessAccess.canManage(requester.id, requester.role, businessId);
    if (!allowed) {
      throw new ForbiddenException('Solo el dueño del negocio puede gestionar su equipo');
    }
  }
}
