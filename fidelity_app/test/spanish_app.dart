import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// `MaterialApp` en español para los tests de pantallas: la app muestra su
/// texto en español, pero sin un `locale` explícito Flutter usaría el idioma
/// del sistema donde corre el test (inglés) y la interfaz saldría traducida.
Widget spanishApp(Widget home) => MaterialApp(
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    );
