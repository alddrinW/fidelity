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
var RealtimeGateway_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.RealtimeGateway = void 0;
const websockets_1 = require("@nestjs/websockets");
const socket_io_1 = require("socket.io");
const common_1 = require("@nestjs/common");
const jwt_1 = require("@nestjs/jwt");
let RealtimeGateway = RealtimeGateway_1 = class RealtimeGateway {
    constructor(jwtService) {
        this.jwtService = jwtService;
        this.logger = new common_1.Logger(RealtimeGateway_1.name);
    }
    async handleConnection(client) {
        try {
            const authHeader = client.handshake.headers.authorization || client.handshake.auth?.token;
            if (authHeader) {
                const token = authHeader.replace('Bearer ', '');
                const payload = this.jwtService.decode(token);
                if (payload && payload.sub) {
                    client.data.userId = payload.sub;
                    client.data.role = payload.role;
                    client.join(`user:${payload.sub}`);
                    this.logger.debug(`Client connected and joined room user:${payload.sub}`);
                }
            }
        }
        catch (error) {
            this.logger.warn(`Error during WebSocket connection handshake: ${error.message}`);
        }
    }
    handleDisconnect(client) {
        this.logger.debug(`Client disconnected: ${client.id}`);
    }
    handleJoinBusiness(client, businessId) {
        if (businessId) {
            client.join(`business:${businessId}`);
            this.logger.debug(`Socket ${client.id} joined business room: business:${businessId}`);
            return { event: 'joined_business', data: { businessId } };
        }
    }
    handleLeaveBusiness(client, businessId) {
        if (businessId) {
            client.leave(`business:${businessId}`);
            this.logger.debug(`Socket ${client.id} left business room: business:${businessId}`);
            return { event: 'left_business', data: { businessId } };
        }
    }
    emitToUser(userId, event, data) {
        if (this.server) {
            this.server.to(`user:${userId}`).emit(event, data);
        }
    }
    emitToBusiness(businessId, event, data) {
        if (this.server) {
            this.server.to(`business:${businessId}`).emit(event, data);
        }
    }
    emitBroadcast(event, data) {
        if (this.server) {
            this.server.emit(event, data);
        }
    }
};
exports.RealtimeGateway = RealtimeGateway;
__decorate([
    (0, websockets_1.WebSocketServer)(),
    __metadata("design:type", socket_io_1.Server)
], RealtimeGateway.prototype, "server", void 0);
__decorate([
    (0, websockets_1.SubscribeMessage)('join_business'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, String]),
    __metadata("design:returntype", void 0)
], RealtimeGateway.prototype, "handleJoinBusiness", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('leave_business'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, String]),
    __metadata("design:returntype", void 0)
], RealtimeGateway.prototype, "handleLeaveBusiness", null);
exports.RealtimeGateway = RealtimeGateway = RealtimeGateway_1 = __decorate([
    (0, websockets_1.WebSocketGateway)({
        cors: {
            origin: '*',
        },
    }),
    __metadata("design:paramtypes", [jwt_1.JwtService])
], RealtimeGateway);
//# sourceMappingURL=realtime.gateway.js.map