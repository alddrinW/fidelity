// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fidelity_app/features/business/create_business_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Sin red en los tests: no intentar descargar las fuentes.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('CreateBusinessScreen muestra el primer paso "Mi negocio"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: spanishApp(const CreateBusinessScreen()),
      ),
    );

    expect(find.byType(CreateBusinessScreen), findsOneWidget);
    expect(find.text('MI NEGOCIO'), findsOneWidget);
    expect(find.text('Nombre del negocio'), findsOneWidget);
    expect(find.text('Teléfono de atención'), findsOneWidget);
    expect(find.text('Cédula propietario ó RUC'), findsOneWidget);
    expect(find.text('Dirección'), findsOneWidget);
  });

  testWidgets('no avanza al paso 2 si faltan datos obligatorios', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: spanishApp(const CreateBusinessScreen()),
      ),
    );

    await tester.tap(find.byTooltip('Continuar con la campaña'));
    await tester.pump();

    expect(find.text('MI NEGOCIO'), findsOneWidget);
    expect(find.text('MI CAMPAÑA'), findsNothing);
    expect(find.text('Ingresa el nombre de tu negocio'), findsOneWidget);
    expect(find.text('Ingresa un teléfono de atención'), findsOneWidget);
    expect(find.text('Ingresa tu cédula o RUC'), findsOneWidget);
    expect(find.text('Selecciona la ubicación en el mapa'), findsOneWidget);
  });
}
