import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Business } from '../../database/entities/business.entity';
import { BusinessMember } from '../../database/entities/business-member.entity';
import { UserRole } from '../../database/entities/profile.entity';

/**
 * Decide quién puede hacer qué sobre un negocio. Es el único lugar donde se
 * define esa regla.
 *
 * - **Gestionar** (editar el negocio, QR, pagos, equipo, estadísticas): el
 *   administrador y el dueño.
 * - **Operar** (aprobar escaneos, entregar premios, moderar opiniones): lo
 *   anterior y los aprobadores asignados a ese negocio.
 */
@Injectable()
export class BusinessAccessService {
  constructor(
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(BusinessMember)
    private readonly memberRepository: Repository<BusinessMember>,
  ) {}

  async canManage(userId: string, role: UserRole, businessId: string): Promise<boolean> {
    if (role === UserRole.ADMIN) return true;
    const business = await this.businessRepository.findOne({
      where: { id: businessId },
      select: ['id', 'ownerId'],
    });
    return !!business && business.ownerId === userId;
  }

  async canOperate(userId: string, role: UserRole, businessId: string): Promise<boolean> {
    if (await this.canManage(userId, role, businessId)) return true;
    if (role !== UserRole.APPROVER) return false;
    return this.memberRepository.exists({ where: { businessId, userId } });
  }

  /** Ids de los negocios donde el usuario es aprobador. */
  async businessIdsForMember(userId: string): Promise<string[]> {
    const memberships = await this.memberRepository.find({ where: { userId } });
    return memberships.map((m) => m.businessId);
  }
}
