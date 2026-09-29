import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';

describe('AuthService', () => {
  let service: AuthService;
  let profileRepo: any;
  let jwtService: any;
  let notificationsService: any;

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
});
