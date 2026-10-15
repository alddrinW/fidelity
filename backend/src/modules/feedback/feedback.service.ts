import {
  BadRequestException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { MoreThan, Repository } from 'typeorm';
import {
  Feedback,
  FeedbackKind,
  FeedbackStatus,
} from '../../database/entities/feedback.entity';
import { Business } from '../../database/entities/business.entity';
import { Scan } from '../../database/entities/scan.entity';
import { UserRole } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { BusinessAccessService } from '../businesses/business-access.service';
import { CreateFeedbackDto, FeedbackFilterDto } from './dto/feedback.dto';

/** Máximo de opiniones por cliente y local cada 24 horas (evita el spam). */
export const MAX_FEEDBACK_PER_DAY = 3;

/** Largo mínimo del texto de una sugerencia o un reclamo. */
export const MIN_MESSAGE_LENGTH = 5;

@Injectable()
export class FeedbackService {
  private readonly logger = new Logger(FeedbackService.name);

  constructor(
    @InjectRepository(Feedback)
    private readonly feedbackRepository: Repository<Feedback>,
    @InjectRepository(Scan)
    private readonly scanRepository: Repository<Scan>,
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    private readonly notificationsService: NotificationsService,
    private readonly businessAccess: BusinessAccessService,
  ) {}

  /** Calificación baja = reclamo; con texto = sugerencia; solo estrellas = elogio. */
  static inferKind(rating?: number, message?: string | null): FeedbackKind {
    if (rating === 1) return FeedbackKind.COMPLAINT;
    return message ? FeedbackKind.SUGGESTION : FeedbackKind.PRAISE;
  }

  async create(userId: string, dto: CreateFeedbackDto) {
    // Solo se opina de un local donde ya se escaneó al menos una vez.
    const scans = await this.scanRepository.count({
      where: { userId, businessId: dto.businessId },
    });
    if (scans === 0) {
      throw new ForbiddenException('Solo puedes opinar de un local donde ya escaneaste');
    }

    const business = await this.businessRepository.findOne({
      where: { id: dto.businessId },
      select: ['id', 'name'],
    });
    if (!business) throw new NotFoundException('Negocio no encontrado');

    const message = dto.message?.trim() || null;
    const tags = [...new Set((dto.tags ?? []).map((t) => t.trim()).filter(Boolean))];
    const kind = dto.kind ?? FeedbackService.inferKind(dto.rating, message);

    if (dto.rating == null && !message) {
      throw new BadRequestException('Cuéntanos algo: elige una calificación o escribe un comentario');
    }
    if (kind !== FeedbackKind.PRAISE && (message?.length ?? 0) < MIN_MESSAGE_LENGTH) {
      throw new BadRequestException(
        `Cuéntanos un poco más (al menos ${MIN_MESSAGE_LENGTH} caracteres)`,
      );
    }

    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recent = await this.feedbackRepository.count({
      where: { userId, businessId: dto.businessId, createdAt: MoreThan(since) },
    });
    if (recent >= MAX_FEEDBACK_PER_DAY) {
      throw new HttpException(
        'Ya enviaste varias opiniones de este local hoy. Inténtalo mañana.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const saved = await this.feedbackRepository.save(
      this.feedbackRepository.create({
        userId,
        businessId: dto.businessId,
        kind,
        rating: dto.rating ?? null,
        tags,
        message,
        status: kind === FeedbackKind.PRAISE ? FeedbackStatus.RESOLVED : FeedbackStatus.OPEN,
      }),
    );

    // Los elogios no necesitan seguimiento: solo se avisa al dueño.
    await this.notifyNewFeedback(saved, business.name);
    return saved;
  }

  private async notifyNewFeedback(feedback: Feedback, businessName: string) {
    const label = {
      [FeedbackKind.COMPLAINT]: 'reclamo',
      [FeedbackKind.SUGGESTION]: 'sugerencia',
      [FeedbackKind.PRAISE]: 'felicitación',
    }[feedback.kind];

    await this.safely(async () => {
      await this.notificationsService.sendToBusinessStaff(
        feedback.businessId,
        `Nueva ${label} de un cliente`,
        `${businessName}: ${feedback.message ?? 'Un cliente calificó tu atención.'}`.slice(0, 140),
        { type: 'feedback' },
      );
      if (feedback.kind !== FeedbackKind.PRAISE) {
        await this.notificationsService.broadcastToAdmins(
          `Nuevo ${label}`,
          `${businessName}: ${feedback.message ?? ''}`.slice(0, 140),
          '/admin_feedback',
        );
      }
    });
  }

  /** Opiniones enviadas por el propio cliente, con la respuesta si ya la hay. */
  async listMine(userId: string) {
    return this.feedbackRepository.find({
      where: { userId },
      relations: ['business'],
      order: { createdAt: 'DESC' },
      take: 100,
    });
  }

  /** Todas las opiniones (administrador). */
  async listAll(filter: FeedbackFilterDto = {}) {
    return this.feedbackRepository.find({
      where: { ...(filter.status && { status: filter.status }), ...(filter.kind && { kind: filter.kind }) },
      relations: ['business', 'user'],
      order: { createdAt: 'DESC' },
      take: 200,
    });
  }

  /** Opiniones de un negocio: el dueño o el administrador. */
  async listForBusiness(
    businessId: string,
    requester: { id: string; role: UserRole },
    filter: FeedbackFilterDto = {},
  ) {
    await this.assertCanManage(requester, businessId);
    return this.feedbackRepository.find({
      where: {
        businessId,
        ...(filter.status && { status: filter.status }),
        ...(filter.kind && { kind: filter.kind }),
      },
      relations: ['user'],
      order: { createdAt: 'DESC' },
      take: 200,
    });
  }

  /** Cuántas sugerencias y reclamos siguen abiertos. */
  async countOpen(): Promise<number> {
    return this.feedbackRepository.count({ where: { status: FeedbackStatus.OPEN } });
  }

  /** Marca la opinión como resuelta y, si hay respuesta, se la avisa al cliente. */
  async resolve(
    feedbackId: string,
    requester: { id: string; role: UserRole },
    reply?: string,
  ) {
    const feedback = await this.feedbackRepository.findOne({
      where: { id: feedbackId },
      relations: ['business'],
    });
    if (!feedback) throw new NotFoundException('Opinión no encontrada');
    await this.assertCanManage(requester, feedback.businessId);

    feedback.status = FeedbackStatus.RESOLVED;
    feedback.reply = reply?.trim() || feedback.reply;
    feedback.resolvedById = requester.id;
    feedback.resolvedAt = new Date();
    const saved = await this.feedbackRepository.save(feedback);

    if (saved.reply) {
      await this.safely(() =>
        this.notificationsService.sendToUser(
          saved.userId,
          `${feedback.business?.name ?? 'Un local'} respondió tu opinión`,
          saved.reply!.slice(0, 140),
          { type: 'feedback_reply' },
        ),
      );
    }
    return saved;
  }

  private async assertCanManage(requester: { id: string; role: UserRole }, businessId: string) {
    const allowed = await this.businessAccess.canOperate(requester.id, requester.role, businessId);
    if (!allowed) {
      throw new ForbiddenException('No tienes permiso para ver las opiniones de este negocio');
    }
  }

  /** Una notificación fallida nunca debe deshacer el guardado de la opinión. */
  private async safely(task: () => Promise<unknown>) {
    try {
      await task();
    } catch (error) {
      this.logger.warn(`Notificación de opinión no enviada: ${error.message}`);
    }
  }
}
