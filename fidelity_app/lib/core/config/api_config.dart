import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Configuración de servidor NestJS

  /// Host según la plataforma:
  /// - Emulador de Android: `10.0.2.2` es el alias de la PC que lo ejecuta
  ///   (en el emulador, `localhost` sería el propio emulador).
  /// - Web, Windows y demás: `localhost`.
  static String get defaultHost {
    if (kIsWeb) return 'localhost';
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  /// Para un teléfono físico en la misma red Wi-Fi, asigna aquí la IP de tu PC
  /// (p. ej. `ApiConfig.customHost = '192.168.1.20'`). Si es `null` se usa
  /// [defaultHost].
  static String? customHost;

  static String get host => customHost ?? defaultHost;

  static String get baseUrl => 'http://$host:3000/api/v1';
  static String get websocketUrl => 'http://$host:3000';
}
