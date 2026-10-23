import { AppThrottlerGuard } from './app-throttler.guard';

describe('AppThrottlerGuard', () => {
  // El rastreo de quién es la persona no usa el resto del guard.
  const guard = Object.create(AppThrottlerGuard.prototype) as AppThrottlerGuard;
  const tracker = (req: any): Promise<string> => (guard as any).getTracker(req);

  it('en el inicio de sesión cuenta por IP y correo (en minúsculas)', async () => {
    const req = { ip: '10.0.0.5', originalUrl: '/api/v1/auth/login', body: { email: ' Ana@Mail.com ' } };

    expect(await tracker(req)).toBe('10.0.0.5|ana@mail.com');
  });

  it('lo mismo al pedir y al usar el código de recuperación', async () => {
    for (const url of ['/api/v1/auth/forgot-password', '/api/v1/auth/reset-password']) {
      expect(await tracker({ ip: '1.2.3.4', originalUrl: url, body: { email: 'a@b.com' } })).toBe('1.2.3.4|a@b.com');
    }
  });

  it('dos correos distintos desde la misma IP no se bloquean entre sí', async () => {
    const a = await tracker({ ip: '1.1.1.1', originalUrl: '/api/v1/auth/login', body: { email: 'a@b.com' } });
    const b = await tracker({ ip: '1.1.1.1', originalUrl: '/api/v1/auth/login', body: { email: 'c@d.com' } });

    expect(a).not.toBe(b);
  });

  it('el registro y el resto de la API cuentan solo por IP', async () => {
    expect(await tracker({ ip: '1.2.3.4', originalUrl: '/api/v1/auth/register', body: { email: 'a@b.com' } })).toBe('1.2.3.4');
    expect(await tracker({ ip: '1.2.3.4', originalUrl: '/api/v1/campaigns/feed', body: {} })).toBe('1.2.3.4');
  });

  it('sin correo en el cuerpo, solo la IP', async () => {
    expect(await tracker({ ip: '9.9.9.9', originalUrl: '/api/v1/auth/login', body: {} })).toBe('9.9.9.9');
  });

  it('sin IP conocida usa la del socket', async () => {
    expect(await tracker({ socket: { remoteAddress: '::1' }, originalUrl: '/x', body: {} })).toBe('::1');
  });

  it('las conexiones que no son HTTP (tiempo real) no se limitan aquí', async () => {
    const context = { getType: () => 'ws' } as any;

    await expect(guard.canActivate(context)).resolves.toBe(true);
  });
});
