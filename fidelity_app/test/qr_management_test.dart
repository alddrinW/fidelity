// ignore_for_file: depend_on_referenced_packages
import 'package:fidelity_app/features/business/qr_management/qr_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Sin red en los tests: no intentar descargar las fuentes.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('QR: muestra la carga y, sin códigos, ofrece generar el primero', (tester) async {
    await tester.pumpWidget(
      spanishApp(const Scaffold(body: QRManagementScreen(businessId: 'test-business-id'))),
    );

    // Al abrir carga los códigos del negocio.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // En los tests toda llamada HTTP responde 400: la lista queda vacía.
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('SIN CÓDIGOS QR'), findsOneWidget);
    expect(find.text('GENERAR MI QR'), findsOneWidget);
  });
}
