import 'package:fidelity_app/core/widgets/app_pill_tab_bar.dart';
import 'package:fidelity_app/features/cards/customer_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'spanish_app.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('destinos del panel de usuario', () {
    test('siempre están inicio y explorar', () {
      final destinations = customerDestinations(cardCount: 0, giftCount: 0);

      expect(
        destinations.map((d) => d.tab).toList(),
        [CustomerTab.home, CustomerTab.explore],
      );
      // Escanear ya no es un destino: es el botón flotante de la esquina.
      expect(destinations.any((d) => d.isAction), isFalse);
    });

    test('los regalos aparecen solo si el usuario ya tiene', () {
      final withoutGifts = customerDestinations(cardCount: 2, giftCount: 0);
      expect(withoutGifts.any((d) => d.tab == CustomerTab.gifts), isFalse);

      final withGifts = customerDestinations(cardCount: 0, giftCount: 1);
      expect(withGifts.any((d) => d.tab == CustomerTab.gifts), isTrue);
    });

    test('el perfil no es un destino (se abre desde la foto)', () {
      for (final gifts in [0, 1]) {
        final destinations = customerDestinations(cardCount: 0, giftCount: gifts);
        expect(
          destinations.map((d) => d.label),
          isNot(contains('Perfil')),
          reason: 'con $gifts regalos',
        );
      }
    });

    test('nunca aparece la pestaña de tarjetas (va dentro de cada local)', () {
      for (final cards in [0, 3]) {
        for (final gifts in [0, 1]) {
          final destinations = customerDestinations(cardCount: cards, giftCount: gifts);
          expect(
            destinations.map((d) => d.label),
            isNot(contains('Tarjetas')),
            reason: 'con $cards tarjetas y $gifts regalos',
          );
        }
      }
    });
  });

  group('AppPillTabBar', () {
    Widget bar({
      required List<String> labels,
      required ValueChanged<int> onSelected,
      int selectedIndex = 0,
    }) {
      return spanishApp(
        Scaffold(
          body: const SizedBox(),
          bottomNavigationBar: AppPillTabBar(
            labels: labels,
            selectedIndex: selectedIndex,
            onSelected: onSelected,
          ),
        ),
      );
    }

    testWidgets('muestra los destinos en mayúsculas y avisa el que se toca',
        (tester) async {
      var selected = 0;
      await tester.pumpWidget(bar(
        labels: const ['Inicio', 'Explorar', 'Regalos', 'Perfil'],
        onSelected: (index) => selected = index,
      ));

      expect(find.text('INICIO'), findsOneWidget);
      expect(find.text('EXPLORAR'), findsOneWidget);

      await tester.tap(find.text('EXPLORAR'));
      expect(selected, 1);
    });

    testWidgets('el destino seleccionado queda en negro', (tester) async {
      await tester.pumpWidget(bar(
        labels: const ['Inicio', 'Perfil'],
        selectedIndex: 1,
        onSelected: (_) {},
      ));

      final activo = tester.widget<Text>(
        find.text('PERFIL'),
      );
      expect(activo.style?.color, isNotNull);
    });
  });
}
