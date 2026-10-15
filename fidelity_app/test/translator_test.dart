import 'package:fidelity_app/core/l10n/app_language.dart';
import 'package:fidelity_app/core/l10n/language_selector.dart';
import 'package:fidelity_app/core/l10n/strings_en.dart';
import 'package:fidelity_app/core/l10n/tr_text.dart' as tr;
import 'package:fidelity_app/core/l10n/translator.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Translator', () {
    final translator = Translator.english;

    test('traduce el texto exacto', () {
      expect(translator.toEnglish('Iniciar sesión'), 'Log in');
      expect(translator.toEnglish('Clientes'), 'Customers');
    });

    test('un texto sin traducción se devuelve igual (nunca falla)', () {
      expect(translator.toEnglish('Texto que no existe en el diccionario'),
          'Texto que no existe en el diccionario');
      expect(translator.toEnglish(''), '');
      expect(translator.toEnglish('   '), '   ');
    });

    test('un título en mayúsculas se traduce y se devuelve en mayúsculas', () {
      expect(translator.toEnglish('INICIAR SESIÓN'), 'LOG IN');
      expect(translator.toEnglish('RECUPERAR CONTRASEÑA'), 'RECOVER PASSWORD');
    });

    test('las plantillas rellenan los datos', () {
      expect(translator.toEnglish('Hola, Ana'), 'Hello, Ana');
      expect(translator.toEnglish('12 clientes activos'), '12 active customers');
      expect(translator.toEnglish('Ganaste Café gratis en Café Aurora. Acércate al local para reclamarlo.'),
          'You won Café gratis at Café Aurora. Go to the store to claim it.');
    });

    test('la plantilla más específica gana', () {
      expect(translator.toEnglish('Hola, Ana · Aprobador'), 'Hello, Ana · Approver');
    });

    test('una plantilla puede reordenar los datos', () {
      expect(translator.toEnglish('Tarjeta de Café Aurora, 6 de 10 puntos'),
          'Café Aurora card, 6 of 10 points');
    });

    test('los datos de una plantilla se traducen a su vez', () {
      expect(translator.toEnglish('Tarjeta de regalo · Sin fecha de fin'),
          'Gift card · No end date');
    });

    test('las plantillas en mayúsculas funcionan', () {
      expect(translator.toEnglish('6/10 PUNTOS'), '6/10 POINTS');
      expect(translator.toEnglish('2 PREMIOS LISTOS'), '2 PRIZES READY');
    });

    test('el texto de varias líneas se traduce línea por línea', () {
      expect(translator.toEnglish('Cancelar\nAceptar'), 'Cancel\nOK');
    });

    test('un nombre que parece una plantilla no se rompe', () {
      expect(translator.toEnglish('Hola, {}'), 'Hello, {}');
    });
  });

  group('diccionario', () {
    test('ninguna clave exacta queda vacía ni sin traducción', () {
      kEnglishStrings.forEach((key, value) {
        expect(key.trim(), isNotEmpty);
        expect(value.trim(), isNotEmpty, reason: 'sin traducción: $key');
      });
    });

    test('cada plantilla conserva la cantidad de datos', () {
      kEnglishPatterns.forEach((source, target) {
        final holes = '{}'.allMatches(source).length;
        final used = RegExp(r'\{(\d*)\}').allMatches(target).length;
        expect(source.contains('{}'), isTrue, reason: 'sin {}: $source');
        // La traducción puede omitir un dato, pero no inventar más de los que hay.
        for (final m in RegExp(r'\{(\d+)\}').allMatches(target)) {
          expect(int.parse(m.group(1)!), lessThanOrEqualTo(holes), reason: source);
        }
        if (RegExp(r'\{\}').hasMatch(target)) {
          expect(used, lessThanOrEqualTo(holes + 0), reason: source);
        }
      });
    });

    test('las traducciones no mezclan una clave exacta con una plantilla', () {
      for (final key in kEnglishStrings.keys) {
        expect(key.contains('{}'), isFalse, reason: 'va en las plantillas: $key');
      }
    });
  });

  group('AppLanguage', () {
    test('se reconoce por su código y cae en español', () {
      expect(AppLanguage.fromCode('en'), AppLanguage.en);
      expect(AppLanguage.fromCode('es'), AppLanguage.es);
      expect(AppLanguage.fromCode('fr'), AppLanguage.es);
      expect(AppLanguage.fromCode(null), AppLanguage.es);
    });

    test('se guarda y se recupera', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await LanguageStore.load(), AppLanguage.es);
      await LanguageStore.save(AppLanguage.en);
      expect(await LanguageStore.load(), AppLanguage.en);
    });
  });

  group('Text traducido', () {
    Widget app(AppLanguage language, Widget child) => ProviderScope(
          overrides: [initialLanguageProvider.overrideWithValue(language)],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              locale: ref.watch(languageProvider).locale,
              supportedLocales: const [Locale('es'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: Scaffold(body: child),
            ),
          ),
        );

    testWidgets('en español muestra el texto tal cual', (tester) async {
      await tester.pumpWidget(app(AppLanguage.es, const tr.Text('Iniciar sesión')));

      expect(find.text('Iniciar sesión'), findsOneWidget);
    });

    testWidgets('en inglés muestra la traducción', (tester) async {
      await tester.pumpWidget(app(AppLanguage.en, const tr.Text('Iniciar sesión')));

      expect(find.text('Log in'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsNothing);
    });

    testWidgets('al cambiar de idioma el texto se actualiza al instante', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(app(
        AppLanguage.es,
        const Column(children: [tr.Text('Clientes'), LanguageRow()]),
      ));
      expect(find.text('Clientes'), findsOneWidget);

      await tester.tap(find.textContaining('Idioma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Clientes'), findsNothing);
      expect(find.textContaining('Language'), findsOneWidget);
    });
  });
}
