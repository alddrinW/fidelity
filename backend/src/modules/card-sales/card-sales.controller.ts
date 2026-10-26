import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { UserRole } from '../../database/entities/profile.entity';
import { CARD_SALES_AREA, CardSalesService, PurchaseOutcome } from './card-sales.service';
import { SettlePayoutDto } from './dto/card-sales.dto';

/** Las tarjetas en venta: el cliente las ve y las compra; el dueño ve lo vendido; el administrador paga a los locales. */
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('card-sales')
export class CardSalesController {
  constructor(private readonly cardSales: CardSalesService) {}

  /** Las reglas de la venta de tarjetas (para el formulario del dueño y la tienda del cliente). */
  @Get('rules')
  @Roles(UserRole.CLIENT, UserRole.BUSINESS, UserRole.ADMIN)
  rules() {
    return this.cardSales.rules();
  }

  // --- Cliente ---

  /** Las tarjetas en venta que el cliente puede comprar. */
  @Get('offers')
  @Roles(UserRole.CLIENT)
  offers(@CurrentUser() user: AuthenticatedUser) {
    return this.cardSales.offersFor(user.id);
  }

  /** Empieza la compra: devuelve la página de pago de PayPhone. */
  @Post(':campaignId/purchase')
  @Roles(UserRole.CLIENT)
  purchase(
    @CurrentUser() user: AuthenticatedUser,
    @Param('campaignId', ParseUUIDPipe) campaignId: string,
  ) {
    return this.cardSales.startPurchase(user.id, campaignId, user.email);
  }

  // --- Dueño ---

  @Get('mine')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  mine(@CurrentUser() user: AuthenticatedUser) {
    return this.cardSales.mySales(user);
  }

  // --- Administrador ---

  @Get('admin/payouts')
  @Roles(UserRole.ADMIN)
  payouts() {
    return this.cardSales.payouts();
  }

  @Post('admin/payouts/:businessId')
  @Roles(UserRole.ADMIN)
  settle(
    @CurrentUser() user: AuthenticatedUser,
    @Param('businessId', ParseUUIDPipe) businessId: string,
    @Body() dto: SettlePayoutDto,
  ) {
    return this.cardSales.settle(businessId, user.id, dto.note);
  }

  @Post('admin/refunds/:purchaseId')
  @Roles(UserRole.ADMIN)
  refunded(
    @CurrentUser() user: AuthenticatedUser,
    @Param('purchaseId', ParseUUIDPipe) purchaseId: string,
    @Body() dto: SettlePayoutDto,
  ) {
    return this.cardSales.markRefunded(purchaseId, user.id, dto.note);
  }
}

const PAGES: Record<PurchaseOutcome | 'error', { title: string; message: string }> = {
  approved: {
    title: '¡Compra aprobada!',
    message: 'Tu pago fue aprobado y tu tarjeta ya está en Mis regalos. Vuelve a la app de Fidelity.',
  },
  cancelled: {
    title: 'Pago cancelado',
    message: 'No se realizó ningún cobro. Vuelve a la app de Fidelity para intentarlo de nuevo.',
  },
  failed: {
    title: 'No pudimos confirmar tu pago',
    message:
      'Si se te cobró, no pagues de nuevo: vuelve a la app y revisa Mis regalos o avísanos con tu referencia.',
  },
  error: {
    title: 'Enlace no válido',
    message: 'No encontramos esta compra. Vuelve a la app de Fidelity.',
  },
};

function page(outcome: PurchaseOutcome | 'error', reference?: string): string {
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
 * Direcciones a las que PayPhone devuelve al cliente tras pagar una tarjeta.
 * Son públicas (las abre su navegador, sin sesión): el cobro se confirma con
 * PayPhone desde el servidor, no con lo que llegue en la dirección.
 */
@Controller(CARD_SALES_AREA)
export class CardSalesPayphoneController {
  constructor(private readonly cardSales: CardSalesService) {}

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
      const result = await this.cardSales.confirm(gatewayId, String(clientTransactionId).slice(0, 20));
      return this.send(res, result.outcome, result.reference);
    } catch {
      return this.send(res, 'error');
    }
  }

  /** Abre PayPhone desde el dominio autorizado de la app (igual que los pagos de registro). */
  @Get('pay/:clientTxId')
  async onPay(@Param('clientTxId') clientTxId: string, @Res() res: Response) {
    const url = await this.cardSales.getRedirect(clientTxId.slice(0, 20));
    if (!url) return this.send(res, 'error');

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

  private send(res: Response, outcome: PurchaseOutcome | 'error', reference?: string) {
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
