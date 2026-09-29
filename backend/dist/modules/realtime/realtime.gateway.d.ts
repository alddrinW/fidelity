import { OnGatewayConnection, OnGatewayDisconnect } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
export declare class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
    private readonly jwtService;
    server: Server;
    private readonly logger;
    constructor(jwtService: JwtService);
    handleConnection(client: Socket): Promise<void>;
    handleDisconnect(client: Socket): void;
    handleJoinBusiness(client: Socket, businessId: string): {
        event: string;
        data: {
            businessId: string;
        };
    };
    handleLeaveBusiness(client: Socket, businessId: string): {
        event: string;
        data: {
            businessId: string;
        };
    };
    emitToUser(userId: string, event: string, data: any): void;
    emitToBusiness(businessId: string, event: string, data: any): void;
    emitBroadcast(event: string, data: any): void;
}
