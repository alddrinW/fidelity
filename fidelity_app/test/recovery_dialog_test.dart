import 'package:fidelity_app/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> openRecovery(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(child: spanishApp(const LoginScreen())));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();
  }

  testWidgets('el primer paso pide solo el correo', (tester) async {
    await openRecovery(tester);

    expect(find.text('RECUPERAR CONTRASEÑA'), findsOneWidget);
    expect(find.text('Te enviaremos un código para crear una nueva contraseña.'), findsOneWidget);
    expect(find.text('ENVIAR CÓDIGO'), findsOneWidget);
    expect(find.text('Código de 6 dígitos'), findsNothing);
    expect(find.text('Nueva contraseña'), findsNothing);
  });

  testWidgets('un correo inválido no envía el código', (tester) async {
    await openRecovery(tester);

    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
      'no-es-correo',
    );
    await tester.tap(find.text('ENVIAR CÓDIGO'));
    await tester.pumpAndSettle();

    expect(find.text('Email inválido'), findsOneWidget);
    expect(find.text('Código de 6 dígitos'), findsNothing);
  });
}
