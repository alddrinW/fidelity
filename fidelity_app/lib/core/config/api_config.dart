import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Configuración de servidor NestJS
  static String get defaultHost {
    if (kIsWeb) return 'localhost';
    if (Platform.isAndroid)
      return '10.0.2.2'; // Emulador Android por defecto o IP LAN
    return 'localhost';
  }

  // Permite configurar la IP personalizada en tiempo de ejecución si se desea
  static String customHost = '192.168.101.63';

  static String get baseUrl => 'http://$customHost:3000/api/v1';
  static String get websocketUrl => 'http://$customHost:3000';
}
