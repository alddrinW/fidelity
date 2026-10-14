import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { BusinessesService, DEFAULT_CATEGORIES } from './businesses.service';
import { Business } from '../../database/entities/business.entity';
import { BusinessCategory } from '../../database/entities/business-category.entity';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Scan } from '../../database/entities/scan.entity';
import { Reward } from '../../database/entities/reward.entity';
import { Profile } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';

describe('BusinessesService - categorias base', () => {
  let service: BusinessesService;
  let categoryRepo: any;

  beforeEach(async () => {
    categoryRepo = {
      count: jest.fn(),
      create: jest.fn((items) => items),
      save: jest.fn((items) => Promise.resolve(items)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BusinessesService,
        { provide: getRepositoryToken(BusinessCategory), useValue: categoryRepo },
        { provide: getRepositoryToken(Business), useValue: {} },
        { provide: getRepositoryToken(LoyaltyCard), useValue: {} },
        { provide: getRepositoryToken(Scan), useValue: {} },
        { provide: getRepositoryToken(Reward), useValue: {} },
        { provide: getRepositoryToken(Profile), useValue: {} },
        { provide: NotificationsService, useValue: {} },
      ],
    }).compile();

    service = module.get(BusinessesService);
  });

  it('crea las categorias base cuando la tabla esta vacia', async () => {
    categoryRepo.count.mockResolvedValue(0);

    const created = await service.seedDefaultCategories();

    expect(created).toBe(DEFAULT_CATEGORIES.length);
    expect(categoryRepo.save).toHaveBeenCalledTimes(1);
    const saved = categoryRepo.save.mock.calls[0][0];
    expect(saved.map((c: any) => c.name)).toEqual(DEFAULT_CATEGORIES.map((c) => c.name));
  });

  it('no toca nada si ya existen categorias', async () => {
    categoryRepo.count.mockResolvedValue(3);

    expect(await service.seedDefaultCategories()).toBe(0);
    expect(categoryRepo.save).not.toHaveBeenCalled();
  });

  it('no impide el arranque si la siembra falla', async () => {
    categoryRepo.count.mockRejectedValue(new Error('db caida'));

    await expect(service.onModuleInit()).resolves.toBeUndefined();
    expect(categoryRepo.save).not.toHaveBeenCalled();
  });

  it('las categorias base tienen nombres unicos', () => {
    const names = DEFAULT_CATEGORIES.map((c) => c.name);
    expect(new Set(names).size).toBe(names.length);
  });
});
