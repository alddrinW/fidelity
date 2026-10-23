import { ExecutionContext, Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/** Rutas donde el límite es por persona (IP + correo), no solo por IP. */
const PER_ACCOUNT_ROUTES = /\/auth\/(login|forgot-password|reset-password)\b/;

/**
 * Límite de intentos para toda la API. Contra quien prueba contraseñas: en el
 * inicio de sesión y la recuperación de contraseña el límite se cuenta por IP
 * **y** correo, así alguien no puede adivinar la clave de una cuenta a base de
 * intentos, y quien se equivoca con su propio correo no bloquea a los demás.
 *
 * Solo aplica a las rutas HTTP (los sockets de tiempo real no se limitan aquí).
 */
@Injectable()
export class AppThrottlerGuard extends ThrottlerGuard {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (context.getType() !== 'http') return true;
    return super.canActivate(context);
  }

  protected async getTracker(req: Record<string, any>): Promise<string> {
    const ip: string = req.ip ?? req.socket?.remoteAddress ?? 'desconocida';
    const url: string = req.originalUrl ?? req.url ?? '';
    const email = typeof req.body?.email === 'string' ? req.body.email.toLowerCase().trim() : '';
    return email && PER_ACCOUNT_ROUTES.test(url) ? `${ip}|${email}` : ip;
  }
}
