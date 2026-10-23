import 'package:fidelity_app/features/admin/widgets/bank_accounts_dialog.dart';
import 'package:fidelity_app/features/payments/data/payments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

class _FakePaymentsRepository extends PaymentsRepository {
  final List<List<BankAccount>> saved = [];
  String? failWith;
  List<BankAccount> accounts = const [
    BankAccount(
      bank: 'Banco de Loja',
      accountNumber: '2900000001',
      accountType: 'Cuenta de ahorros',
      holder: 'Titular Uno',
      taxId: '1100000001',
    ),
  ];

  @override
  Future<PaymentPlan> getPlan() async => PaymentPlan(
        currency: 'USD',
        registrationFee: 20,
        branchFee: 10,
        bankAccounts: accounts,
      );

  @override
  Future<PaymentPlan> updateBankAccounts(List<BankAccount> accounts) async {
    if (failWith != null) throw failWith!;
    saved.add(accounts);
    return getPlan();
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late _FakePaymentsRepository repository;

  Future<void> openDialog(WidgetTester tester, {List<BankAccount>? accounts}) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repository = _FakePaymentsRepository();
    if (accounts != null) repository.accounts = accounts;

    await tester.pumpWidget(
      spanishApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showBankAccountsDialog(context, repository),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra las cuentas vigentes para editarlas', (tester) async {
    await openDialog(tester);

    expect(find.text('CUENTAS BANCARIAS'), findsOneWidget);
    expect(find.text('Cuenta 1'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Banco de Loja'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '2900000001'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Titular Uno'), findsOneWidget);
  });

  testWidgets('cambia el titular y guarda', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Titular Uno'), 'Fidelity S.A.');
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.single.holder, 'Fidelity S.A.');
    expect(repository.saved.single.single.accountNumber, '2900000001');
    expect(find.text('CUENTAS BANCARIAS'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('agrega una cuenta nueva; los campos obligatorios se piden', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Agregar cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Cuenta 2'), findsOneWidget);

    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();
    expect(find.text('Campo obligatorio'), findsWidgets);
    expect(repository.saved, isEmpty);
  });

  testWidgets('un número de cuenta muy corto no se acepta', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '2900000001'), '12');
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();

    expect(find.text('Entre 4 y 30 dígitos'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('quitar todas las cuentas guarda una lista vacía (solo tarjeta)', (tester) async {
    await openDialog(tester);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Cuenta 1'), findsNothing);

    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();

    expect(repository.saved, [isEmpty]);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('dos cuentas con el mismo número no se guardan', (tester) async {
    await openDialog(tester, accounts: const [
      BankAccount(bank: 'A', accountNumber: '1111', holder: 'X'),
      BankAccount(bank: 'B', accountNumber: '1111', holder: 'Y'),
    ]);

    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();

    expect(find.text('Hay dos cuentas con el mismo número'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('si el servidor rechaza, muestra el motivo y no cierra', (tester) async {
    await openDialog(tester);
    repository.failWith = 'Puedes registrar hasta 5 cuentas';

    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();

    expect(find.text('Puedes registrar hasta 5 cuentas'), findsOneWidget);
    expect(find.text('CUENTAS BANCARIAS'), findsOneWidget);
  });
}
