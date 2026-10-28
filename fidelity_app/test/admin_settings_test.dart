import 'package:fidelity_app/features/admin/admin_settings_screen.dart';
import 'package:fidelity_app/features/admin/data/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spanish_app.dart';

AppSettingItem _item(
  String key,
  String group,
  String label, {
  String kind = 'int',
  String unit = 'intentos',
  double min = 1,
  double max = 10,
  double def = 3,
  double? value,
  bool custom = false,
}) =>
    AppSettingItem(
      key: key,
      group: group,
      kind: kind,
      label: label,
      description: 'Descripción de $label',
      unit: unit,
      min: min,
      max: max,
      defaultValue: def,
      value: value ?? def,
      isCustom: custom,
    );

/// Una descripción de las que hacían la pantalla larguísima.
const _long = 'Con 1, cada cliente puede jugar una vez por semana (de lunes a domingo): elige un negocio y, si gana, '
    'suma puntos ahí. No puede repetir un negocio donde ya ganó, y cuando ya ganó en todos se abre de nuevo la lista.';

extension on AppSettingItem {
  AppSettingItem withDescription(String text) => AppSettingItem(
        key: key,
        group: this.group,
        kind: kind,
        label: label,
        description: text,
        unit: unit,
        min: min,
        max: max,
        defaultValue: defaultValue,
        value: value,
        isCustom: isCustom,
      );
}

class _FakeSettingsRepository extends SettingsRepository {
  final saved = <(String, double?)>[];
  String? failWith;
  late AppSettings current;

  _FakeSettingsRepository() {
    current = AppSettings(
      groups: const [
        AppSettingGroup(id: 'precios', label: 'Precios', description: 'Lo que paga un dueño.'),
        AppSettingGroup(id: 'minijuegos', label: 'Minijuegos', description: 'Reglas de los juegos.'),
        AppSettingGroup(id: 'tarjetas', label: 'Tarjetas', description: 'Venta de tarjetas.'),
      ],
      items: [
        _item('registration_fee', 'precios', 'Registro de negocio',
            kind: 'money', unit: 'USD', min: 0.5, max: 10000, def: 20, value: 35.5, custom: true),
        _item('game_max_attempts', 'minijuegos', 'Intentos por reto'),
        _item('weekly_game_enabled', 'tarjetas', 'Juego semanal',
            unit: '0 = apagado, 1 = encendido', min: 0, max: 1, def: 0, value: 0).withDescription(_long),
        _item('referral_trigger', 'tarjetas', 'Cuándo cuenta un amigo',
            unit: '0 = al registrarse, 1 = al primer escaneo', min: 0, max: 1, def: 0, value: 1, custom: true),
      ],
    );
  }

  @override
  Future<AppSettings> load() async => current;

  @override
  Future<AppSettings> save(String key, double? value) async {
    if (failWith != null) throw failWith!;
    saved.add((key, value));
    return current;
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late _FakeSettingsRepository repo;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = _FakeSettingsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
        child: spanishApp(const AdminSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Abre un grupo (todos empiezan cerrados).
  Future<void> openGroup(WidgetTester tester, String label) async {
    await tester.tap(find.text(label.toUpperCase()));
    await tester.pumpAndSettle();
  }

  testWidgets('los grupos empiezan cerrados y dicen cuántos ajustes tienen y cuántos se cambiaron', (tester) async {
    await open(tester);

    expect(find.text('AJUSTES'), findsOneWidget);
    expect(find.text('PRECIOS'), findsOneWidget);
    expect(find.text('MINIJUEGOS'), findsOneWidget);
    expect(find.text('TARJETAS'), findsOneWidget);
    // Cerrados: ningún ajuste a la vista.
    expect(find.text('Registro de negocio'), findsNothing);
    expect(find.text('1 ajuste'), findsNWidgets(2)); // Precios y Minijuegos
    expect(find.text('2 ajustes'), findsOneWidget); // Tarjetas
    // Precios y Tarjetas tienen uno cambiado cada uno.
    expect(find.text('1 PERSONALIZADO'), findsNWidgets(2));
  });

  testWidgets('abrir un grupo muestra sus ajustes con el valor y su unidad aparte; tocar de nuevo lo cierra', (tester) async {
    await open(tester);

    await openGroup(tester, 'Precios');
    expect(find.text('Registro de negocio'), findsOneWidget);
    expect(find.text('35.50'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    // Solo el precio fue cambiado por el administrador.
    expect(find.text('PERSONALIZADO'), findsOneWidget);

    await openGroup(tester, 'Minijuegos');
    expect(find.text('3'), findsOneWidget);
    expect(find.text('intentos'), findsOneWidget);

    await openGroup(tester, 'Precios');
    expect(find.text('Registro de negocio'), findsNothing);
  });

  testWidgets('encender o apagar es un interruptor que se guarda al instante, sin números', (tester) async {
    await open(tester);
    await openGroup(tester, 'Tarjetas');

    final toggle = find.byType(Switch);
    expect(toggle, findsOneWidget);
    expect(tester.widget<Switch>(toggle).value, isFalse);
    // No sale el "0 = apagado, 1 = encendido" que antes aplastaba la tarjeta.
    expect(find.textContaining('0 = apagado'), findsNothing);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(repo.saved, [('weekly_game_enabled', 1.0)]);
    expect(find.text('Ajuste guardado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('una opción se muestra con palabras, no como "1" ni con la frase de la unidad', (tester) async {
    await open(tester);
    await openGroup(tester, 'Tarjetas');

    expect(find.text('Al primer escaneo'), findsOneWidget);
    expect(find.textContaining('1 = al primer escaneo'), findsNothing);
  });

  testWidgets('una descripción larga se muestra corta, con "Ver más" y "Ver menos"', (tester) async {
    await open(tester);
    await openGroup(tester, 'Tarjetas');

    expect(find.text('Ver más'), findsOneWidget);
    // Corta: dos líneas con puntos suspensivos.
    final text = tester.widget<Text>(find.textContaining('Con 1, cada cliente'));
    expect(text.maxLines, 2);

    await tester.tap(find.text('Ver más'));
    await tester.pumpAndSettle();
    expect(find.text('Ver menos'), findsOneWidget);
    expect(tester.widget<Text>(find.textContaining('Con 1, cada cliente')).maxLines, isNull);

    await tester.tap(find.text('Ver menos'));
    await tester.pumpAndSettle();
    expect(find.text('Ver más'), findsOneWidget);
  });

  testWidgets('una descripción corta no lleva "Ver más"', (tester) async {
    await open(tester);
    await openGroup(tester, 'Minijuegos');

    expect(find.text('Ver más'), findsNothing);
  });

  testWidgets('en un celular angosto con letra grande no se desborda', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = _FakeSettingsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
        child: MediaQuery(
          data: const MediaQueryData(size: Size(320, 700), textScaler: TextScaler.linear(1.4)),
          child: spanishApp(const AdminSettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final g in ['Precios', 'Minijuegos', 'Tarjetas']) {
      await tester.scrollUntilVisible(find.text(g.toUpperCase()), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(g.toUpperCase()));
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('en inglés los contadores, "Ver más" y las opciones salen traducidos', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = _FakeSettingsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const AdminSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 settings'), findsOneWidget);
    expect(find.text('1 setting'), findsNWidgets(2));
    await tester.tap(find.text('CARDS'));
    await tester.pumpAndSettle();
    expect(find.text('See more'), findsOneWidget);
    expect(find.text('On their first scan'), findsOneWidget);
  });

  testWidgets('el modelo entiende las unidades que son opciones', (tester) async {
    final onOff = _item('a', 'g', 'A', unit: '0 = apagado, 1 = encendido', min: 0, max: 1, def: 0, value: 1);
    expect(onOff.isSwitch, isTrue);
    expect(onOff.options, {0: 'apagado', 1: 'encendido'});
    expect(onOff.optionLabel, 'encendido');

    final choice = _item('b', 'g', 'B', unit: '0 = al registrarse, 1 = al primer escaneo', min: 0, max: 1, def: 0, value: 0);
    expect(choice.isSwitch, isFalse);
    expect(choice.optionLabel, 'al registrarse');

    final plain = _item('c', 'g', 'C', unit: 'días', min: 1, max: 30, def: 5);
    expect(plain.options, isEmpty);
    expect(plain.isSwitch, isFalse);
    expect(plain.optionLabel, isNull);
  });

  testWidgets('cambia un ajuste y lo guarda', (tester) async {
    await open(tester);
    await openGroup(tester, 'Minijuegos');

    await tester.tap(find.text('Intentos por reto'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Por defecto: 3 · de 1 a 10'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '5');
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();

    expect(repo.saved, [('game_max_attempts', 5.0)]);
    expect(find.text('Ajuste guardado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('un valor fuera de rango, decimal en un entero o vacío no se guarda', (tester) async {
    await open(tester);
    await openGroup(tester, 'Minijuegos');
    await tester.tap(find.text('Intentos por reto'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '11');
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();
    expect(find.text('Debe estar entre 1 y 10'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un número'), findsOneWidget);

    expect(repo.saved, isEmpty);
  });

  testWidgets('un precio acepta coma decimal', (tester) async {
    await open(tester);
    await openGroup(tester, 'Precios');
    await tester.tap(find.text('Registro de negocio'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '42,5');
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();

    expect(repo.saved, [('registration_fee', 42.5)]);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('restablecer vuelve al valor por defecto (solo si fue cambiado)', (tester) async {
    await open(tester);
    await openGroup(tester, 'Minijuegos');
    await openGroup(tester, 'Precios');

    await tester.tap(find.text('Intentos por reto'));
    await tester.pumpAndSettle();
    expect(find.text('Restablecer'), findsNothing);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registro de negocio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restablecer'));
    await tester.pumpAndSettle();

    expect(repo.saved, [('registration_fee', null)]);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('si el servidor rechaza el valor, muestra el motivo y no cierra', (tester) async {
    await open(tester);
    repo.failWith = 'Los avisos leídos no pueden guardarse más tiempo que cualquier aviso';
    await openGroup(tester, 'Minijuegos');
    await tester.tap(find.text('Intentos por reto'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '4');
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no pueden guardarse más tiempo'), findsOneWidget);
    expect(find.text('GUARDAR'), findsOneWidget);
  });
}
