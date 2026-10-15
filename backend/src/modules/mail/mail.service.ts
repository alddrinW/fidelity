import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

/**
 * Envío de correos. Con SMTP configurado (`SMTP_HOST`...) envía de verdad; sin
 * él, fuera de producción escribe el mensaje en el log para poder probar el
 * flujo, y en producción avisa del error (nunca se pierde en silencio).
 */
@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);

  constructor(private readonly configService: ConfigService) {}

  isConfigured(): boolean {
    return !!this.configService.get<string>('mail.host');
  }

  /** Devuelve `true` si el correo salió (o, sin SMTP, si se dejó en el log de desarrollo). */
  async send(to: string, subject: string, text: string, html?: string): Promise<boolean> {
    if (!this.isConfigured()) {
      if (this.configService.get<string>('nodeEnv') === 'production') {
        this.logger.error(`SMTP sin configurar: no se pudo enviar "${subject}" a ${to}`);
        return false;
      }
      this.logger.warn(`[correo de desarrollo] a ${to} · ${subject}\n${text}`);
      return true;
    }

    const port = this.configService.get<number>('mail.port') ?? 587;
    const user = this.configService.get<string>('mail.user');
    const transport = nodemailer.createTransport({
      host: this.configService.get<string>('mail.host'),
      port,
      secure: port === 465,
      auth: user ? { user, pass: this.configService.get<string>('mail.pass') } : undefined,
    });

    try {
      await transport.sendMail({
        from: this.configService.get<string>('mail.from'),
        to,
        subject,
        text,
        html,
      });
      return true;
    } catch (error) {
      this.logger.error(`No se pudo enviar el correo a ${to}: ${error.message}`);
      return false;
    }
  }
}
