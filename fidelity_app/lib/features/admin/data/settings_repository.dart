import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';

/// Un ajuste del sistema que el administrador controla.
class AppSettingItem {
  final String key;
  final String group;

  /// 'money' (con centavos) o 'int' (entero).
  final String kind;
  final String label;
  final String description;

  /// "USD", "días", "intentos"...
  final String unit;
  final double min;
  final double max;
  final double defaultValue;
  final double value;

  /// El administrador lo cambió (si no, está en su valor por defecto).
  final bool isCustom;

  const AppSettingItem({
    required this.key,
    required this.group,
    required this.kind,
    required this.label,
    required this.description,
    required this.unit,
    required this.min,
    required this.max,
    required this.defaultValue,
    required this.value,
    required this.isCustom,
  });

  bool get isMoney => kind == 'money';

  /// Las opciones que explica la unidad ("0 = apagado, 1 = encendido"), por valor.
  /// Vacío si la unidad es una unidad de verdad ("USD", "días").
  Map<int, String> get options {
    final found = <int, String>{};
    for (final part in unit.split(',')) {
      final m = RegExp(r'^\s*(\d+)\s*=\s*(.+?)\s*$').firstMatch(part);
      if (m == null) return const {};
      found[int.parse(m.group(1)!)] = m.group(2)!;
    }
    return found;
  }

  /// Un interruptor: solo apagado (0) y encendido (1).
  bool get isSwitch => !isMoney && min == 0 && max == 1 && options[0] == 'apagado' && options[1] == 'encendido';

  /// Lo que se muestra del valor cuando es una opción ("al primer escaneo").
  String? get optionLabel => options[value.round()];

  factory AppSettingItem.fromJson(Map<String, dynamic> json) => AppSettingItem(
        key: json['key'] as String,
        group: json['group'] as String,
        kind: json['kind'] as String? ?? 'int',
        label: json['label'] as String,
        description: json['description'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        min: (json['min'] as num).toDouble(),
        max: (json['max'] as num).toDouble(),
        defaultValue: (json['default'] as num).toDouble(),
        value: (json['value'] as num).toDouble(),
        isCustom: json['isCustom'] == true,
      );

  /// "20.00" o "3", según el tipo.
  String format(double v) => isMoney ? v.toStringAsFixed(2) : v.round().toString();

  /// "20.00 USD" o "3 intentos".
  String get display => unit.isEmpty ? format(value) : '${format(value)} $unit';
}

class AppSettingGroup {
  final String id;
  final String label;
  final String description;

  const AppSettingGroup({required this.id, required this.label, required this.description});

  factory AppSettingGroup.fromJson(Map<String, dynamic> json) => AppSettingGroup(
        id: json['id'] as String,
        label: json['label'] as String,
        description: json['description'] as String? ?? '',
      );
}

class AppSettings {
  final List<AppSettingGroup> groups;
  final List<AppSettingItem> items;

  const AppSettings({this.groups = const [], this.items = const []});

  List<AppSettingItem> itemsOf(String group) => items.where((i) => i.group == group).toList();

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        groups: [
          for (final g in (json['groups'] as List? ?? const []))
            AppSettingGroup.fromJson(Map<String, dynamic>.from(g as Map)),
        ],
        items: [
          for (final i in (json['items'] as List? ?? const []))
            AppSettingItem.fromJson(Map<String, dynamic>.from(i as Map)),
        ],
      );
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

/// Los ajustes del sistema (para el administrador).
final appSettingsProvider = FutureProvider.autoDispose<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).load(),
);

class SettingsRepository {
  final ApiClient _api = ApiClient();

  Future<AppSettings> load() async {
    final response = await _api.get('settings');
    return AppSettings.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Guarda un ajuste; con [value] nulo vuelve a su valor por defecto.
  Future<AppSettings> save(String key, double? value) async {
    final response = await _api.patch('settings', body: {
      'values': {key: value},
    });
    return AppSettings.fromJson(Map<String, dynamic>.from(response as Map));
  }
}
