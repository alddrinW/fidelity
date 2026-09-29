import { Repository } from 'typeorm';
import { SupportTicket } from '../../database/entities/support-ticket.entity';
import { CreateSupportTicketDto, UpdateTicketStatusDto } from './dto/support-tickets.dto';
import { NotificationsService } from '../notifications/notifications.service';
export declare class SupportTicketsService {
    private readonly ticketRepository;
    private readonly notificationsService;
    private readonly logger;
    constructor(ticketRepository: Repository<SupportTicket>, notificationsService: NotificationsService);
    createTicket(userId: string, dto: CreateSupportTicketDto): Promise<SupportTicket>;
    getUserTickets(userId: string): Promise<SupportTicket[]>;
    getAllTickets(): Promise<SupportTicket[]>;
    updateStatus(ticketId: string, dto: UpdateTicketStatusDto): Promise<SupportTicket>;
}
