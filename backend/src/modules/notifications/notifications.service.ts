import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import * as admin from 'firebase-admin';
import * as fs from 'fs';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { Business } from '../../database/entities/business.entity';
import { BusinessMember } from '../../database/entities/business-member.entity';

@Injectable()
export class NotificationsService implements OnModuleInit {
  private readonly logger = new Logger(NotificationsService.name);
  private firebaseApp: admin.app.App | null = null;

  constructor(
    private readonly configService: ConfigService,
    @InjectRepository(Profile)
    private readonly profileRepository: Repository<Profile>,
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(BusinessMember)
    private readonly memberRepository: Repository<BusinessMember>,
  ) {}

  onModuleInit() {
    this.initializeFirebase();
  }

  private initializeFirebase() {
    try {
      const serviceAccountStr = this.configService.get<string>('firebase.serviceAccount');
      const credentialsPath = this.configService.get<string>('firebase.credentialsPath');

      let credential: admin.credential.Credential | null = null;

      if (serviceAccountStr && serviceAccountStr.trim().length > 0) {
        const parsed = JSON.parse(serviceAccountStr);
        credential = admin.credential.cert(parsed);
      } else if (credentialsPath && fs.existsSync(credentialsPath)) {
        const content = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
        credential = admin.credential.cert(content);
      }

      if (credential) {
        if (!admin.apps.length) {
          this.firebaseApp = admin.initializeApp({ credential });
        } else {
          this.firebaseApp = admin.app();
        }
        this.logger.log('Firebase Admin SDK initialized successfully');
      } else {
        this.logger.warn('Firebase credentials not provided. Push notifications will run in mock mode');
      }
    } catch (error) {
      this.logger.error(`Error initializing Firebase Admin SDK: ${error.message}`);
    }
  }

  async sendPushNotification(
    token: string,
    title: string,
    body: string,
    dataPayload: Record<string, string> = {},
  ): Promise<boolean> {
    if (!token) return false;

    if (!this.firebaseApp) {
      this.logger.debug(`[Mock FCM Notification] To: ${token.substring(0, 15)}... | Title: ${title} | Body: ${body}`);
      return true;
    }

    try {
      await admin.messaging().send({
        token,
        notification: {
          title,
          body,
        },
        data: dataPayload,
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'high_importance_channel',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      });
      return true;
    } catch (error) {
      this.logger.error(`Failed to send push notification: ${error.message}`);
      return false;
    }
  }

  async sendToUser(
    userId: string,
    title: string,
    body: string,
    dataPayload: Record<string, string> = {},
  ): Promise<boolean> {
    const user = await this.profileRepository.findOne({ where: { id: userId } });
    if (!user || !user.fcmToken) return false;
    return this.sendPushNotification(user.fcmToken, title, body, dataPayload);
  }

  async sendToBusinessOwner(
    businessId: string,
    title: string,
    body: string,
    dataPayload: Record<string, string> = {},
  ): Promise<boolean> {
    const business = await this.businessRepository.findOne({
      where: { id: businessId },
      relations: ['owner'],
    });
    if (!business || !business.owner || !business.owner.fcmToken) return false;
    return this.sendPushNotification(business.owner.fcmToken, title, body, dataPayload);
  }

  /**
   * Avisa al dueño del negocio y a sus aprobadores (quienes atienden escaneos,
   * premios y opiniones). Devuelve cuántos avisos se enviaron.
   */
  async sendToBusinessStaff(
    businessId: string,
    title: string,
    body: string,
    dataPayload: Record<string, string> = {},
  ): Promise<number> {
    const business = await this.businessRepository.findOne({
      where: { id: businessId },
      relations: ['owner'],
    });
    if (!business) return 0;

    const members = await this.memberRepository.find({
      where: { businessId },
      relations: ['user'],
    });
    const tokens = new Set<string>();
    if (business.owner?.fcmToken) tokens.add(business.owner.fcmToken);
    for (const member of members) {
      if (member.user?.fcmToken) tokens.add(member.user.fcmToken);
    }

    let sent = 0;
    for (const token of tokens) {
      if (await this.sendPushNotification(token, title, body, dataPayload)) sent++;
    }
    return sent;
  }

  /**
   * Avisa a muchos usuarios a la vez (campañas). Consulta sus tokens en una
   * sola pasada y envía por tandas para no saturar. Devuelve cuántos avisos
   * se enviaron.
   */
  async sendToUsers(
    userIds: string[],
    title: string,
    body: string,
    dataPayload: Record<string, string> = {},
  ): Promise<number> {
    if (userIds.length === 0) return 0;
    const users = await this.profileRepository.find({
      where: { id: In(userIds) },
      select: ['id', 'fcmToken'],
    });
    const tokens = [...new Set(users.map((u) => u.fcmToken).filter(Boolean))];

    let sent = 0;
    const batchSize = 20;
    for (let i = 0; i < tokens.length; i += batchSize) {
      const results = await Promise.allSettled(
        tokens
          .slice(i, i + batchSize)
          .map((token) => this.sendPushNotification(token, title, body, dataPayload)),
      );
      sent += results.filter((r) => r.status === 'fulfilled' && r.value).length;
    }
    return sent;
  }

  async broadcastToAdmins(
    title: string,
    body: string,
    route: string = '/admin_dashboard',
  ): Promise<void> {
    const admins = await this.profileRepository.find({
      where: { role: UserRole.ADMIN },
    });
    const tokens = admins.map((a) => a.fcmToken).filter(Boolean);
    for (const token of tokens) {
      await this.sendPushNotification(token, title, body, { route });
    }
  }
}
