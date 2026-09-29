import { OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Repository } from 'typeorm';
import { Profile } from '../../database/entities/profile.entity';
import { Business } from '../../database/entities/business.entity';
export declare class NotificationsService implements OnModuleInit {
    private readonly configService;
    private readonly profileRepository;
    private readonly businessRepository;
    private readonly logger;
    private firebaseApp;
    constructor(configService: ConfigService, profileRepository: Repository<Profile>, businessRepository: Repository<Business>);
    onModuleInit(): void;
    private initializeFirebase;
    sendPushNotification(token: string, title: string, body: string, dataPayload?: Record<string, string>): Promise<boolean>;
    sendToUser(userId: string, title: string, body: string, dataPayload?: Record<string, string>): Promise<boolean>;
    sendToBusinessOwner(businessId: string, title: string, body: string, dataPayload?: Record<string, string>): Promise<boolean>;
    broadcastToAdmins(title: string, body: string, route?: string): Promise<void>;
}
