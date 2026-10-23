import {
  Body,
  Controller,
  Get,
  Param,
  ParseEnumPipe,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { PaymentsService } from './payments.service';
import {
  CreateOrderDto,
  RejectPaymentDto,
  ReportPaymentDto,
  UpdateBankAccountsDto,
  UpdatePricesDto,
} from './dto/payments.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../../common/interfaces/jwt-payload.interface';
import { UserRole } from '../../database/entities/profile.entity';
import { PaymentStatus } from '../../database/entities/payment.entity';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  /** Precios del plan, para el asistente "PAGA YA". */
  @Get('plan')
  @Roles(UserRole.BUSINESS, UserRole.CLIENT, UserRole.ADMIN)
  getPlan() {
    return this.paymentsService.getPlan();
  }

  /** El administrador fija los precios del registro y de las sucursales. */
  @Patch('plan')
  @Roles(UserRole.ADMIN)
  updatePrices(@Body() dto: UpdatePricesDto) {
    return this.paymentsService.updatePrices(dto);
  }

  /** El administrador fija las cuentas bancarias para transferencias y depósitos. */
  @Put('bank-accounts')
  @Roles(UserRole.ADMIN)
  updateBankAccounts(@Body() dto: UpdateBankAccountsDto) {
    return this.paymentsService.updateBankAccounts(dto);
  }

  @Get('mine')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  listMine(@CurrentUser() user: AuthenticatedUser) {
    return this.paymentsService.listMine(user.id);
  }

  /** Orden de pago vigente de un negocio inactivo (la crea si no existe). */
  @Post('order')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  ensureOrder(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateOrderDto,
  ) {
    return this.paymentsService.ensureOrder(dto.businessId, user.id);
  }

  /** Inicia el pago con tarjeta: devuelve la página de pago de PayPhone. */
  @Post(':id/card')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  startCard(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.paymentsService.startCardPayment(id, user.id);
  }

  @Post(':id/report')
  @Roles(UserRole.BUSINESS, UserRole.ADMIN)
  report(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReportPaymentDto,
  ) {
    return this.paymentsService.report(id, user.id, dto);
  }

  // --- Administración ---

  @Get()
  @Roles(UserRole.ADMIN)
  listAll(
    @Query('status', new ParseEnumPipe(PaymentStatus, { optional: true }))
    status?: PaymentStatus,
  ) {
    return this.paymentsService.listAll(status);
  }

  /** Detalle de un pago: comprobante, negocio y dueño. */
  @Get(':id')
  @Roles(UserRole.ADMIN)
  getOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.paymentsService.getOne(id);
  }

  @Patch(':id/validate')
  @Roles(UserRole.ADMIN)
  validate(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.paymentsService.validate(id, user.id);
  }

  @Patch(':id/reject')
  @Roles(UserRole.ADMIN)
  reject(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectPaymentDto,
  ) {
    return this.paymentsService.reject(id, dto.reason);
  }
}
