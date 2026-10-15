import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { BusinessAccessService } from './business-access.service';
import { Business } from '../../database/entities/business.entity';
import { BusinessMember } from '../../database/entities/business-member.entity';
import { UserRole } from '../../database/entities/profile.entity';

describe('BusinessAccessService', () => {
  let service: BusinessAccessService;
  let businessRepo: any;
  let memberRepo: any;

  beforeEach(async () => {
    businessRepo = { findOne: jest.fn().mockResolvedValue({ id: 'b1', ownerId: 'owner-1' }) };
    memberRepo = { exists: jest.fn().mockResolvedValue(false), find: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BusinessAccessService,
        { provide: getRepositoryToken(Business), useValue: businessRepo },
        { provide: getRepositoryToken(BusinessMember), useValue: memberRepo },
      ],
    }).compile();

    service = module.get(BusinessAccessService);
  });

  describe('canManage', () => {
    it('el administrador gestiona cualquier negocio sin consultar nada', async () => {
      expect(await service.canManage('a1', UserRole.ADMIN, 'b1')).toBe(true);
      expect(businessRepo.findOne).not.toHaveBeenCalled();
    });

    it('el dueño gestiona su negocio', async () => {
      expect(await service.canManage('owner-1', UserRole.BUSINESS, 'b1')).toBe(true);
    });

    it('otro dueño no gestiona un negocio ajeno', async () => {
      expect(await service.canManage('owner-2', UserRole.BUSINESS, 'b1')).toBe(false);
    });

    it('un aprobador no gestiona (solo opera)', async () => {
      memberRepo.exists.mockResolvedValue(true);

      expect(await service.canManage('ap-1', UserRole.APPROVER, 'b1')).toBe(false);
    });

    it('un negocio inexistente no se puede gestionar', async () => {
      businessRepo.findOne.mockResolvedValue(null);

      expect(await service.canManage('owner-1', UserRole.BUSINESS, 'nada')).toBe(false);
    });
  });

  describe('canOperate', () => {
    it('el dueño y el administrador operan', async () => {
      expect(await service.canOperate('owner-1', UserRole.BUSINESS, 'b1')).toBe(true);
      expect(await service.canOperate('a1', UserRole.ADMIN, 'b1')).toBe(true);
    });

    it('un aprobador asignado a ese negocio opera', async () => {
      memberRepo.exists.mockResolvedValue(true);

      expect(await service.canOperate('ap-1', UserRole.APPROVER, 'b1')).toBe(true);
      expect(memberRepo.exists).toHaveBeenCalledWith({ where: { businessId: 'b1', userId: 'ap-1' } });
    });

    it('un aprobador de otro negocio no opera', async () => {
      expect(await service.canOperate('ap-1', UserRole.APPROVER, 'b1')).toBe(false);
    });

    it('un cliente jamás opera, aunque figure como miembro', async () => {
      memberRepo.exists.mockResolvedValue(true);

      expect(await service.canOperate('c1', UserRole.CLIENT, 'b1')).toBe(false);
      expect(memberRepo.exists).not.toHaveBeenCalled();
    });
  });

  it('lista los negocios donde el usuario es aprobador', async () => {
    memberRepo.find.mockResolvedValue([{ businessId: 'b1' }, { businessId: 'b2' }]);

    expect(await service.businessIdsForMember('ap-1')).toEqual(['b1', 'b2']);
  });
});
