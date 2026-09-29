import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

@WebSocketGateway({
  cors: {
    origin: '*',
  },
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(private readonly jwtService: JwtService) {}

  async handleConnection(client: Socket) {
    try {
      const authHeader = client.handshake.headers.authorization || client.handshake.auth?.token;
      if (authHeader) {
        const token = authHeader.replace('Bearer ', '');
        const payload = this.jwtService.decode(token) as any;
        if (payload && payload.sub) {
          client.data.userId = payload.sub;
          client.data.role = payload.role;
          // Join user-specific room
          client.join(`user:${payload.sub}`);
          this.logger.debug(`Client connected and joined room user:${payload.sub}`);
        }
      }
    } catch (error) {
      this.logger.warn(`Error during WebSocket connection handshake: ${error.message}`);
    }
  }

  handleDisconnect(client: Socket) {
    this.logger.debug(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('join_business')
  handleJoinBusiness(client: Socket, businessId: string) {
    if (businessId) {
      client.join(`business:${businessId}`);
      this.logger.debug(`Socket ${client.id} joined business room: business:${businessId}`);
      return { event: 'joined_business', data: { businessId } };
    }
  }

  @SubscribeMessage('leave_business')
  handleLeaveBusiness(client: Socket, businessId: string) {
    if (businessId) {
      client.leave(`business:${businessId}`);
      this.logger.debug(`Socket ${client.id} left business room: business:${businessId}`);
      return { event: 'left_business', data: { businessId } };
    }
  }

  emitToUser(userId: string, event: string, data: any) {
    if (this.server) {
      this.server.to(`user:${userId}`).emit(event, data);
    }
  }

  emitToBusiness(businessId: string, event: string, data: any) {
    if (this.server) {
      this.server.to(`business:${businessId}`).emit(event, data);
    }
  }

  emitBroadcast(event: string, data: any) {
    if (this.server) {
      this.server.emit(event, data);
    }
  }
}
