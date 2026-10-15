import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import {
  BusinessMembersService,
  MAX_APPROVERS_PER_BUSINESS,
} from './business-members.service';
import { BusinessAccessService } from './business-access.service';
import { Business } from '../../database/entities/business.entity';
import { BusinessMember } from '../../database/entities/business-member.entity';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';

describe('BusinessMembersService', () => {
  let service: BusinessMembersService;
  let memberRepo: any;
  let profileRepo: any;
  let businessRepo: any;
  let access: any;
  let notifications: any;
  let queryBuilder: any;

  const owner = { id: 'owner-1', role: UserRole.BUSINESS };
  const client = { id: 'c1', email: 'luis@mail.com', fullName: 'Luis', role: UserRole.CLIENT, phone: null };

  beforeEach(async () => {
    queryBuilder = {
      where: jest.fn().mockReturnThis(),
      getOne: jest.fn().mockResolvedValue({ ...client }),
    };
    profileRepo = {
      createQueryBuilder: jest.fn(() => queryBuilder),
      save: jest.fn((p) => Promise.resolve(p)),
      update: jest.fn().mockResolvedValue(undefined),
    };
    memberRepo = {
      find: jest.fn().mockResolvedValue([]),
      findOne: jest.fn(),
      exists: jest.fn().mockResolvedValue(false),
      count: jest.fn().mockResolvedValue(0),
      create: jest.fn((d) => d),
      save: jest.fn((m) => Promise.resolve({ id: 'm1', createdAt: new Date(), ...m })),
      remove: jest.fn().mockResolvedValue(undefined),
    };
    businessRepo = {
      findOne: jest.fn().mockResolvedValue({ id: 'b1', name: 'Cafe Aurora', ownerId: 'owner-1' }),
    };
    access = { canManage: jest.fn().mockResolvedValue(true) };
    notifications = { sendToUser: jest.fn().mockResolvedValue(true) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BusinessMembersService,
        { provide: getRepositoryToken(BusinessMember), useValue: memberRepo },
        { provide: getRepositoryToken(Profile), useValue: profileRepo },
        { provide: getRepositoryToken(Business), useValue: businessRepo },
        { provide: BusinessAccessService, useValue: access },
        { provide: NotificationsService, useValue: notifications },
      ],
    }).compile();

    service = module.get(BusinessMembersService);
  });

  describe('add', () => {
    it('convierte a un cliente en aprobador, lo suma al equipo y le avisa', async () => {
      const member = await service.add('b1', owner, ' Luis@Mail.com ');

      expect(queryBuilder.where).toHaveBeenCalledWith('LOWER(profile.email) = LOWER(:email)', {
        email: 'Luis@Mail.com',
      });
      expect(profileRepo.save).toHaveBeenCalledWith(expect.objectContaining({ role: UserRole.APPROVER }));
      expect(memberRepo.save).toHaveBeenCalled();
      expect(member).toMatchObject({ userId: 'c1', email: 'luis@mail.com', fullName: 'Luis' });
      expect(notifications.sendToUser).toHaveBeenCalledWith(
        'c1',
        expect.any(String),
        expect.stringContaining('Cafe Aurora'),
        expect.anything(),
      );
    });

    it('un aprobador existente puede sumarse a otro negocio sin cambiar de rol', async () => {
      queryBuilder.getOne.mockResolvedValue({ ...client, role: UserRole.APPROVER });

      await service.add('b1', owner, 'luis@mail.com');

      expect(profileRepo.save).not.toHaveBeenCalled();
      expect(memberRepo.save).toHaveBeenCalled();
    });

    it('solo el dueño o el admin gestionan el equipo', async () => {
      access.canManage.mockResolvedValue(false);

      await expect(service.add('b1', owner, 'luis@mail.com')).rejects.toBeInstanceOf(
        ForbiddenException,
      );
      expect(memberRepo.save).not.toHaveBeenCalled();
    });

    it('pide que se registre si el correo no existe', async () => {
      queryBuilder.getOne.mockResolvedValue(null);

      await expect(service.add('b1', owner, 'nadie@mail.com')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('no deja que el dueño se asigne a si mismo', async () => {
      queryBuilder.getOne.mockResolvedValue({ ...client, id: 'owner-1' });

      await expect(service.add('b1', owner, 'luis@mail.com')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it.each([UserRole.BUSINESS, UserRole.ADMIN])(
      'no convierte una cuenta %s en aprobador',
      async (role) => {
        queryBuilder.getOne.mockResolvedValue({ ...client, role });

        await expect(service.add('b1', owner, 'luis@mail.com')).rejects.toBeInstanceOf(
          BadRequestException,
        );
        expect(profileRepo.save).not.toHaveBeenCalled();
      },
    );

    it('rechaza a quien ya es aprobador del negocio', async () => {
      memberRepo.exists.mockResolvedValue(true);

      await expect(service.add('b1', owner, 'luis@mail.com')).rejects.toBeInstanceOf(
        ConflictException,
      );
    });

    it('limita la cantidad de aprobadores por negocio', async () => {
      memberRepo.count.mockResolvedValue(MAX_APPROVERS_PER_BUSINESS);

      await expect(service.add('b1', owner, 'luis@mail.com')).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(profileRepo.save).not.toHaveBeenCalled();
    });

    it('si falla la notificacion igual queda asignado', async () => {
      notifications.sendToUser.mockRejectedValue(new Error('fcm caido'));

      const member = await service.add('b1', owner, 'luis@mail.com');

      expect(member.userId).toBe('c1');
    });
  });

  describe('remove', () => {
    it('quita al aprobador y, sin mas negocios, vuelve a ser cliente', async () => {
      memberRepo.findOne.mockResolvedValue({ id: 'm1', businessId: 'b1', userId: 'c1' });
      memberRepo.count.mockResolvedValue(0);

      await service.remove('b1', 'c1', owner);

      expect(memberRepo.remove).toHaveBeenCalled();
      expect(profileRepo.update).toHaveBeenCalledWith(
        { id: 'c1', role: UserRole.APPROVER },
        { role: UserRole.CLIENT },
      );
    });

    it('si sigue en otro negocio conserva su rol de aprobador', async () => {
      memberRepo.findOne.mockResolvedValue({ id: 'm1', businessId: 'b1', userId: 'c1' });
      memberRepo.count.mockResolvedValue(1);

      await service.remove('b1', 'c1', owner);

      expect(profileRepo.update).not.toHaveBeenCalled();
    });

    it('falla si esa persona no es parte del equipo', async () => {
      memberRepo.findOne.mockResolvedValue(null);

      await expect(service.remove('b1', 'c1', owner)).rejects.toBeInstanceOf(NotFoundException);
    });

    it('solo el dueño o el admin pueden quitar aprobadores', async () => {
      access.canManage.mockResolvedValue(false);

      await expect(service.remove('b1', 'c1', owner)).rejects.toBeInstanceOf(ForbiddenException);
      expect(memberRepo.remove).not.toHaveBeenCalled();
    });
  });

  describe('list', () => {
    it('lista el equipo con los datos de cada persona', async () => {
      memberRepo.find.mockResolvedValue([
        { id: 'm1', userId: 'c1', role: 'approver', createdAt: new Date(), user: client },
      ]);

      const list = await service.list('b1', owner);

      expect(list).toEqual([
        expect.objectContaining({ userId: 'c1', email: 'luis@mail.com', fullName: 'Luis' }),
      ]);
    });

    it('no lista el equipo a quien no gestiona el negocio', async () => {
      access.canManage.mockResolvedValue(false);

      await expect(service.list('b1', owner)).rejects.toBeInstanceOf(ForbiddenException);
    });
  });
});
