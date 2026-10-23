/**
 * Prueba el correo saliente sin levantar el servidor:
 *
 *   npm run mail:test -- tu@correo.com          comprueba las claves y envía un correo de prueba
 *   npm run mail:test -- tu@correo.com en       el mismo, en inglés
 *   npm run mail:test                           solo comprueba la conexión (no envía nada)
 *
 * Nunca muestra la clave del correo.
 */
import { ConfigService } from '@nestjs/config';
import * as dotenv from 'dotenv';
import { configuration } from '../config/configuration';
import { MailService } from '../modules/mail/mail.service';
import { testEmail } from '../modules/mail/mail-templates';

dotenv.config();

async function main() {
  const [to, language] = process.argv.slice(2);
  const config = new ConfigService(configuration());
  const mail = new MailService(config);

  if (!mail.isConfigured()) {
    console.error('SMTP no está configurado. Define SMTP_HOST, SMTP_USER y SMTP_PASS en backend/.env (mira docs/correo.md).');
    process.exit(1);
  }

  const host = config.get<string>('mail.host');
  const port = config.get<number>('mail.port');
  const user = config.get<string>('mail.user');
  console.log(`Servidor: ${host}:${port}  ·  usuario: ${user || '(sin usuario)'}  ·  remitente: ${config.get('mail.from')}`);

  const check = await mail.verify();
  if (!check.ok) {
    console.error(`No se pudo iniciar sesión en el servidor de correo.\n  ${check.error}`);
    process.exit(1);
  }
  console.log('Conexión y claves: correctas.');

  if (!to) {
    console.log('Para enviar un correo de prueba agrega un destinatario: npm run mail:test -- tu@correo.com');
    return;
  }

  const sent = await mail.sendContent(to, testEmail(language));
  if (!sent) {
    console.error(`El servidor aceptó las claves pero no pudo enviar el correo a ${to}. Mira el mensaje de arriba.`);
    process.exit(1);
  }
  console.log(`Correo de prueba enviado a ${to}. Revisa la bandeja de entrada (y el spam, la primera vez).`);
}

main().catch((error) => {
  console.error('Error:', error.message);
  process.exit(1);
});
