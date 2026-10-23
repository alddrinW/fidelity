import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import type { Transporter } from 'nodemailer';
import { MailContent } from './mail-templates';

/**
 * Envío de correos. Con SMTP configurado (`SMTP_HOST`...) envía de verdad; sin
 * él, fuera de producción escribe el mensaje en el log para poder probar el
 * flujo, y en producción avisa del error (nunca se pierde en silencio).
 *
 * La conexión siempre es cifrada: puerto 465 con TLS directo y los demás con
 * STARTTLS obligatorio (así la clave del correo nunca viaja en claro). Hay
 * límites de espera para que un servidor de correo caído no deje colgada a la
 * persona que pide recuperar su contraseña.
 */
@Injectable()
export class MailService implements OnModuleInit {
  private readonly logger = new Logger(MailService.name);
  private transport: Transporter | null = null;

  constructor(private readonly configService: ConfigService) {}

  /** Al arrancar dice, sin mostrar claves, si los correos van a salir. */
  onModuleInit() {
    if (this.isConfigured()) {
      const host = this.configService.get<string>('mail.host');
      const port = this.configService.get<number>('mail.port') ?? 587;
      this.logger.log(`Correo: SMTP configurado (${host}:${port}). Usa "npm run mail:test" para probarlo.`);
    } else if (this.configService.get<string>('nodeEnv') === 'production') {
      this.logger.error(
        'Correo: SMTP SIN CONFIGURAR en producción. Nadie podrá recuperar su contraseña. Define SMTP_HOST, SMTP_USER y SMTP_PASS.',
      );
    } else {
      this.logger.warn('Correo: SMTP sin configurar. Los correos se escriben en este log (solo en desarrollo).');
    }
  }

  isConfigured(): boolean {
    return !!this.configService.get<string>('mail.host');
  }

  /** La conexión al servidor de correo (se crea una vez y se reutiliza). */
  private getTransport(): Transporter {
    if (this.transport) return this.transport;

    const port = this.configService.get<number>('mail.port') ?? 587;
    const secure = this.configService.get<boolean>('mail.secure') ?? port === 465;
    const user = this.configService.get<string>('mail.user');
    this.transport = nodemailer.createTransport({
      host: this.configService.get<string>('mail.host'),
      port,
      secure,
      // Sin TLS directo, el cifrado (STARTTLS) es obligatorio salvo que se pida lo contrario.
      requireTLS: !secure && (this.configService.get<boolean>('mail.requireTls') ?? true),
      auth: user ? { user, pass: this.configService.get<string>('mail.pass') } : undefined,
      connectionTimeout: 10_000,
      greetingTimeout: 10_000,
      socketTimeout: 20_000,
    });
    return this.transport;
  }

  /** Comprueba la conexión y las claves con el servidor de correo (sin enviar nada). */
  async verify(): Promise<{ ok: boolean; error?: string }> {
    if (!this.isConfigured()) return { ok: false, error: 'SMTP_HOST no está definido' };
    try {
      await this.getTransport().verify();
      return { ok: true };
    } catch (error) {
      return { ok: false, error: this.explain(error) };
    }
  }

  /** Un correo ya armado con sus plantillas. */
  sendContent(to: string, content: MailContent): Promise<boolean> {
    return this.send(to, content.subject, content.text, content.html);
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

    try {
      await this.getTransport().sendMail({
        from: this.configService.get<string>('mail.from'),
        to,
        subject,
        text,
        html,
      });
      return true;
    } catch (error) {
      this.logger.error(`No se pudo enviar el correo a ${to}: ${this.explain(error)}`);
      return false;
    }
  }

  /** Traduce los errores típicos del correo a algo que se pueda arreglar. */
  explain(error: any): string {
    const code = error?.code as string | undefined;
    const response = String(error?.response ?? error?.message ?? error);
    if (code === 'EAUTH' || /535|authentication|credentials/i.test(response)) {
      return 'Usuario o contraseña del correo rechazados. En Gmail hace falta una "contraseña de aplicación", no la clave normal.';
    }
    if (code === 'ECONNECTION' || code === 'ESOCKET' || code === 'ETIMEDOUT' || code === 'ECONNREFUSED' || code === 'EDNS') {
      return `No se pudo conectar al servidor de correo (${code}). Revisa SMTP_HOST y SMTP_PORT, y que no haya un firewall.`;
    }
    if (code === 'EENVELOPE') return 'El destinatario o el remitente no son válidos.';
    return response.slice(0, 200);
  }
}
