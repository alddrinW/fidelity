// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fidelity_app/features/business/qr_management/qr_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('QR Management Screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: QRManagementScreen(businessId: 'test-business-id'),
      ),
    );

    // Verify loading state or empty state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Nuevo QR'), findsOneWidget);

    // Tap the button
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('Generar nuevo QR'), findsOneWidget);
    expect(find.text('Etiqueta (ej: Caja 1)'), findsOneWidget);
    expect(find.text('Generar'), findsOneWidget);
  });
}
