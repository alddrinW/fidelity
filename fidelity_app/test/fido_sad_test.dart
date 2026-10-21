import 'package:fidelity_app/core/widgets/app_empty_state.dart';
import 'package:fidelity_app/core/widgets/fido_mascot.dart';
import 'package:fidelity_app/core/widgets/fido_says.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'spanish_app.dart';

/// El Fido triste (la imagen que lleva "Fido triste" como etiqueta).
Finder sadFido() => find.byWidgetPredicate(
      (w) => w is Image && w.semanticLabel == 'Fido triste',
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Fido triste usa su propia imagen', (tester) async {
    await tester.pumpWidget(spanishApp(
      const Scaffold(body: Center(child: FidoMascot(mood: FidoMood.sad, height: 120))),
    ));
    await tester.pump(const Duration(seconds: 1));

    final image = tester.widget<Image>(sadFido());
    expect((image.image as AssetImage).assetName, 'assets/images/fido_triste.png');
  });

  testWidgets('con "reducir movimiento" Fido triste se queda quieto', (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: spanishApp(
        const Scaffold(body: Center(child: FidoMascot(mood: FidoMood.sad, height: 120))),
      ),
    ));
    await tester.pump();

    expect(sadFido(), findsOneWidget);
  });

  testWidgets('un error se muestra con Fido triste y el título de siempre', (tester) async {
    await tester.pumpWidget(spanishApp(
      const Scaffold(body: AppEmptyState.error(message: 'No pudimos cargar tus regalos.')),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('ALGO SALIÓ MAL'), findsOneWidget);
    expect(find.text('No pudimos cargar tus regalos.'), findsOneWidget);
    expect(sadFido(), findsOneWidget);
  });

  testWidgets('un estado vacío normal no lleva a Fido triste', (tester) async {
    await tester.pumpWidget(spanishApp(
      const Scaffold(body: AppEmptyState(title: 'Sin regalos', message: 'Aquí aparecerán tus regalos.')),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(sadFido(), findsNothing);
  });

  testWidgets('un estado vacío puede pedir a Fido triste (p. ej. un reto vencido)', (tester) async {
    await tester.pumpWidget(spanishApp(
      const Scaffold(
        body: AppEmptyState(title: 'Reto vencido', message: 'Ya no está disponible.', mood: FidoMood.sad),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(sadFido(), findsOneWidget);
  });

  testWidgets('Fido con globo: triste, celebrando o tranquilo', (tester) async {
    Future<void> show(Widget fido) async {
      await tester.pumpWidget(spanishApp(Scaffold(body: Center(child: fido))));
      await tester.pump(const Duration(seconds: 1));
    }

    await show(const FidoSays(sad: true, message: 'No pudimos cargar tus minijuegos.'));
    expect(sadFido(), findsOneWidget);

    await show(const FidoSays(celebrating: true, message: '¡Listo!'));
    expect(sadFido(), findsNothing);

    await show(const FidoSays(message: 'Hola'));
    expect(sadFido(), findsNothing);
  });
}
