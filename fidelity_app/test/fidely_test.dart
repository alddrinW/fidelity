import 'package:fidelity_app/core/l10n/translator.dart';
import 'package:fidelity_app/core/widgets/fidely_badge.dart';
import 'package:fidelity_app/features/business/dashboard/providers/dashboard_provider.dart';
import 'package:fidelity_app/features/business/dashboard/widgets/tabs/tab_customers.dart';
import 'package:fidelity_app/features/cards/card_history_screen.dart';
import 'package:fidelity_app/features/cards/providers/card_history_provider.dart';
import 'package:fidelity_app/features/cards/widgets/registered_scans_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'spanish_app.dart';

/// El historial de la tarjeta de un cliente, con su avance de FidelyUsuario.
class _FakeHistory extends CardHistoryNotifier {
  final int verified;
  final bool isFidely;
  final int required;

  _FakeHistory({this.verified = 0, this.isFidely = false, this.required = 3});

  @override
  void init(String cardId, String businessId) {}

  @override
  Future<void> loadHistory() async {}

  @override
  CardHistoryState build() => CardHistoryState(
        isLoading: false,
        card: {
          'name': 'Vilcanatu',
          'reward_description': 'Café gratis',
          'current_points': 1,
          'total_points': 1,
          'rewards_claimed': 0,
          'points_required': 10,
          'verified_scans': verified,
          'fidely_required': required,
          'is_fidely': isFidely,
        },
      );
}

/// El directorio de clientes del dueño.
class _FakeDashboard extends DashboardNotifier {
  @override
  DashboardState build() => DashboardState(
        isLoading: false,
        business: {'id': 'b1', 'name': 'Vilcanatu', 'points_required': 10},
        customers: [
          _customer('u1', 'Ana Pérez', fidely: true, scans: 5),
          _customer('u2', 'Luis Mora', scans: 1),
          _customer('u3', 'Zoe Ríos', fidely: true, scans: 3),
        ],
        pendingScans: const [],
        pendingRewards: const [],
      );
}

Map<String, dynamic> _customer(String id, String name, {bool fidely = false, int scans = 0}) => {
      'id': 'c-$id',
      'user_id': id,
      'business_id': 'b1',
      'current_points': 2,
      'total_points_lifetime': 4,
      'rewards_claimed': 0,
      'profiles': {'id': id, 'full_name': name, 'avatar_url': null, 'is_demo': false},
      'verified_scans': scans,
      'fidely_required': 3,
      'is_fidely': fidely,
    };

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('FidelyInfo', () {
    test('lee lo que trae el servidor', () {
      final info = FidelyInfo.fromMap({'verified_scans': 2, 'fidely_required': 3, 'is_fidely': false});

      expect(info.verifiedScans, 2);
      expect(info.required, 3);
      expect(info.isFidely, isFalse);
      expect(info.missing, 1);
    });

    test('sin datos: 3 escaneos y todavía no lo es', () {
      final info = FidelyInfo.fromMap(null);

      expect(info.verifiedScans, 0);
      expect(info.required, 3);
      expect(info.missing, 3);
    });

    test('quien ya lo es no tiene escaneos pendientes, y nunca sale un número negativo', () {
      expect(const FidelyInfo(verifiedScans: 7, isFidely: true).missing, 0);
      expect(const FidelyInfo(verifiedScans: 9).missing, 0);
    });

    test('con otra cantidad que fije el administrador', () {
      expect(const FidelyInfo(verifiedScans: 2, required: 5).missing, 3);
    });
  });

  group('lo que ve el cliente al entrar al local', () {
    Future<void> open(WidgetTester tester, CardHistoryNotifier Function() history) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [cardHistoryProvider.overrideWith(history)],
          child: spanishApp(
            const CardHistoryScreen(loyaltyCardId: 'c1', businessId: 'b1', businessName: 'Vilcanatu'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('con el 3.er escaneo ya es FidelyUsuario: ve su insignia y por qué', (tester) async {
      await open(tester, () => _FakeHistory(verified: 3, isFidely: true));

      expect(find.text('FIDELYUSUARIO'), findsOneWidget);
      expect(find.text('Por tu fidelidad a Vilcanatu'), findsOneWidget);
      expect(find.textContaining('para ser FidelyUsuario'), findsNothing);
    });

    testWidgets('si aún no, ve cuánto le falta', (tester) async {
      await open(tester, () => _FakeHistory(verified: 1));

      expect(find.text('Te faltan 2 escaneos para ser FidelyUsuario'), findsOneWidget);
      expect(find.text('FIDELYUSUARIO'), findsNothing);
    });

    testWidgets('con un escaneo para lograrlo, lo dice en singular', (tester) async {
      await open(tester, () => _FakeHistory(verified: 2));

      expect(find.text('Te falta 1 escaneo para ser FidelyUsuario'), findsOneWidget);
    });

    testWidgets('recién llegado: le faltan los 3', (tester) async {
      await open(tester, () => _FakeHistory());

      expect(find.text('Te faltan 3 escaneos para ser FidelyUsuario'), findsOneWidget);
    });

    testWidgets('la cantidad la fija el administrador (con 5, le faltan 3 si lleva 2)', (tester) async {
      await open(tester, () => _FakeHistory(verified: 2, required: 5));

      expect(find.text('Te faltan 3 escaneos para ser FidelyUsuario'), findsOneWidget);
    });

    test('se traduce al inglés', () {
      expect(Translator.english.toEnglish('Te faltan 2 escaneos para ser FidelyUsuario'), 'You need 2 more scans to become a FidelyUsuario');
      expect(Translator.english.toEnglish('Te falta 1 escaneo para ser FidelyUsuario'), 'You need 1 more scan to become a FidelyUsuario');
      expect(Translator.english.toEnglish('Por tu fidelidad a Vilcanatu'), 'For your loyalty to Vilcanatu');
    });
  });

  group('en la lista de locales del cliente', () {
    testWidgets('el local donde ya es FidelyUsuario lleva la insignia; los demás no', (tester) async {
      final cards = [
        {
          'id': 'c1',
          'current_points': 1,
          'is_fidely': true,
          'businesses': {'name': 'Vilcanatu', 'points_required': 10},
        },
        {
          'id': 'c2',
          'current_points': 2,
          'is_fidely': false,
          'businesses': {'name': 'Café Aurora', 'points_required': 10},
        },
      ];
      await tester.pumpWidget(
        spanishApp(Scaffold(body: SingleChildScrollView(child: RegisteredScansList(cards: cards, onOpen: (_) {})))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FidelyBadge), findsOneWidget);
      expect(find.text('FIDELYUSUARIO'), findsOneWidget);
    });
  });

  group('lo que ve el dueño en sus clientes', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dashboardProvider.overrideWith(() => _FakeDashboard())],
          child: spanishApp(const Scaffold(body: TabCustomers())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('cada FidelyUsuario lleva su insignia en la lista', (tester) async {
      await open(tester);

      expect(find.text('ANA PÉREZ'), findsOneWidget);
      expect(find.text('LUIS MORA'), findsOneWidget);
      // Ana y Zoe son fieles; Luis todavía no.
      expect(find.byType(FidelyBadge), findsNWidgets(2));
    });

    testWidgets('el filtro muestra cuántos son y deja ver solo a los FidelyUsuarios', (tester) async {
      await open(tester);
      expect(find.text('TODOS (3)'), findsOneWidget);
      expect(find.text('FIDELYUSUARIOS (2)'), findsOneWidget);

      await tester.tap(find.text('FIDELYUSUARIOS (2)'));
      await tester.pumpAndSettle();

      expect(find.text('ANA PÉREZ'), findsOneWidget);
      expect(find.text('ZOE RÍOS'), findsOneWidget);
      expect(find.text('LUIS MORA'), findsNothing);

      await tester.tap(find.text('TODOS (3)'));
      await tester.pumpAndSettle();
      expect(find.text('LUIS MORA'), findsOneWidget);
    });

    testWidgets('el filtro se junta con la búsqueda por nombre', (tester) async {
      await open(tester);
      await tester.tap(find.text('FIDELYUSUARIOS (2)'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zoe');
      await tester.pumpAndSettle();

      expect(find.text('ZOE RÍOS'), findsOneWidget);
      expect(find.text('ANA PÉREZ'), findsNothing);
    });

    testWidgets('sin ningún FidelyUsuario no aparece el filtro', (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dashboardProvider.overrideWith(() => _NoFidelyDashboard())],
          child: spanishApp(const Scaffold(body: TabCustomers())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FidelyBadge), findsNothing);
      expect(find.textContaining('FIDELYUSUARIOS'), findsNothing);
    });
  });
}

class _NoFidelyDashboard extends DashboardNotifier {
  @override
  DashboardState build() => DashboardState(
        isLoading: false,
        business: {'id': 'b1', 'name': 'Vilcanatu', 'points_required': 10},
        customers: [_customer('u2', 'Luis Mora', scans: 1)],
        pendingScans: const [],
        pendingRewards: const [],
      );
}
