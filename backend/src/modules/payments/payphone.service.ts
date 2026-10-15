import { BadGatewayException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/** Respuesta de "Prepare": las dos páginas de pago de PayPhone. */
export interface PayphoneCheckout {
  paymentId: number | string;
  payWithCard: string;
  payWithPayPhone: string;
}

/** Resultado de "Confirm" (solo los campos que usa Fidelity). */
export interface PayphoneConfirmation {
  /** 3 = aprobada, 2 = cancelada. */
  statusCode: number;
  transactionStatus: string;
  transactionId: number | string;
  clientTransactionId: string;
  authorizationCode?: string;
  /** Monto en centavos. */
  amount: number;
  currency?: string;
  lastDigits?: string;
  cardBrand?: string;
}

export const PAYPHONE_APPROVED = 3;

/**
 * Cliente de PayPhone (botón de pago por redirección): "Prepare" crea la
 * página de pago y, cuando el cliente vuelve, "Confirm" verifica el cobro
 * desde el servidor con el token, de modo que nadie puede darlo por pagado
 * solo con abrir la dirección de retorno.
 */
@Injectable()
export class PayphoneService {
  private readonly logger = new Logger(PayphoneService.name);

  constructor(private readonly configService: ConfigService) {}

  private get token(): string {
    return this.configService.get<string>('payments.payphone.token') ?? '';
  }

  private get storeId(): string {
    return this.configService.get<string>('payments.payphone.storeId') ?? '';
  }

  private get apiUrl(): string {
    return (
      this.configService.get<string>('payments.payphone.apiUrl') ??
      'https://pay.payphonetodoesposible.com'
    );
  }

  private get publicApiUrl(): string {
    return this.configService.get<string>('payments.payphone.publicApiUrl') ?? '';
  }

  /**
   * Hay token y una dirección pública a la que PayPhone devuelva al cliente.
   * El Store ID es opcional: solo hace falta si la cuenta tiene varias tiendas.
   */
  isConfigured(): boolean {
    return !!(this.token && this.publicApiUrl);
  }

  /**
   * Dirección con la que se abre el pago. PayPhone solo muestra su página si el
   * navegador llega desde el dominio autorizado de la app (si no, responde "No
   * autorizado"), así que no se abre PayPhone directo: se pasa por una página
   * del backend, que redirige y así deja ese dominio como origen.
   */
  launchUrl(clientTransactionId: string): string {
    const prefix = this.configService.get<string>('apiPrefix') ?? 'api/v1';
    return `${this.publicApiUrl}/${prefix}/payments/payphone/pay/${encodeURIComponent(clientTransactionId)}`;
  }

  /** Solo se redirige a páginas de PayPhone (nunca a una dirección arbitraria). */
  isPayphoneUrl(url: string | null | undefined): url is string {
    if (!url) return false;
    try {
      return new URL(url).origin === new URL(this.apiUrl).origin;
    } catch {
      return false;
    }
  }

  /** Dirección a la que PayPhone devuelve al cliente (`path` es `return` o `cancel`). */
  returnUrl(path: 'return' | 'cancel'): string {
    const prefix = this.configService.get<string>('apiPrefix') ?? 'api/v1';
    return `${this.publicApiUrl}/${prefix}/payments/payphone/${path}`;
  }

  async prepare(input: {
    /** Monto en centavos (sin impuestos adicionales). */
    amountCents: number;
    clientTransactionId: string;
    reference: string;
    email?: string | null;
  }): Promise<PayphoneCheckout> {
    const body: Record<string, unknown> = {
      amount: input.amountCents,
      amountWithoutTax: input.amountCents,
      currency: this.configService.get<string>('payments.currency') ?? 'USD',
      clientTransactionId: input.clientTransactionId,
      reference: input.reference,
      responseUrl: this.returnUrl('return'),
      cancellationUrl: this.returnUrl('cancel'),
      lang: 'es',
    };
    if (this.storeId) body.storeId = this.storeId;
    if (input.email) body.email = input.email;

    const data = await this.post('/api/button/Prepare', body);
    if (!data?.payWithCard || !data?.payWithPayPhone) {
      this.logger.error(`Respuesta inesperada de PayPhone al preparar: ${JSON.stringify(data)}`);
      throw new BadGatewayException('PayPhone no devolvió la página de pago');
    }
    return data as PayphoneCheckout;
  }

  async confirm(id: number, clientTxId: string): Promise<PayphoneConfirmation> {
    return (await this.post('/api/button/V2/Confirm', { id, clientTxId })) as PayphoneConfirmation;
  }

  private async post(path: string, body: Record<string, unknown>): Promise<any> {
    let response: Response;
    try {
      response = await fetch(`${this.apiUrl}${path}`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(15000),
      });
    } catch (error) {
      this.logger.error(`No se pudo contactar a PayPhone (${path}): ${error.message}`);
      throw new BadGatewayException('No se pudo contactar a PayPhone. Inténtalo de nuevo.');
    }

    const data = await response.json().catch(() => null);
    if (!response.ok) {
      this.logger.error(
        `PayPhone respondió ${response.status} en ${path}: ${JSON.stringify(data)}`,
      );
      throw new BadGatewayException(
        'PayPhone rechazó la solicitud de pago. Inténtalo de nuevo en unos minutos.',
      );
    }
    return data;
  }
}
