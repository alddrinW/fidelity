import 'package:fidelity_app/features/payments/data/payments_repository.dart';
import 'package:fidelity_app/features/payments/paga_ya_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final order = PaymentOrder.fromJson({
    'id': 'p1',
    'businessId': 'b1',
    'business': {'name': 'Café Aurora'},
    'amount': 20,
    'currency': 'USD',
    'status': 'pending',
    'reference': 'FID-ABC234',
  });

  PaymentPlan plan({bool bank = true, bool card = true}) => PaymentPlan(
        currency: 'USD',
        registrationFee: 20,
        branchFee: 10,
        bankAccounts: bank
            ? const [
                BankAccount(
                  bank: 'Banco de Loja',
                  accountNumber: '2900000001',
                  accountType: 'Cuenta de ahorros',
                  holder: 'Titular Uno',
                  taxId: '1100000001',
                ),
                BankAccount(
                  bank: 'Banco Pichincha',
                  accountNumber: '2200000002',
                  accountType: 'Cuenta de ahorro transaccional',
                  holder: 'Titular Dos',
                  taxId: '1100000002',
                ),
              ]
            : const [],
        cardEnabled: card,
      );

  Future<void> open(WidgetTester tester, PaymentPlan plan) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [paymentPlanProvider.overrideWith((ref) async => plan)],
        child: spanishApp(PagaYaScreen(order: order)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Siguiente paso'));
    await tester.pumpAndSettle();
  }

  testWidgets('el primer paso muestra el plan y el costo', (tester) async {
    await open(tester, plan());

    expect(find.text('\$20.00 USD'), findsOneWidget);
    expect(find.text('Pago único para activar Café Aurora'), findsOneWidget);
  });

  testWidgets('no se puede avanzar del método sin elegir uno', (tester) async {
    await open(tester, plan());
    await next(tester);

    expect(find.text('Elige cómo quieres pagar.'), findsOneWidget);
    expect(find.text('TRANSFERENCIA BANCARIA'), findsOneWidget);
    expect(find.text('TARJETA DÉBITO/CRÉDITO'), findsOneWidget);

    await tester.tap(find.byTooltip('Siguiente paso'));
    await tester.pumpAndSettle();
    expect(find.text('Elige cómo quieres pagar.'), findsOneWidget);
  });

  testWidgets('la transferencia muestra los datos de la cuenta y pide el comprobante', (tester) async {
    await open(tester, plan());
    await next(tester);

    await tester.tap(find.text('TRANSFERENCIA BANCARIA'));
    await tester.pumpAndSettle();

    // Se muestran todas las cuentas configuradas, cada una con sus datos.
    expect(find.text('BANCO DE LOJA'), findsOneWidget);
    expect(find.text('2900000001'), findsOneWidget);
    expect(find.text('Titular Uno'), findsOneWidget);
    expect(find.text('BANCO PICHINCHA'), findsOneWidget);
    expect(find.text('2200000002'), findsOneWidget);
    expect(find.text('Cuenta de ahorro transaccional'), findsOneWidget);
    expect(find.text('FID-ABC234'), findsOneWidget);
    expect(find.text('TRANSFIERE O DEPOSITA A UNA DE ESTAS CUENTAS'), findsOneWidget);

    await next(tester);

    expect(find.text('FOTO DEL COMPROBANTE *'), findsOneWidget);
    expect(find.text('HAZ CLIC AQUÍ PARA SUBIR LA FOTO'), findsOneWidget);
    expect(find.text('ENVIAR COMPROBANTE'), findsOneWidget);
  });

  testWidgets('enviar la transferencia sin foto muestra el aviso y no reporta', (tester) async {
    await open(tester, plan());
    await next(tester);
    await tester.tap(find.text('TRANSFERENCIA BANCARIA'));
    await tester.pumpAndSettle();
    await next(tester);

    await tester.tap(find.text('ENVIAR COMPROBANTE'));
    await tester.pump();

    expect(find.text('Adjunta la foto del comprobante.'), findsOneWidget);
  });

  testWidgets('la tarjeta explica los pasos y lleva a PayPhone', (tester) async {
    await open(tester, plan());
    await next(tester);

    await tester.tap(find.text('TARJETA DÉBITO/CRÉDITO'));
    await tester.pumpAndSettle();

    expect(find.text('Pasos rápidos para pagar:'), findsOneWidget);
    expect(find.text('Te llevaremos a PayPhone, una pasarela de pago 100% segura.'), findsOneWidget);
    expect(find.text('Vuelve aquí: confirmaremos tu pago y activaremos tu cuenta automáticamente.'), findsOneWidget);

    await next(tester);

    expect(find.text('IR A PAGAR CON TARJETA'), findsOneWidget);
    expect(find.text('YA PAGUÉ'), findsOneWidget);
  });

  testWidgets('solo se ofrecen los métodos configurados', (tester) async {
    await open(tester, plan(card: false));
    await next(tester);

    expect(find.text('TRANSFERENCIA BANCARIA'), findsOneWidget);
    expect(find.text('TARJETA DÉBITO/CRÉDITO'), findsNothing);
  });

  testWidgets('sin ningún método configurado avisa y no deja avanzar', (tester) async {
    await open(tester, plan(bank: false, card: false));
    await next(tester);

    expect(
      find.text('Los métodos de pago aún no están disponibles. Inténtalo más tarde.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Siguiente paso'));
    await tester.pumpAndSettle();
    expect(find.text('FOTO DEL COMPROBANTE *'), findsNothing);
  });
}
