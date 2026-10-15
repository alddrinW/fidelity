import 'package:flutter/widgets.dart';

import 'strings_en.dart';

/// Traduce el texto de la interfaz del español al inglés.
///
/// El código de la app escribe sus textos en español; aquí se buscan en el
/// diccionario inglés:
///  1. **Texto exacto** (`'Iniciar sesión'`).
///  2. **Mayúsculas y minúsculas indistintas**: los títulos que la interfaz
///     pasa a mayúsculas (`'INICIAR SESIÓN'`) se traducen y se devuelven en
///     mayúsculas.
///  3. **Plantillas** con `{}` para textos con datos (`'Hola, {}'`): cada `{}`
///     toma un valor, que a su vez se traduce, y en la traducción puede
///     reordenarse con `{1}`, `{2}`...
///  4. Textos de **varias líneas**: se traduce cada línea.
///
/// Si no hay traducción, se devuelve el texto tal cual (en español): nunca
/// falla ni deja un hueco.
class Translator {
  final Map<String, String> _exact;
  final Map<String, String> _lower = {};
  final List<_Pattern> _patterns = [];
  final Map<String, String> _cache = {};

  Translator(this._exact, Map<String, String> patterns) {
    for (final entry in _exact.entries) {
      _lower.putIfAbsent(entry.key.toLowerCase(), () => entry.value);
    }
    for (final entry in patterns.entries) {
      _patterns.add(_Pattern(entry.key, entry.value));
    }
    // Las plantillas más específicas (más texto fijo) se prueban primero.
    _patterns.sort((a, b) => b.fixedLength.compareTo(a.fixedLength));
  }

  /// Traductor con el diccionario inglés de la app.
  static final Translator english = Translator(kEnglishStrings, kEnglishPatterns);

  String toEnglish(String text) {
    if (text.trim().isEmpty) return text;
    return _cache.putIfAbsent(text, () => _translate(text));
  }

  String _translate(String text) {
    final exact = _exact[text];
    if (exact != null) return exact;

    final shouting = _isShouting(text);
    String finish(String value) => shouting ? value.toUpperCase() : value;

    final lower = _lower[text.toLowerCase()];
    if (lower != null) return finish(lower);

    for (final pattern in _patterns) {
      final result = pattern.apply(text, toEnglish, caseSensitive: !shouting);
      if (result != null) return finish(result);
    }

    if (text.contains('\n')) {
      return text.split('\n').map(toEnglish).join('\n');
    }
    return text;
  }

  /// Todo el texto está en mayúsculas (y tiene letras): un título "gritado".
  static bool _isShouting(String text) =>
      text == text.toUpperCase() && text != text.toLowerCase();
}

class _Pattern {
  final String source;
  final String target;
  late final RegExp _caseSensitive = _compile(true);
  late final RegExp _caseInsensitive = _compile(false);

  _Pattern(this.source, this.target);

  /// Cantidad de caracteres fijos (sin los `{}`): mayor = más específica.
  int get fixedLength => source.replaceAll('{}', '').length;

  RegExp _compile(bool caseSensitive) {
    final parts = source.split('{}').map(RegExp.escape).toList();
    return RegExp('^${parts.join('(.+?)')}\$', caseSensitive: caseSensitive, dotAll: true);
  }

  String? apply(
    String text,
    String Function(String) translate, {
    required bool caseSensitive,
  }) {
    final match = (caseSensitive ? _caseSensitive : _caseInsensitive).firstMatch(text);
    if (match == null) return null;

    final values = [
      for (var i = 1; i <= match.groupCount; i++) translate(match.group(i) ?? ''),
    ];
    var sequential = 0;
    return target.replaceAllMapped(RegExp(r'\{(\d*)\}'), (m) {
      final index = m.group(1)!.isEmpty ? sequential++ : int.parse(m.group(1)!) - 1;
      return index < values.length ? values[index] : '';
    });
  }
}

extension TranslateContext on BuildContext {
  /// Idioma activo de la app (cambia al elegir otro en Ajustes).
  ///
  /// Usa `Localizations`, así que el widget se reconstruye solo al cambiar de
  /// idioma, incluso si es `const`.
  String get languageCode => Localizations.maybeLocaleOf(this)?.languageCode ?? 'es';

  /// Traduce un texto escrito en español al idioma activo.
  String tr(String spanish) =>
      languageCode == 'en' ? Translator.english.toEnglish(spanish) : spanish;
}
