import 'package:fidelity_app/core/theme/app_colors.dart';
import 'package:fidelity_app/features/business/branches/branches_repository.dart';
import 'package:fidelity_app/features/business/branches/my_businesses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

const _list = [
  BusinessOverview(id: 'a', name: 'Vilcanatu', isActive: true, customers: 1, approvers: 1),
  BusinessOverview(id: 'b', name: 'Vilcanatu - Centro', isActive: true, parentId: 'a', customers: 1),
  BusinessOverview(id: 'c', name: 'Vilcanatu - Norte', isActive: false, parentId: 'a', pendingScans: 12),
];

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> open(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [businessOverviewProvider.overrideWith((ref) async => _list)],
        child: spanishApp(const MyBusinessesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra cada local con sus cifras y acciones', (tester) async {
    await open(tester);

    expect(find.text('MIS NEGOCIOS'), findsOneWidget);
    expect(find.text('VILCANATU'), findsOneWidget);
    expect(find.text('SUCURSALES'), findsOneWidget);
    expect(find.text('MI EQUIPO'), findsWidgets);
    expect(find.text('EDITAR'), findsWidgets);
    expect(find.text('AGREGAR SUCURSAL'), findsOneWidget);
  });

  testWidgets('el negocio principal va en una tarjeta negra y sus sucursales cuelgan de él', (tester) async {
    await open(tester);

    // La tarjeta negra del principal (con las cifras en rosa).
    final hero = find.ancestor(
      of: find.text('VILCANATU'),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == AppColors.black,
      ),
    );
    expect(hero, findsOneWidget);

    // Las sucursales van debajo del principal, con su contador (2).
    expect(find.text('2'), findsWidgets);
    final principalTop = tester.getTopLeft(find.text('VILCANATU')).dy;
    expect(tester.getTopLeft(find.text('SUCURSALES')).dy, greaterThan(principalTop));
    expect(tester.getTopLeft(find.text('VILCANATU - CENTRO')).dy, greaterThan(tester.getTopLeft(find.text('SUCURSALES')).dy));
    expect(find.text('VILCANATU - NORTE'), findsOneWidget);
  });

  testWidgets('las acciones de una sucursal son íconos con su nombre, y el botón principal sigue siendo "Usar este negocio"', (tester) async {
    await open(tester);

    expect(find.byTooltip('Mi equipo'), findsNWidgets(2)); // Centro y Norte (el principal lleva el texto)
    expect(find.byTooltip('Editar'), findsNWidgets(2));
    expect(find.text('USAR ESTE NEGOCIO'), findsWidgets);
  });

  testWidgets('una sucursal sin principal en la lista sale suelta, sin el encabezado', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessOverviewProvider.overrideWith(
            (ref) async => [const BusinessOverview(id: 'x', name: 'Huérfana', isActive: true, parentId: 'no-esta')],
          ),
        ],
        child: spanishApp(const MyBusinessesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HUÉRFANA'), findsOneWidget);
    expect(find.text('SUCURSALES'), findsNothing);
  });

  testWidgets('"Pendientes" se queda en una sola línea aunque la pantalla sea angosta', (tester) async {
    await open(tester, size: const Size(320, 800));

    final label = find.text('PENDIENTES').first;
    final height = tester.getSize(label).height;
    // Una línea de letra de 10 puntos mide bien menos que dos.
    expect(height, lessThan(22));
    expect(tester.takeException(), isNull);
  });

  testWidgets('un local sin activar ofrece pagar, no usarlo', (tester) async {
    await open(tester);
    await tester.scrollUntilVisible(find.text('PAGA YA'), 200, scrollable: find.byType(Scrollable).first);

    expect(find.text('PAGA YA'), findsOneWidget);
  });
}
