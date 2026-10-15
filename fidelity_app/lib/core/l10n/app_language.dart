import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Idiomas de la aplicación. El español es el idioma base: el texto de la app
/// está escrito en español y el inglés se traduce desde él (ver `Translator`).
enum AppLanguage {
  es('es', 'Español'),
  en('en', 'English');

  final String code;

  /// Nombre del idioma en su propio idioma (para el selector).
  final String label;

  const AppLanguage(this.code, this.label);

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return AppLanguage.es;
  }
}

/// Guarda el idioma elegido para recordarlo la próxima vez que se abra la app.
class LanguageStore {
  static const _key = 'app_language';

  static Future<AppLanguage> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppLanguage.fromCode(prefs.getString(_key));
    } catch (_) {
      return AppLanguage.es;
    }
  }

  static Future<void> save(AppLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, language.code);
    } catch (_) {
      // Sin almacenamiento disponible: el idioma solo dura esta sesión.
    }
  }
}

/// Idioma con el que arranca la app (`main` lo lee antes de mostrar nada).
final initialLanguageProvider = Provider<AppLanguage>((ref) => AppLanguage.es);

class LanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => ref.watch(initialLanguageProvider);

  /// Cambia el idioma al instante (toda la interfaz se actualiza) y lo guarda.
  Future<void> select(AppLanguage language) async {
    if (language == state) return;
    state = language;
    await LanguageStore.save(language);
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(LanguageNotifier.new);
