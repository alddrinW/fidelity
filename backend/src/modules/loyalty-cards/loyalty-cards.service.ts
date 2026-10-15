import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { LoyaltyCard } from '../../database/entities/loyalty-card.entity';
import { Business } from '../../database/entities/business.entity';
import { Scan, ScanStatus } from '../../database/entities/scan.entity';
import { Reward, RewardStatus } from '../../database/entities/reward.entity';
import { RewardTransferHistory } from '../../database/entities/reward-transfer-history.entity';
import { UserRole } from '../../database/entities/profile.entity';

@Injectable()
export class LoyaltyCardsService {
  private readonly logger = new Logger(LoyaltyCardsService.name);

  constructor(
    @InjectRepository(LoyaltyCard)
    private readonly cardRepository: Repository<LoyaltyCard>,
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(Scan)
    private readonly scanRepository: Repository<Scan>,
    @InjectRepository(Reward)
    private readonly rewardRepository: Repository<Reward>,
    @InjectRepository(RewardTransferHistory)
    private readonly transferRepository: Repository<RewardTransferHistory>,
  ) {}

  async getOrCreateLoyaltyCard(userId: string, businessId: string): Promise<LoyaltyCard> {
    const existing = await this.cardRepository.findOne({
      where: { userId, businessId },
      relations: ['business', 'business.categoryRef'],
    });

    if (existing) {
      return existing;
    }

    const business = await this.businessRepository.findOne({ where: { id: businessId } });
    if (!business) {
      throw new NotFoundException('Negocio no encontrado');
    }

    // Always create with 0 points for security (replicating hardened DB rules)
    const newCard = this.cardRepository.create({
      userId,
      businessId,
      currentPoints: 0,
      totalPointsLifetime: 0,
      rewardsClaimed: 0,
      lastScanAt: null,
    });

    return this.cardRepository.save(newCard);
  }

  /**
   * Tarjetas del cliente. Cada una incluye `pendingScans` (escaneos que el
   * negocio aun no aprueba) y `rewards` (premios ganados sin entregar), que la
   * app usa para mostrar "pendiente" y "premio listo".
   */
  async getUserCards(userId: string) {
    const cards = await this.cardRepository.find({
      where: { userId },
      relations: ['business', 'business.categoryRef'],
      order: { updatedAt: 'DESC' },
    });
    if (cards.length === 0) return [];

    const [pendingByBusiness, pendingRewards] = await Promise.all([
      this.scanRepository
        .createQueryBuilder('scan')
        .select('scan.businessId', 'businessId')
        .addSelect('COUNT(*)', 'count')
        .where('scan.userId = :userId', { userId })
        .andWhere('scan.status = :status', { status: ScanStatus.PENDING })
        .groupBy('scan.businessId')
        .getRawMany<{ businessId: string; count: string }>(),
      this.rewardRepository.find({
        where: { userId, status: RewardStatus.PENDING },
        select: ['id', 'loyaltyCardId', 'status'],
      }),
    ]);

    const pendingScans = new Map(pendingByBusiness.map((p) => [p.businessId, Number(p.count)]));

    return cards.map((card) => ({
      ...card,
      pendingScans: pendingScans.get(card.businessId) ?? 0,
      rewards: pendingRewards
        .filter((r) => r.loyaltyCardId === card.id)
        .map((r) => ({ id: r.id, status: r.status })),
    }));
  }

  async getBusinessCards(businessId: string, ownerId: string, role: UserRole) {
    const business = await this.businessRepository.findOne({ where: { id: businessId } });
    if (!business) {
      throw new NotFoundException('Negocio no encontrado');
    }

    if (business.ownerId !== ownerId && role !== UserRole.ADMIN) {
      throw new ForbiddenException('No tienes permiso para ver los clientes de este negocio');
    }

    return this.cardRepository.find({
      where: { businessId },
      relations: ['user'],
      order: { updatedAt: 'DESC' },
    });
  }

  async getCardHistory(cardId: string, userId: string, role: UserRole) {
    const card = await this.cardRepository.findOne({
      where: { id: cardId },
      relations: ['business', 'user'],
    });

    if (!card) {
      throw new NotFoundException('Tarjeta de fidelizacion no encontrada');
    }

    if (card.userId !== userId && card.business.ownerId !== userId && role !== UserRole.ADMIN) {
      throw new ForbiddenException('No tienes permiso para ver el historial de esta tarjeta');
    }

    const [scans, rewards, transfers] = await Promise.all([
      this.scanRepository.find({
        where: { loyaltyCardId: cardId },
        order: { scannedAt: 'DESC' },
        take: 50,
      }),
      this.rewardRepository.find({
        where: { loyaltyCardId: cardId },
        order: { earnedAt: 'DESC' },
        take: 50,
      }),
      this.transferRepository.find({
        where: { businessId: card.businessId },
        relations: ['fromUser', 'toUser', 'reward'],
        order: { transferredAt: 'DESC' },
        take: 50,
      }),
    ]);

    return {
      card,
      scans,
      rewards,
      transfers,
    };
  }
}
