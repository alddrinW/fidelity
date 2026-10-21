import 'package:fidelity_app/core/widgets/app_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'spanish_app.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('con dos botones a la derecha la cabecera no se desborda', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(spanishApp(
      Scaffold(
        body: AppPageHeader(
          title: 'Administración',
          trailingWidth: 96,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.logout_rounded)),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Un desborde de la fila haría fallar el test con "RIGHT OVERFLOWED".
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
  });
}
