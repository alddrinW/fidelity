import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Business } from '../../database/entities/business.entity';
import { Scan, ScanStatus } from '../../database/entities/scan.entity';
import { Profile } from '../../database/entities/profile.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { SETTING_KEYS } from '../settings/settings.definitions';
import { SettingsService } from '../settings/settings.service';

/** La insignia de fidelidad de un cliente en un local. */
export interface FidelyStatus {
  /** Escaneos reales (de un QR) aprobados por el local. */
  verifiedScans: number;
  /** Escaneos que se necesitan para ser FidelyUsuario (lo fija el administrador). */
  fidelyRequired: number;
  isFidely: boolean;
}

/**
 * FidelyUsuario: el cliente que ya escaneó (y el local le aprobó) al menos 3
 * veces en un mismo local —la cantidad la fija el administrador— recibe la
 * insignia de ese local, por su fidelidad. Se calcula con los escaneos
 * aprobados, así que nunca se pierde. Los puntos regalados a mano no cuentan:
 * solo los escaneos reales de un QR.
 */
@Injectable()
export class FidelyService {
  private readonly logger = new Logger(FidelyService.name);

  constructor(
    @InjectRepository(Scan)
    private readonly scanRepository: Repository<Scan>,
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(Profile)
    private readonly profileRepository: Repository<Profile>,
    private readonly notificationsService: NotificationsService,
    private readonly settings: SettingsService,
  ) {}

  required(): Promise<number> {
    return this.settings.get(SETTING_KEYS.fidelyScansRequired);
  }

  private realScans() {
    return this.scanRepository
      .createQueryBuilder('scan')
      .where('scan.status = :status', { status: ScanStatus.APPROVED })
      .andWhere('scan.qrCodeId IS NOT NULL');
  }

  /** Escaneos aprobados del cliente en cada local: `businessId → cantidad`. */
  async countsForUser(userId: string): Promise<Map<string, number>> {
    const rows = await this.realScans()
      .select('scan.businessId', 'key')
      .addSelect('COUNT(*)', 'count')
      .andWhere('scan.userId = :userId', { userId })
      .groupBy('scan.businessId')
      .getRawMany<{ key: string; count: string }>();
    return new Map(rows.map((r) => [r.key, Number(r.count)]));
  }

  /** Escaneos aprobados de cada cliente en el local: `userId → cantidad`. */
  async countsForBusiness(businessId: string): Promise<Map<string, number>> {
    const rows = await this.realScans()
      .select('scan.userId', 'key')
      .addSelect('COUNT(*)', 'count')
      .andWhere('scan.businessId = :businessId', { businessId })
      .groupBy('scan.userId')
      .getRawMany<{ key: string; count: string }>();
    return new Map(rows.map((r) => [r.key, Number(r.count)]));
  }

  /** Arma el estado a partir de una cantidad de escaneos. */
  status(verifiedScans: number | undefined, fidelyRequired: number): FidelyStatus {
    const scans = verifiedScans ?? 0;
    return { verifiedScans: scans, fidelyRequired, isFidely: scans >= fidelyRequired };
  }

  async statusFor(userId: string, businessId: string): Promise<FidelyStatus> {
    const [counts, required] = await Promise.all([this.countsForUser(userId), this.required()]);
    return this.status(counts.get(businessId), required);
  }

  /**
   * Se llama cuando el local aprueba un escaneo. Si con ese escaneo el cliente
   * llegó justo a la cantidad necesaria, se le avisa que ya es FidelyUsuario y
   * se avisa también al dueño. Solo ocurre una vez por cliente y local.
   * Devuelve true si acaba de ganar la insignia.
   */
  async onScanApproved(userId: string, businessId: string, loyaltyCardId?: string): Promise<boolean> {
    const status = await this.statusFor(userId, businessId);
    if (status.verifiedScans !== status.fidelyRequired) return false;

    const [business, user] = await Promise.all([
      this.businessRepository.findOne({ where: { id: businessId }, select: ['id', 'name'] }),
      this.profileRepository.findOne({ where: { id: userId }, select: ['id', 'fullName', 'email'] }),
    ]);
    if (!business) return false;
    const person = user?.fullName?.trim() || user?.email?.split('@')[0] || 'Un cliente';

    await this.notificationsService.sendToUser(
      userId,
      `¡Ya eres FidelyUsuario de ${business.name}!`,
      `Por tu fidelidad a ${business.name} tienes la insignia FidelyUsuario. ¡Gracias por volver!`,
      {
        type: 'fidely',
        route: '/fidely_user',
        business_id: business.id,
        business_name: business.name,
        ...(loyaltyCardId ? { loyalty_card_id: loyaltyCardId } : {}),
      },
    );
    await this.notificationsService.sendToBusinessOwner(
      business.id,
      'Nuevo FidelyUsuario',
      `${person} ya es FidelyUsuario de ${business.name}: ${status.fidelyRequired} escaneos aprobados.`,
      { type: 'fidely', route: '/business_dashboard/customers', business_id: business.id },
    );
    this.logger.log(`FidelyUsuario: ${userId} en ${business.id}`);
    return true;
  }
}
