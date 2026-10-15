import { ConfigService } from '@nestjs/config';
import { MailService } from './mail.service';

describe('MailService', () => {
  const build = (values: Record<string, any>) =>
    new MailService({ get: (k: string) => values[k] } as ConfigService);

  it('sin SMTP y fuera de producción deja el correo en el log y devuelve true', async () => {
    const service = build({ nodeEnv: 'development' });

    expect(service.isConfigured()).toBe(false);
    await expect(service.send('a@b.com', 'Asunto', 'Cuerpo')).resolves.toBe(true);
  });

  it('sin SMTP en producción falla en lugar de perder el correo en silencio', async () => {
    const service = build({ nodeEnv: 'production' });

    await expect(service.send('a@b.com', 'Asunto', 'Cuerpo')).resolves.toBe(false);
  });
});
