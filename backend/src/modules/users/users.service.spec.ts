import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import {
  BadRequestException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { UsersService } from './users.service';
import { Profile } from '../../database/entities/profile.entity';

describe('UsersService.changePassword', () => {
  let service: UsersService;
  let profileRepo: any;
  let queryBuilder: any;

  const currentHash = bcrypt.hashSync('clave-actual', 4);

  beforeEach(async () => {
    queryBuilder = {
      addSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      getOne: jest.fn(),
    };
    profileRepo = {
      createQueryBuilder: jest.fn(() => queryBuilder),
      save: jest.fn((entity) => Promise.resolve(entity)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: getRepositoryToken(Profile), useValue: profileRepo },
        { provide: DataSource, useValue: {} },
      ],
    }).compile();

    service = module.get(UsersService);
  });

  it('guarda el nuevo hash cuando la contrasena actual es correcta', async () => {
    const profile = { id: 'u1', passwordHash: currentHash };
    queryBuilder.getOne.mockResolvedValue(profile);

    const result = await service.changePassword('u1', {
      currentPassword: 'clave-actual',
      newPassword: 'clave-nueva',
    });

    expect(result.message).toBeDefined();
    expect(profileRepo.save).toHaveBeenCalledTimes(1);
    const saved = profileRepo.save.mock.calls[0][0];
    expect(saved.passwordHash).not.toBe(currentHash);
    expect(await bcrypt.compare('clave-nueva', saved.passwordHash)).toBe(true);
  });

  it('rechaza si la contrasena actual es incorrecta y no guarda nada', async () => {
    queryBuilder.getOne.mockResolvedValue({ id: 'u1', passwordHash: currentHash });

    await expect(
      service.changePassword('u1', { currentPassword: 'otra', newPassword: 'clave-nueva' }),
    ).rejects.toThrow(UnauthorizedException);
    expect(profileRepo.save).not.toHaveBeenCalled();
  });

  it('rechaza si la nueva contrasena es igual a la actual', async () => {
    queryBuilder.getOne.mockResolvedValue({ id: 'u1', passwordHash: currentHash });

    await expect(
      service.changePassword('u1', {
        currentPassword: 'clave-actual',
        newPassword: 'clave-actual',
      }),
    ).rejects.toThrow(BadRequestException);
    expect(profileRepo.save).not.toHaveBeenCalled();
  });

  it('falla si el perfil no existe', async () => {
    queryBuilder.getOne.mockResolvedValue(null);

    await expect(
      service.changePassword('u1', { currentPassword: 'a', newPassword: 'clave-nueva' }),
    ).rejects.toThrow(NotFoundException);
  });

  it('falla si el usuario no tiene contrasena configurada', async () => {
    queryBuilder.getOne.mockResolvedValue({ id: 'u1', passwordHash: null });

    await expect(
      service.changePassword('u1', { currentPassword: 'a', newPassword: 'clave-nueva' }),
    ).rejects.toThrow(BadRequestException);
  });
});

describe('UsersService.updateLanguage', () => {
  let service: UsersService;
  let profileRepo: any;

  beforeEach(async () => {
    profileRepo = { update: jest.fn().mockResolvedValue({ affected: 1 }) };
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: getRepositoryToken(Profile), useValue: profileRepo },
        { provide: DataSource, useValue: {} },
      ],
    }).compile();
    service = module.get(UsersService);
  });

  it('guarda el idioma del usuario', async () => {
    const result = await service.updateLanguage('u1', { language: 'en' });

    expect(profileRepo.update).toHaveBeenCalledWith({ id: 'u1' }, { language: 'en' });
    expect(result).toEqual({ language: 'en' });
  });

  it('un usuario que no existe se rechaza', async () => {
    profileRepo.update.mockResolvedValue({ affected: 0 });

    await expect(service.updateLanguage('nadie', { language: 'es' })).rejects.toBeInstanceOf(NotFoundException);
  });
});
