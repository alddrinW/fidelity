import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/l10n/app_language.dart';
import 'core/theme/app_theme.dart';
import 'core/services/api_client.dart';
import 'features/auth/auth_wrapper.dart';
import 'features/splash/fidelity_intro.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar cliente HTTP de NestJS con sesión previa
  await ApiClient().init();

  // Inicializar Firebase (Solo en plataformas soportadas)
  if (kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase ya inicializado o no configurado en este entorno: $e');
    }
  }

  // Idioma elegido en la última sesión (español por defecto).
  final language = await LanguageStore.load();

  runApp(ProviderScope(
    overrides: [initialLanguageProvider.overrideWithValue(language)],
    child: const FidelityApp(),
  ));
}

class FidelityApp extends ConsumerWidget {
  /// Si se muestra la animación de entrada (Fido escaneando) al abrir la app.
  final bool playIntro;

  const FidelityApp({super.key, this.playIntro = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Al cambiar de idioma en Ajustes, toda la interfaz se actualiza al instante.
    final language = ref.watch(languageProvider);

    return MaterialApp(
      title: 'Fidelity',
      theme: AppTheme.popTheme,
      debugShowCheckedModeBanner: false,
      locale: language.locale,
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorKey: globalNavigatorKey,
      // La animación de entrada va encima de toda la app, la primera vez que se abre.
      builder: (context, child) => FidelityIntroOverlay(enabled: playIntro, child: child ?? const SizedBox.shrink()),
      // En PC los carruseles y las filas de filtros también se arrastran con el ratón.
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      home: const AuthWrapper(),
    );
  }
}
