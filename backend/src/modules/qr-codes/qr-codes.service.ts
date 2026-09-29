import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { v4 as uuidv4 } from 'uuid';
import { QrCode } from '../../database/entities/qr-code.entity';
import { Business } from '../../database/entities/business.entity';
import { Scan } from '../../database/entities/scan.entity';
import { CreateQrCodeDto, ToggleQrCodeDto } from './dto/qr-codes.dto';
import { UserRole } from '../../database/entities/profile.entity';

@Injectable()
export class QrCodesService {
  private readonly logger = new Logger(QrCodesService.name);

  constructor(
    @InjectRepository(QrCode)
    private readonly qrRepository: Repository<QrCode>,
    @InjectRepository(Business)
    private readonly businessRepository: Repository<Business>,
    @InjectRepository(Scan)
    private readonly scanRepository: Repository<Scan>,
  ) {}

  async createQrCode(callerId: string, callerRole: UserRole, dto: CreateQrCodeDto) {
    const business = await this.businessRepository.findOne({ where: { id: dto.businessId } });
    if (!business) throw new NotFoundException('Negocio no encontrado');

    if (business.ownerId !== callerId && callerRole !== UserRole.ADMIN) {
      throw new ForbiddenException('Solo el dueno del negocio puede generar codigos QR');
    }

    const qrToken = dto.qrCode || `FID-${dto.businessId.substring(0, 8)}-${uuidv4().substring(0, 8)}`.toUpperCase();

    const qr = this.qrRepository.create({
      businessId: dto.businessId,
      qrCode: qrToken,
      label: dto.label || 'Mostrador Principal',
      isActive: true,
    });

    return this.qrRepository.save(qr);
  }

  async getBusinessQrCodes(businessId: string, callerId: string, callerRole: UserRole) {
    const business = await this.businessRepository.findOne({ where: { id: businessId } });
    if (!business) throw new NotFoundException('Negocio no encontrado');

    if (business.ownerId !== callerId && callerRole !== UserRole.ADMIN) {
      throw new ForbiddenException('No autorizado para ver los codigos QR de este negocio');
    }

    return this.qrRepository.find({
      where: { businessId },
      order: { createdAt: 'DESC' },
    });
  }

  async toggleQrCode(qrId: string, callerId: string, callerRole: UserRole, dto: ToggleQrCodeDto) {
    const qr = await this.qrRepository.findOne({
      where: { id: qrId },
      relations: ['business'],
    });

    if (!qr) throw new NotFoundException('Codigo QR no encontrado');

    if (qr.business.ownerId !== callerId && callerRole !== UserRole.ADMIN) {
      throw new ForbiddenException('No autorizado para modificar este codigo QR');
    }

    qr.isActive = dto.isActive;
    return this.qrRepository.save(qr);
  }

  async updateQrCode(qrId: string, callerId: string, callerRole: UserRole, dto: { qrCode?: string; label?: string; isActive?: boolean }) {
    const qr = await this.qrRepository.findOne({
      where: { id: qrId },
      relations: ['business'],
    });

    if (!qr) throw new NotFoundException('Codigo QR no encontrado');

    if (qr.business.ownerId !== callerId && callerRole !== UserRole.ADMIN) {
      throw new ForbiddenException('No autorizado para modificar este codigo QR');
    }

    if (dto.qrCode !== undefined) qr.qrCode = dto.qrCode;
    if (dto.label !== undefined) qr.label = dto.label;
    if (dto.isActive !== undefined) qr.isActive = dto.isActive;

    return this.qrRepository.save(qr);
  }

  async getQrStats(qrId: string, callerId: string, callerRole: UserRole) {
    const qr = await this.qrRepository.findOne({
      where: { id: qrId },
      relations: ['business'],
    });

    if (!qr) throw new NotFoundException('Codigo QR no encontrado');

    if (qr.business.ownerId !== callerId && callerRole !== UserRole.ADMIN) {
      throw new ForbiddenException('No autorizado para ver metricas');
    }

    const totalScans = await this.scanRepository.count({ where: { qrCodeId: qrId } });

    return {
      qrId: qr.id,
      qrCode: qr.qrCode,
      label: qr.label,
      isActive: qr.isActive,
      totalScans,
    };
  }
}
