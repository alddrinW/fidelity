"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var SupportTicketsService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.SupportTicketsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const support_ticket_entity_1 = require("../../database/entities/support-ticket.entity");
const notifications_service_1 = require("../notifications/notifications.service");
let SupportTicketsService = SupportTicketsService_1 = class SupportTicketsService {
    constructor(ticketRepository, notificationsService) {
        this.ticketRepository = ticketRepository;
        this.notificationsService = notificationsService;
        this.logger = new common_1.Logger(SupportTicketsService_1.name);
    }
    async createTicket(userId, dto) {
        const ticket = this.ticketRepository.create({
            userId,
            businessId: dto.businessId || null,
            subject: dto.subject.trim(),
            message: dto.message.trim(),
            status: 'open',
        });
        const saved = await this.ticketRepository.save(ticket);
        await this.notificationsService.broadcastToAdmins('Nuevo Ticket de Soporte', `Ticket: ${saved.subject}`, '/admin_support');
        return saved;
    }
    async getUserTickets(userId) {
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
    async updateStatus(ticketId, dto) {
        const ticket = await this.ticketRepository.findOne({ where: { id: ticketId } });
        if (!ticket)
            throw new common_1.NotFoundException('Ticket no encontrado');
        ticket.status = dto.status;
        return this.ticketRepository.save(ticket);
    }
};
exports.SupportTicketsService = SupportTicketsService;
exports.SupportTicketsService = SupportTicketsService = SupportTicketsService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(support_ticket_entity_1.SupportTicket)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        notifications_service_1.NotificationsService])
], SupportTicketsService);
//# sourceMappingURL=support-tickets.service.js.map