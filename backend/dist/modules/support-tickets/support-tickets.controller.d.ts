import { SupportTicketsService } from './support-tickets.service';
import { CreateSupportTicketDto, UpdateTicketStatusDto } from './dto/support-tickets.dto';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
export declare class SupportTicketsController {
    private readonly supportService;
    constructor(supportService: SupportTicketsService);
    createTicket(user: AuthenticatedUser, dto: CreateSupportTicketDto): Promise<import("../../database/entities").SupportTicket>;
    getMyTickets(user: AuthenticatedUser): Promise<import("../../database/entities").SupportTicket[]>;
    getAllTickets(): Promise<import("../../database/entities").SupportTicket[]>;
    updateStatus(id: string, dto: UpdateTicketStatusDto): Promise<import("../../database/entities").SupportTicket>;
}
