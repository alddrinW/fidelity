// ignore_for_file: depend_on_referenced_packages
import 'package:fidelity_app/features/business/qr_management/qr_management_screen.dart';
import 'package:fidelity_app/features/business/qr_management/qr_poster.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

const _business = {
  'id': 'b1',
  'name': 'Café Aurora',
  'pointsRequired': 10,
  'rewardDescription': 'café gratis',
};

List<Map<String, dynamic>> _codes([int n = 1]) => [
      for (var i = 0; i < n; i++)
        {'id': 'q$i', 'business_id': 'b1', 'qr_code': 'codigo-$i', 'label': 'Código ${i + 1}', 'is_active': true},
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Sin red en los tests: no intentar descargar las fuentes.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> open(
    WidgetTester tester, {
    Map<String, dynamic>? business = _business,
    List<Map<String, dynamic>>? codes,
    Locale locale = const Locale('es'),
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: QRManagementScreen(
          businessId: 'b1',
          business: business,
          codesLoader: codes == null ? null : () async => codes,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

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

  group('el cartel del código', () {
    testWidgets('muestra el logo, el nombre, el código y lo que se gana, sobre fondo rosa', (tester) async {
      await open(tester, codes: _codes());

      expect(find.text('MI CÓDIGO'), findsOneWidget);
      expect(find.text('CAFÉ AURORA'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('ESCANEA Y'), findsOneWidget);
      expect(find.text('SUMA PUNTOS'), findsOneWidget);
      expect(find.text('10 puntos = café gratis'), findsOneWidget);
      // El código que se dibuja es el del local.
      expect(tester.widget<QrPosterCard>(find.byType(QrPosterCard)).code, 'codigo-0');
      // Toda la pantalla es rosa.
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, const Color(0xFFFEBFDC));
    });

    testWidgets('tiene las tres acciones: imprimir cartel, compartir y descargar', (tester) async {
      await open(tester, codes: _codes());

      expect(find.text('Imprimir cartel'), findsOneWidget);
      expect(find.text('Compartir'), findsOneWidget);
      expect(find.text('Descargar'), findsOneWidget);
      expect(find.byIcon(Icons.print_outlined), findsOneWidget);
    });

    testWidgets('sin los puntos y el premio del local, dice que cada visita suma puntos', (tester) async {
      await open(tester, business: {'name': 'Café Aurora'}, codes: _codes());

      expect(find.text('Cada visita suma puntos'), findsOneWidget);
    });

    testWidgets('con más de un código, se elige cuál se ve', (tester) async {
      await open(tester, codes: _codes(2));

      expect(find.text('Código 1'), findsOneWidget);
      expect(find.text('Código 2'), findsOneWidget);
      expect(tester.widget<QrPosterCard>(find.byType(QrPosterCard)).code, 'codigo-0');

      await tester.tap(find.text('Código 2'));
      await tester.pumpAndSettle();
      expect(tester.widget<QrPosterCard>(find.byType(QrPosterCard)).code, 'codigo-1');
    });

    testWidgets('con un solo código no hay selector', (tester) async {
      await open(tester, codes: _codes());

      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('un código dañado ofrece regenerarlo, sin cartel', (tester) async {
      await open(tester, codes: [
        {'id': 'q0', 'qr_code': '', 'label': 'Código QR Único'},
      ]);

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('CÓDIGO DAÑADO'), findsOneWidget);
      expect(find.text('REGENERAR QR'), findsOneWidget);
    });

    testWidgets('regenerar pide confirmar y avisa que hay que volver a imprimir', (tester) async {
      await open(tester, codes: _codes());

      await tester.tap(find.text('Regenerar código'));
      await tester.pumpAndSettle();

      expect(find.text('REGENERAR QR'), findsOneWidget);
      expect(find.textContaining('volver a imprimir tu cartel'), findsOneWidget);
    });

    testWidgets('en inglés sale traducido', (tester) async {
      await open(tester, codes: _codes(), locale: const Locale('en'));

      expect(find.text('MY CODE'), findsOneWidget);
      expect(find.text('SCAN AND'), findsOneWidget);
      expect(find.text('EARN POINTS'), findsOneWidget);
      expect(find.text('10 points = café gratis'), findsOneWidget);
      expect(find.text('Print poster'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });
  });

  group('qrPointsLine', () {
    test('une los puntos y el premio', () {
      expect(qrPointsLine(_business), '10 puntos = café gratis');
      expect(qrPointsLine({'points_required': 5, 'reward_description': ' Un postre '}), '5 puntos = Un postre');
    });

    test('sin puntos o sin premio no hay línea', () {
      expect(qrPointsLine(null), isNull);
      expect(qrPointsLine({'pointsRequired': 10}), isNull);
      expect(qrPointsLine({'rewardDescription': 'café'}), isNull);
      expect(qrPointsLine({'pointsRequired': 0, 'rewardDescription': 'café'}), isNull);
      expect(qrPointsLine({'pointsRequired': 10, 'rewardDescription': '  '}), isNull);
    });
  });

  group('el cartel para imprimir (PDF)', () {
    test('se genera un PDF de una página con el código', () async {
      final bytes = await buildQrPosterPdf(
        code: 'codigo-0',
        name: 'Café Aurora',
        pointsLine: '10 puntos = café gratis',
      );

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });

    test('con logo en base64 y sin datos extra también se genera', () async {
      const png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
      final bytes = await buildQrPosterPdf(code: 'x', name: 'Ñandú', logoUrl: png);

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('un logo que no se puede leer no rompe el cartel', () async {
      final bytes = await buildQrPosterPdf(code: 'x', name: 'Local', logoUrl: 'data:image/png;base64,no-es-una-imagen');

      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
