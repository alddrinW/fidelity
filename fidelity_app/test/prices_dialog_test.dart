import 'package:fidelity_app/features/admin/widgets/prices_dialog.dart';
import 'package:fidelity_app/features/payments/data/payments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

class _FakePaymentsRepository extends PaymentsRepository {
  final List<({double registration, double branch})> saved = [];

  @override
  Future<PaymentPlan> getPlan() async =>
      const PaymentPlan(currency: 'USD', registrationFee: 20, branchFee: 10);

  @override
  Future<PaymentPlan> updatePrices({
    required double registrationFee,
    required double branchFee,
  }) async {
    saved.add((registration: registrationFee, branch: branchFee));
    return PaymentPlan(currency: 'USD', registrationFee: registrationFee, branchFee: branchFee);
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late _FakePaymentsRepository repository;

  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repository = _FakePaymentsRepository();

    await tester.pumpWidget(
      spanishApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPricesDialog(context, repository),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }


  testWidgets('muestra los precios vigentes', (tester) async {
    await openDialog(tester);

    expect(find.text('PRECIOS DEL REGISTRO'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '20.00'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '10.00'), findsOneWidget);
  });

  testWidgets('guarda los precios nuevos (acepta coma decimal)', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '20.00'), '35,5');
    await tester.enterText(find.widgetWithText(TextFormField, '10.00'), '12');
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();

    expect(repository.saved, [(registration: 35.5, branch: 12.0)]);
    expect(find.text('PRECIOS DEL REGISTRO'), findsNothing);
    // Deja correr el aviso temporal.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('un precio vacío o demasiado bajo no se guarda', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '20.00'), '');
    await tester.enterText(find.widgetWithText(TextFormField, '10.00'), '0.1');
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un precio'), findsOneWidget);
    expect(find.text('El mínimo es 0.50'), findsOneWidget);
    expect(repository.saved, isEmpty);
    expect(find.text('PRECIOS DEL REGISTRO'), findsOneWidget);
  });
}
