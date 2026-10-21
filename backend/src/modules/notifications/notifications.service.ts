import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, LessThan, Repository } from 'typeorm';
import * as admin from 'firebase-admin';
import * as fs from 'fs';
import { Profile, UserRole } from '../../database/entities/profile.entity';
import { Business } from '../../database/entities/business.entity';
import { BusinessMember } from '../../database/entities/business-member.entity';
import { Notification } from '../../database/entities/notification.entity';
import { translateNotification } from './notification-translator';

/** A quién se le manda un push: su token y el idioma de su app. */
interface PushTarget {
  token: string;
  language?: string | null;
}

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
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
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

  // ------------------------------------------------------------------
  // Bandeja: cada aviso queda guardado para que el usuario lo revise
  // ------------------------------------------------------------------

  /**
   * Guarda el aviso en la bandeja de cada usuario. Un fallo aquí nunca debe
   * impedir el push ni la operación que lo originó.
   */
  async record(
    userIds: string[],
    title: string,
    body: string,
    dataPayload: Record<string, string> = {},
  ): Promise<void> {
    const ids = [...new Set(userIds.filter(Boolean))];
    if (ids.length === 0) return;
    try {
      const type = (dataPayload.type ?? 'general').slice(0, 40);
      const rows = ids.map((userId) => ({
        userId,
        type,
        title: title.slice(0, 160),
        body,
        data: Object.keys(dataPayload).length > 0 ? dataPayload : null,
      }));
      const chunk = 500;
      for (let i = 0; i < rows.length; i += chunk) {
        await this.notificationRepository.insert(rows.slice(i, i + chunk));
      }
    } catch (error) {
      this.logger.warn(`No se pudo guardar la notificación en la bandeja: ${error.message}`);
    }
  }

  /** Movimientos del usuario, del más nuevo al más viejo (máximo 50 por página). */
  async listForUser(userId: string, limit = 30, before?: string) {
    const take = Math.min(Math.max(limit, 1), 50);
    const beforeDate = before ? new Date(before) : null;
    const where: Record<string, unknown> = { userId };
    if (beforeDate && !Number.isNaN(beforeDate.getTime())) where.createdAt = LessThan(beforeDate);

    const [items, owner] = await Promise.all([
      this.notificationRepository.find({
        where,
        order: { createdAt: 'DESC' },
        take,
      }),
      this.profileRepository.findOne({ where: { id: userId }, select: ['id', 'language'] }),
    ]);
    // En la bandeja queda el texto original (en español): se traduce al leerlo,
    // así si el usuario cambia de idioma sus avisos viejos también cambian.
    const language = owner?.language;
    return items.map((n) => ({
      id: n.id,
      type: n.type,
      title: translateNotification(n.title, language),
      body: translateNotification(n.body, language),
      data: n.data,
      read: !!n.readAt,
      createdAt: n.createdAt,
    }));
  }

  unreadCount(userId: string): Promise<number> {
    return this.notificationRepository.count({ where: { userId, readAt: IsNull() } });
  }

  /** Marca una como leída; devuelve cuántas cambió (0 si no era suya o ya estaba leída). */
  async markRead(userId: string, id: string): Promise<number> {
    const result = await this.notificationRepository.update(
      { id, userId, readAt: IsNull() },
      { readAt: new Date() },
    );
    return result.affected ?? 0;
  }

  async markAllRead(userId: string): Promise<number> {
    const result = await this.notificationRepository.update(
      { userId, readAt: IsNull() },
      { readAt: new Date() },
    );
    return result.affected ?? 0;
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
    if (!user) return false;
    await this.record([user.id], title, body, dataPayload);
    if (!user.fcmToken) return false;
    return this.sendPushNotification(
      user.fcmToken,
      translateNotification(title, user.language),
      translateNotification(body, user.language),
      dataPayload,
    );
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
    if (!business || !business.owner) return false;
    await this.record([business.owner.id], title, body, dataPayload);
    if (!business.owner.fcmToken) return false;
    return this.sendPushNotification(
      business.owner.fcmToken,
      translateNotification(title, business.owner.language),
      translateNotification(body, business.owner.language),
      dataPayload,
    );
  }

  /**
   * Manda el mismo aviso a varios dispositivos, cada uno en el idioma de su
   * dueño (se traduce una sola vez por idioma). Envía por tandas para no
   * saturar y devuelve cuántos salieron.
   */
  private async pushToTargets(
    targets: PushTarget[],
    title: string,
    body: string,
    dataPayload: Record<string, string>,
  ): Promise<number> {
    const unique = new Map<string, PushTarget>();
    for (const target of targets) if (target.token) unique.set(target.token, target);

    const texts = new Map<string, { title: string; body: string }>();
    const textsFor = (language?: string | null) => {
      const key = language === 'en' ? 'en' : 'es';
      if (!texts.has(key)) {
        texts.set(key, {
          title: translateNotification(title, key),
          body: translateNotification(body, key),
        });
      }
      return texts.get(key)!;
    };

    const list = [...unique.values()];
    let sent = 0;
    const batchSize = 20;
    for (let i = 0; i < list.length; i += batchSize) {
      const results = await Promise.allSettled(
        list.slice(i, i + batchSize).map((target) => {
          const text = textsFor(target.language);
          return this.sendPushNotification(target.token, text.title, text.body, dataPayload);
        }),
      );
      sent += results.filter((r) => r.status === 'fulfilled' && r.value).length;
    }
    return sent;
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
    const targets: PushTarget[] = [];
    if (business.owner?.fcmToken) {
      targets.push({ token: business.owner.fcmToken, language: business.owner.language });
    }
    for (const member of members) {
      if (member.user?.fcmToken) {
        targets.push({ token: member.user.fcmToken, language: member.user.language });
      }
    }
    await this.record(
      [business.ownerId, ...members.map((m) => m.userId)],
      title,
      body,
      dataPayload,
    );

    return this.pushToTargets(targets, title, body, dataPayload);
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
    await this.record(userIds, title, body, dataPayload);
    const users = await this.profileRepository.find({
      where: { id: In(userIds) },
      select: ['id', 'fcmToken', 'language'],
    });
    return this.pushToTargets(
      users.map((u) => ({ token: u.fcmToken, language: u.language })),
      title,
      body,
      dataPayload,
    );
  }

  async broadcastToAdmins(
    title: string,
    body: string,
    route: string = '/admin_dashboard',
  ): Promise<void> {
    const admins = await this.profileRepository.find({
      where: { role: UserRole.ADMIN },
    });
    await this.record(
      admins.map((a) => a.id),
      title,
      body,
      { type: 'admin', route },
    );
    await this.pushToTargets(
      admins.map((a) => ({ token: a.fcmToken, language: a.language })),
      title,
      body,
      { route },
    );
  }
}
