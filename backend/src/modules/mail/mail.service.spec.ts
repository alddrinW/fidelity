import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { MailService } from './mail.service';

jest.mock('nodemailer');

describe('MailService', () => {
  const build = (values: Record<string, any>) =>
    new MailService({ get: (k: string) => values[k] } as ConfigService);

  const smtp = (extra: Record<string, any> = {}) => ({
    nodeEnv: 'production',
    'mail.host': 'smtp.gmail.com',
    'mail.port': 587,
    'mail.user': 'fidelity@gmail.com',
    'mail.pass': 'claveapp',
    'mail.from': 'Fidelity <fidelity@gmail.com>',
    ...extra,
  });

  let sendMail: jest.Mock;
  let verify: jest.Mock;

  beforeEach(() => {
    sendMail = jest.fn().mockResolvedValue({});
    verify = jest.fn().mockResolvedValue(true);
    (nodemailer.createTransport as jest.Mock).mockReset().mockReturnValue({ sendMail, verify });
  });

  describe('sin SMTP', () => {
    it('fuera de producción deja el correo en el log y devuelve true', async () => {
      const service = build({ nodeEnv: 'development' });

      expect(service.isConfigured()).toBe(false);
      await expect(service.send('a@b.com', 'Asunto', 'Cuerpo')).resolves.toBe(true);
      expect(nodemailer.createTransport).not.toHaveBeenCalled();
    });

    it('en producción falla en lugar de perder el correo en silencio', async () => {
      const service = build({ nodeEnv: 'production' });

      await expect(service.send('a@b.com', 'Asunto', 'Cuerpo')).resolves.toBe(false);
    });

    it('verify dice que falta configurar', async () => {
      expect(await build({ nodeEnv: 'development' }).verify()).toEqual({ ok: false, error: 'SMTP_HOST no está definido' });
    });
  });

  describe('con SMTP', () => {
    it('envía con el remitente, el destinatario, el texto y el HTML', async () => {
      await expect(build(smtp()).send('ana@mail.com', 'Hola', 'texto', '<p>html</p>')).resolves.toBe(true);

      expect(sendMail).toHaveBeenCalledWith({
        from: 'Fidelity <fidelity@gmail.com>',
        to: 'ana@mail.com',
        subject: 'Hola',
        text: 'texto',
        html: '<p>html</p>',
      });
    });

    it('con el puerto 587 exige cifrado (STARTTLS) y pone tiempos de espera', async () => {
      await build(smtp()).send('ana@mail.com', 'x', 'y');

      expect(nodemailer.createTransport).toHaveBeenCalledWith(
        expect.objectContaining({
          host: 'smtp.gmail.com',
          port: 587,
          secure: false,
          requireTLS: true,
          auth: { user: 'fidelity@gmail.com', pass: 'claveapp' },
          connectionTimeout: 10_000,
          greetingTimeout: 10_000,
          socketTimeout: 20_000,
        }),
      );
    });

    it('con el puerto 465 usa TLS directo', async () => {
      await build(smtp({ 'mail.port': 465 })).send('ana@mail.com', 'x', 'y');

      expect(nodemailer.createTransport).toHaveBeenCalledWith(expect.objectContaining({ port: 465, secure: true, requireTLS: false }));
    });

    it('SMTP_SECURE y SMTP_REQUIRE_TLS se pueden forzar', async () => {
      await build(smtp({ 'mail.port': 2525, 'mail.secure': true })).send('a@b.com', 'x', 'y');
      expect(nodemailer.createTransport).toHaveBeenLastCalledWith(expect.objectContaining({ secure: true }));

      await build(smtp({ 'mail.port': 1025, 'mail.requireTls': false })).send('a@b.com', 'x', 'y');
      expect(nodemailer.createTransport).toHaveBeenLastCalledWith(expect.objectContaining({ requireTLS: false }));
    });

    it('sin usuario no manda credenciales (servidor interno)', async () => {
      await build(smtp({ 'mail.user': '' })).send('a@b.com', 'x', 'y');

      expect(nodemailer.createTransport).toHaveBeenCalledWith(expect.objectContaining({ auth: undefined }));
    });

    it('reutiliza la conexión entre correos', async () => {
      const service = build(smtp());

      await service.send('a@b.com', 'uno', 'x');
      await service.send('c@d.com', 'dos', 'y');

      expect(nodemailer.createTransport).toHaveBeenCalledTimes(1);
      expect(sendMail).toHaveBeenCalledTimes(2);
    });

    it('si el servidor falla devuelve false y no lanza', async () => {
      sendMail.mockRejectedValue(Object.assign(new Error('boom'), { code: 'ETIMEDOUT' }));

      await expect(build(smtp()).send('a@b.com', 'x', 'y')).resolves.toBe(false);
    });

    it('sendContent manda el asunto, el texto y el HTML de la plantilla', async () => {
      await build(smtp()).sendContent('a@b.com', { subject: 'S', text: 'T', html: '<b>H</b>' });

      expect(sendMail).toHaveBeenCalledWith(expect.objectContaining({ to: 'a@b.com', subject: 'S', text: 'T', html: '<b>H</b>' }));
    });
  });

  describe('verify y mensajes de error', () => {
    it('con claves correctas dice ok', async () => {
      expect(await build(smtp()).verify()).toEqual({ ok: true });
    });

    it('con claves rechazadas explica lo de la contraseña de aplicación de Gmail', async () => {
      verify.mockRejectedValue(Object.assign(new Error('Invalid login'), { code: 'EAUTH', response: '535 5.7.8 Username and Password not accepted' }));

      const result = await build(smtp()).verify();

      expect(result.ok).toBe(false);
      expect(result.error).toContain('contraseña de aplicación');
    });

    it('si no llega al servidor lo dice', async () => {
      verify.mockRejectedValue(Object.assign(new Error('connect'), { code: 'ECONNREFUSED' }));

      expect((await build(smtp()).verify()).error).toContain('No se pudo conectar');
    });

    it('un error desconocido se muestra recortado', () => {
      expect(build(smtp()).explain(new Error('x'.repeat(500))).length).toBeLessThanOrEqual(200);
    });

    it('un destinatario inválido se explica', () => {
      expect(build(smtp()).explain({ code: 'EENVELOPE' })).toContain('destinatario');
    });
  });
});
