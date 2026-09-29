import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/api_client.dart';
import 'features/auth/auth_wrapper.dart';

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

  runApp(const ProviderScope(child: FidelityApp()));
}

class FidelityApp extends StatelessWidget {
  const FidelityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fidelity',
      theme: AppTheme.popTheme,
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorKey: globalNavigatorKey,
      home: const AuthWrapper(),
    );
  }
}
