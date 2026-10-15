import { Controller, Get, Param, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import { PaymentsService } from './payments.service';

type Outcome = 'approved' | 'cancelled' | 'failed' | 'error';

const PAGES: Record<Outcome, { title: string; message: string }> = {
  approved: {
    title: '¡Pago aprobado!',
    message:
      'Tu pago con tarjeta fue aprobado y tu cuenta ya está activa. Ya puedes volver a la app de Fidelity.',
  },
  cancelled: {
    title: 'Pago cancelado',
    message: 'No se realizó ningún cobro. Vuelve a la app de Fidelity para intentarlo de nuevo.',
  },
  failed: {
    title: 'No pudimos confirmar tu pago',
    message:
      'Si se te cobró, no pagues de nuevo: vuelve a la app y revisa el estado de tu pago o avísanos con tu referencia.',
  },
  error: {
    title: 'Enlace no válido',
    message: 'No encontramos este pago. Vuelve a la app de Fidelity.',
  },
};

function page(outcome: Outcome, reference?: string): string {
  const { title, message } = PAGES[outcome];
  const ref = reference
    ? `<p class="ref">Referencia <strong>${reference.replace(/[^A-Z0-9-]/gi, '')}</strong></p>`
    : '';
  return `<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Fidelity · ${title}</title>
<style>
  body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
    background:#fff;color:#000;font-family:Helvetica,Arial,sans-serif;padding:24px;box-sizing:border-box}
  main{max-width:420px;text-align:center}
  .badge{display:inline-block;background:#ffb3d9;border:1.5px solid #000;border-radius:999px;
    padding:6px 18px;letter-spacing:.2em;font-size:12px;font-weight:700;margin-bottom:20px}
  h1{font-size:30px;margin:0 0 12px;text-transform:uppercase;letter-spacing:.04em}
  p{font-size:16px;line-height:1.5;margin:0 0 12px;font-weight:300}
  .ref{font-size:14px}
</style></head>
<body><main>
  <span class="badge">FIDELITY</span>
  <h1>${title}</h1>
  <p>${message}</p>
  ${ref}
</main></body></html>`;
}

/**
 * Direcciones a las que PayPhone devuelve al cliente tras pagar o cancelar.
 * Son públicas (las abre el navegador del cliente, sin sesión): el cobro se
 * confirma con PayPhone desde el servidor, no con lo que llegue en la URL.
 */
@Controller('payments/payphone')
export class PayphoneReturnController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Get('return')
  async onReturn(
    @Query('id') id: string,
    @Query('clientTransactionId') clientTransactionId: string,
    @Res() res: Response,
  ) {
    const gatewayId = Number(id);
    if (!Number.isInteger(gatewayId) || gatewayId <= 0 || !clientTransactionId) {
      return this.send(res, 'error');
    }

    try {
      const result = await this.paymentsService.confirmCardPayment(
        gatewayId,
        String(clientTransactionId).slice(0, 20),
      );
      return this.send(res, result.outcome, result.reference);
    } catch {
      return this.send(res, 'error');
    }
  }

  /**
   * Pasarela propia: abre PayPhone desde el dominio autorizado de la app (ver
   * PayphoneService.launchUrl). Es una página, no un 302: el navegador envía
   * como origen la página que redirige.
   */
  @Get('pay/:clientTxId')
  async onPay(@Param('clientTxId') clientTxId: string, @Res() res: Response) {
    const url = await this.paymentsService.getCardRedirect(clientTxId.slice(0, 20));
    if (!url) return this.send(res, 'error');

    // `url` ya se validó como dirección de PayPhone; se escapa para el atributo.
    const safe = url.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
    res
      .status(200)
      .set({
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-store',
        'Referrer-Policy': 'origin',
        'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'",
      })
      .send(`<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="origin">
<meta http-equiv="refresh" content="0;url=${safe}">
<title>Fidelity · Ir a pagar</title>
<style>body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
font-family:Helvetica,Arial,sans-serif;text-align:center;padding:24px}
a{display:inline-block;margin-top:16px;padding:14px 28px;border:1.5px solid #000;border-radius:999px;
color:#000;font-weight:700;text-decoration:none;letter-spacing:.1em}</style></head>
<body><main><p>Te estamos llevando a PayPhone…</p>
<a href="${safe}" referrerpolicy="origin">CONTINUAR</a></main></body></html>`);
  }

  @Get('cancel')
  onCancel(@Res() res: Response) {
    return this.send(res, 'cancelled');
  }

  private send(res: Response, outcome: Outcome, reference?: string) {
    res
      .status(200)
      .set({
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-store',
        'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'",
      })
      .send(page(outcome, reference));
  }
}
