import 'package:fidelity_app/features/admin/admin_payment_detail_screen.dart';
import 'package:fidelity_app/features/payments/data/payments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

/// Datos de prueba en lugar de la red.
class _FakePaymentsRepository extends PaymentsRepository {
  final PaymentOrder order;
  final List<String> validated = [];
  final List<String> rejected = [];

  _FakePaymentsRepository(this.order);

  @override
  Future<PaymentOrder> getOne(String paymentId) async => order;

  @override
  Future<void> validate(String paymentId) async => validated.add(paymentId);

  @override
  Future<void> reject(String paymentId, String reason) async => rejected.add(paymentId);
}

// Un PNG de 1x1 píxel.
const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Map<String, dynamic> _json({
  String status = 'reported',
  String? method = 'transfer',
  String? proof = _png,
  Map<String, dynamic>? business,
}) =>
    {
      'id': 'p1',
      'businessId': 'b1',
      'concept': 'registration',
      'amount': 20,
      'currency': 'USD',
      'status': status,
      'reference': 'FID-ABC234',
      'method': method,
      'note': '8842',
      'proofUrl': proof,
      'hasProof': proof != null,
      'createdAt': '2026-10-14T15:00:00.000Z',
      'reportedAt': '2026-10-14T16:00:00.000Z',
      'business': business ??
          {
            'id': 'b1',
            'name': 'Café Aurora',
            'isActive': false,
            'description': 'Cafetería de especialidad',
            'phone': '0991234567',
            'taxId': '1790012345001',
            'address': 'Av. Amazonas y Colón, Quito',
            'latitude': '-0.1807',
            'longitude': '-78.4678',
            'rewardDescription': 'Café gratis',
            'pointsRequired': 10,
            'createdAt': '2026-10-13T12:00:00.000Z',
            'categoryRef': {'name': 'Cafeterías & Panaderías'},
          },
      'owner': {
        'fullName': 'Ana Torres',
        'email': 'ana@mail.com',
        'phone': '0987654321',
      },
    };

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<_FakePaymentsRepository> open(
    WidgetTester tester,
    Map<String, dynamic> json,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = _FakePaymentsRepository(PaymentOrder.fromJson(json));
    await tester.pumpWidget(
      spanishApp(AdminPaymentDetailScreen(paymentId: 'p1', repository: repository)),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  group('PaymentOrder con negocio y dueño', () {
    test('lee todos los datos del negocio', () {
      final order = PaymentOrder.fromJson(_json());
      final business = order.businessInfo!;

      expect(business.name, 'Café Aurora');
      expect(business.category, 'Cafeterías & Panaderías');
      expect(business.taxId, '1790012345001');
      expect(business.latitude, -0.1807);
      expect(business.hasLocation, isTrue);
      expect(business.pointsRequired, 10);
      expect(business.isActive, isFalse);
      expect(order.ownerInfo?.displayName, 'Ana Torres');
      expect(order.hasProof, isTrue);
    });

    test('los datos vacíos se tratan como ausentes', () {
      final order = PaymentOrder.fromJson(_json(
        business: {'id': 'b1', 'name': 'X', 'phone': '  ', 'address': '', 'isActive': true},
        proof: null,
      ));

      expect(order.businessInfo?.phone, isNull);
      expect(order.businessInfo?.address, isNull);
      expect(order.businessInfo?.hasLocation, isFalse);
      expect(order.hasProof, isFalse);
    });

    test('un dueño sin nombre se muestra por su correo', () {
      expect(PaymentOwner.fromJson({'fullName': ' ', 'email': 'x@mail.com'}).displayName, 'x@mail.com');
    });
  });

  testWidgets('muestra el comprobante, el negocio y el dueño', (tester) async {
    await open(tester, _json());

    // Pago
    expect(find.text('\$20.00 USD'), findsOneWidget);
    expect(find.text('FID-ABC234'), findsOneWidget);
    expect(find.text('N.º 8842'), findsOneWidget);
    // Comprobante
    expect(find.text('COMPROBANTE DE PAGO'), findsOneWidget);
    expect(find.text('Toca la foto para verla ampliada.'), findsOneWidget);
    // Negocio
    expect(find.text('CAFÉ AURORA'), findsOneWidget);
    expect(find.text('Cafeterías & Panaderías'.toUpperCase()), findsOneWidget);
    expect(find.text('Cafetería de especialidad'), findsOneWidget);
    expect(find.text('0991234567'), findsOneWidget);
    expect(find.text('1790012345001'), findsOneWidget);
    expect(find.text('Av. Amazonas y Colón, Quito'), findsOneWidget);
    expect(find.text('Café gratis · 10 pts'), findsOneWidget);
    expect(find.text('VER EN EL MAPA'), findsOneWidget);
    // Dueño
    expect(find.text('Ana Torres'), findsOneWidget);
    expect(find.text('ana@mail.com'), findsOneWidget);
    expect(find.text('0987654321'), findsOneWidget);
  });

  testWidgets('un pago con tarjeta explica que no lleva foto', (tester) async {
    await open(tester, _json(method: 'card', proof: null));

    expect(find.text('Pago con tarjeta: no lleva foto de comprobante.'), findsOneWidget);
    expect(find.text('Toca la foto para verla ampliada.'), findsNothing);
  });

  testWidgets('un pago sin reportar avisa que el dueño aún no pagó', (tester) async {
    await open(tester, _json(status: 'pending', method: null, proof: null));

    expect(find.text('El dueño todavía no reportó su pago.'), findsOneWidget);
  });

  testWidgets('un pago por revisar ofrece validar y rechazar', (tester) async {
    await open(tester, _json());

    expect(find.text('VALIDAR PAGO'), findsOneWidget);
    expect(find.text('RECHAZAR'), findsOneWidget);
  });

  testWidgets('un pago ya validado no ofrece acciones', (tester) async {
    await open(tester, _json(status: 'paid'));

    expect(find.text('VALIDAR PAGO'), findsNothing);
    expect(find.text('RECHAZAR'), findsNothing);
  });

  testWidgets('validar pide confirmación y valida el pago', (tester) async {
    final repository = await open(tester, _json());

    await tester.tap(find.text('VALIDAR PAGO'));
    await tester.pumpAndSettle();
    expect(find.text('¿VALIDAR PAGO?'), findsOneWidget);

    await tester.tap(find.text('SÍ, VALIDAR'));
    await tester.pumpAndSettle();

    expect(repository.validated, ['p1']);
    // Deja correr el aviso temporal que muestra la pantalla.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('cancelar la confirmación no valida nada', (tester) async {
    final repository = await open(tester, _json());

    await tester.tap(find.text('VALIDAR PAGO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();

    expect(repository.validated, isEmpty);
  });

  testWidgets('rechazar exige un motivo', (tester) async {
    final repository = await open(tester, _json());

    await tester.tap(find.text('RECHAZAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'RECHAZAR'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe el motivo'), findsOneWidget);
    expect(repository.rejected, isEmpty);

    await tester.enterText(find.byType(TextFormField), 'No vemos el depósito');
    await tester.tap(find.widgetWithText(ElevatedButton, 'RECHAZAR'));
    await tester.pumpAndSettle();

    expect(repository.rejected, ['p1']);
    await tester.pump(const Duration(seconds: 5));
  });
}
