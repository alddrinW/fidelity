import 'dart:io';
import '../services/api_client.dart';

/// Traductor centralizado de errores de autenticación a español.
class AuthErrorTranslator {
  AuthErrorTranslator._();

  static String translate(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    if (error is SocketException) {
      return 'No hay conexión a internet. Revisa tu red e intenta de nuevo.';
    }
    return _fromMessage(error.toString());
  }

  static String _fromMessage(String rawMessage) {
    final msg = rawMessage.toLowerCase();

    if (msg.contains('invalid') || msg.contains('credenciales') || msg.contains('unauthorized')) {
      return 'Correo o contraseña incorrectos.';
    }

    if (msg.contains('conflict') || msg.contains('registrado') || msg.contains('already')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }

    if (msg.contains('not found') || msg.contains('no encontrado')) {
      return 'No existe una cuenta con este correo.';
    }

    if (msg.contains('password') && (msg.contains('short') || msg.contains('corta') || msg.contains('6'))) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('servidor')) {
      return 'No se pudo conectar con el servidor. Revisa tu conexión.';
    }

    return rawMessage.replaceAll('Exception:', '').trim();
  }
}
