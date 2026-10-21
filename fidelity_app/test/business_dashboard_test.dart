import 'package:fidelity_app/features/business/dashboard/business_dashboard_screen.dart';
import 'package:fidelity_app/features/business/dashboard/providers/dashboard_provider.dart';
import 'package:fidelity_app/features/business/dashboard/widgets/client_detail_screen.dart';
import 'package:fidelity_app/features/business/rewards/providers/rewards_management_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'spanish_app.dart';

class _FakeDashboard extends DashboardNotifier {
  @override
  DashboardState build() => DashboardState(
        isLoading: false,
        business: {
          'id': 'b1',
          'name': 'Vilcanatu',
          'logo_url': null,
          'points_required': 10,
        },
        ownerName: 'aurora zhuma',
        customers: const [
          {
            'user_id': 'u1',
            'current_points': 1,
            'total_points_lifetime': 1,
            'rewards_claimed': 0,
            'profiles': {'full_name': 'Juan Diego'},
          },
        ],
        pendingScans: const [],
        pendingRewards: const [],
      );
}

class _FakeRewards extends RewardsManagementNotifier {
  @override
  RewardsManagementState build() => RewardsManagementState(
        isLoading: false,
        businessId: 'b1',
        rewards: const [
          {
            'id': 'r1',
            'user_id': 'u1',
            'status': 'pending',
            'description': 'Café gratis',
            'earned_at': '2026-10-19T15:27:16.832Z',
            'display_name': 'Juan Diego',
          },
        ],
      );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget panel(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    return ProviderScope(
      overrides: [
        dashboardProvider.overrideWith(() => _FakeDashboard()),
        rewardsManagementProvider.overrideWith(() => _FakeRewards()),
      ],
      child: spanishApp(const BusinessDashboardScreen()),
    );
  }

  testWidgets('el dueño ve solo tres pestañas', (tester) async {
    await tester.pumpWidget(panel(tester));
    await tester.pumpAndSettle();

    expect(find.text('CLIENTES'), findsOneWidget);
    expect(find.text('PENDIENTES'), findsOneWidget);
    expect(find.text('MÉTRICAS'), findsOneWidget);

    // Los premios están dentro de cada cliente, y el QR, las gift cards y las
    // campañas quedan detrás del botón "+".
    expect(find.text('PREMIOS'), findsNothing);
    expect(find.text('QR'), findsNothing);
    expect(find.text('GIFT CARDS'), findsNothing);
    expect(find.text('CAMPAÑAS'), findsNothing);
  });

  testWidgets('el botón "+" abre el QR, las gift cards y las campañas', (tester) async {
    await tester.pumpWidget(panel(tester));
    await tester.pumpAndSettle();

    // El botón "+" de la esquina (el grande, de la marca).
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.add_rounded && w.size == 30,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CREAR Y GESTIONAR'), findsOneWidget);
    expect(find.text('Mi código QR'), findsOneWidget);
    expect(find.text('Gift cards'), findsOneWidget);
    expect(find.text('Campañas'), findsOneWidget);
  });

  testWidgets('la sección del QR se abre con su propio encabezado', (tester) async {
    await tester.pumpWidget(panel(tester));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.add_rounded && w.size == 30,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mi código QR'));
    await tester.pumpAndSettle();

    // La pantalla tiene su título y su botón de volver.
    expect(find.text('MI CÓDIGO QR'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
  });

  testWidgets('tocar un cliente abre su ficha con sus premios', (tester) async {
    await tester.pumpWidget(panel(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('JUAN DIEGO'));
    await tester.pumpAndSettle();

    expect(find.byType(ClientDetailScreen), findsOneWidget);
    expect(find.text('Café gratis'), findsOneWidget);
    expect(find.text('ENTREGAR'), findsOneWidget);
  });
}
