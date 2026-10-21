import 'package:fidelity_app/features/help/faqs_screen.dart';
import 'package:fidelity_app/features/profile/providers/user_profile_provider.dart';
import 'package:fidelity_app/features/profile/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

/// El perfil del cliente, sin red.
class _FakeProfile extends UserProfileNotifier {
  @override
  UserProfileState build() => UserProfileState(
        isLoading: false,
        fullName: 'juan diego',
        phone: '0999994555',
        email: 'juan@uide.edu.ec',
      );
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('el perfil solo deja las cuentas en las preguntas frecuentes',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [userProfileProvider.overrideWith(() => _FakeProfile())],
      child: spanishApp(const Scaffold(body: UserProfileView())),
    ));
    await tester.pumpAndSettle();

    // Los botones ya no están en el perfil.
    expect(find.text('Cerrar sesión'), findsNothing);
    expect(find.text('Eliminar mi cuenta'), findsNothing);
    expect(find.text('¿Necesitas cerrar sesión o eliminar tu cuenta?'), findsOneWidget);
    // Pero sí se llega a las preguntas frecuentes.
    expect(find.text('Preguntas frecuentes'), findsOneWidget);
  });

  testWidgets('las preguntas frecuentes explican cómo cerrar sesión y eliminar la cuenta',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(spanishApp(const FaqsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('¿Cómo cierro mi sesión?'), findsOneWidget);
    expect(find.text('¿Cómo elimino mi cuenta?'), findsOneWidget);

    // Al abrir "¿Cómo cierro mi sesión?" aparece el botón.
    await tester.tap(find.text('¿Cómo cierro mi sesión?'));
    await tester.pumpAndSettle();
    expect(find.text('CERRAR SESIÓN'), findsOneWidget);
    expect(find.text('ELIMINAR MI CUENTA'), findsNothing);

    // Y al abrir "¿Cómo elimino mi cuenta?" aparece el suyo.
    await tester.scrollUntilVisible(
      find.text('¿Cómo elimino mi cuenta?'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('¿Cómo elimino mi cuenta?'));
    await tester.pumpAndSettle();
    expect(find.text('ELIMINAR MI CUENTA'), findsOneWidget);
  });
}
