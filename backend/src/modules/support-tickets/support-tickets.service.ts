import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { SupportTicket } from '../../database/entities/support-ticket.entity';
import { CreateSupportTicketDto, UpdateTicketStatusDto } from './dto/support-tickets.dto';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class SupportTicketsService {
  private readonly logger = new Logger(SupportTicketsService.name);

  constructor(
    @InjectRepository(SupportTicket)
    private readonly ticketRepository: Repository<SupportTicket>,
    private readonly notificationsService: NotificationsService,
  ) {}

  async createTicket(userId: string, dto: CreateSupportTicketDto) {
    const ticket = this.ticketRepository.create({
      userId,
      businessId: dto.businessId || null,
      subject: dto.subject.trim(),
      message: dto.message.trim(),
      status: 'open',
    });

    const saved = await this.ticketRepository.save(ticket);

    // Notify admins of new support ticket
    await this.notificationsService.broadcastToAdmins(
      'Nuevo Ticket de Soporte',
      `Ticket: ${saved.subject}`,
      '/admin_support',
    );

    return saved;
  }

  async getUserTickets(userId: string) {
    return this.ticketRepository.find({
      where: { userId },
      relations: ['business'],
      order: { createdAt: 'DESC' },
    });
  }

  async getAllTickets() {
    return this.ticketRepository.find({
      relations: ['user', 'business'],
      order: { createdAt: 'DESC' },
    });
  }

  async updateStatus(ticketId: string, dto: UpdateTicketStatusDto) {
    const ticket = await this.ticketRepository.findOne({ where: { id: ticketId } });
    if (!ticket) throw new NotFoundException('Ticket no encontrado');

    ticket.status = dto.status;
    return this.ticketRepository.save(ticket);
  }
}
