import 'package:fidelity_app/features/admin/admin_settings_screen.dart';
import 'package:fidelity_app/features/admin/data/settings_repository.dart';
import 'package:flutter/material.dart';
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

class _FakeSettingsRepository extends SettingsRepository {
  final saved = <(String, double?)>[];
  String? failWith;
  late AppSettings current;

  _FakeSettingsRepository() {
    current = AppSettings(
      groups: const [
        AppSettingGroup(id: 'precios', label: 'Precios', description: 'Lo que paga un dueño.'),
        AppSettingGroup(id: 'minijuegos', label: 'Minijuegos', description: 'Reglas de los juegos.'),
      ],
      items: [
        _item('registration_fee', 'precios', 'Registro de negocio',
            kind: 'money', unit: 'USD', min: 0.5, max: 10000, def: 20, value: 35.5, custom: true),
        _item('game_max_attempts', 'minijuegos', 'Intentos por reto'),
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

  testWidgets('muestra los ajustes por grupo con su valor y marca los personalizados', (tester) async {
    await open(tester);

    expect(find.text('AJUSTES'), findsOneWidget);
    expect(find.text('PRECIOS'), findsOneWidget);
    expect(find.text('MINIJUEGOS'), findsOneWidget);
    expect(find.text('Registro de negocio'), findsOneWidget);
    expect(find.text('35.50 USD'), findsOneWidget);
    expect(find.text('3 intentos'), findsOneWidget);
    // Solo el precio fue cambiado por el administrador.
    expect(find.text('PERSONALIZADO'), findsOneWidget);
  });

  testWidgets('cambia un ajuste y lo guarda', (tester) async {
    await open(tester);

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
    await tester.tap(find.text('Intentos por reto'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '4');
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no pueden guardarse más tiempo'), findsOneWidget);
    expect(find.text('GUARDAR'), findsOneWidget);
  });
}
