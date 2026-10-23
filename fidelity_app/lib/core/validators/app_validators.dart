// lib/core/validators/app_validators.dart
class AppValidators {
  // Validar nombre: solo letras y espacios
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu nombre completo';
    }

    // Regex: solo letras (incluyendo tildes) y espacios
    final nameRegex = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
    if (!nameRegex.hasMatch(value)) {
      return 'El nombre no debe contener números ni caracteres especiales';
    }

    if (value.length < 3) {
      return 'El nombre debe tener al menos 3 caracteres';
    }

    return null;
  }

  // Validar teléfono Ecuador: exactamente 10 dígitos (Obligatorio)
  static String? validateEcuadorPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tu número de teléfono';
    }

    // Regex: exactamente 10 dígitos
    final phoneRegex = RegExp(r'^\d{10}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'El teléfono debe tener exactamente 10 dígitos (formato Ecuador)';
    }

    return null;
  }

  // Validar email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu email';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email inválido';
    }

    return null;
  }

  // Validar contraseña
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña';
    }

    if (value.length < 8) {
      return 'Mínimo 8 caracteres';
    }

    // Letras y números (las reglas del servidor; él además rechaza las más comunes).
    if (!RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñÜü]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
      return 'Usa letras y números';
    }

    return null;
  }

  // Validar nombre de negocio
  static String? validateBusinessName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Ingresa el nombre de tu negocio';
    if (name.length < 2) return 'El nombre debe tener al menos 2 caracteres';
    return null;
  }

  // Teléfono de atención: celular (10 dígitos) o convencional con código de
  // área (9 dígitos). Solo dígitos.
  static String? validateBusinessPhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Ingresa un teléfono de atención';
    if (!RegExp(r'^\d{9,10}$').hasMatch(phone)) {
      return 'El teléfono debe tener 9 o 10 dígitos';
    }
    return null;
  }

  // Cédula (10 dígitos) o RUC (13 dígitos) del propietario. Solo se valida
  // el formato, no el dígito verificador: hay varios tipos de RUC y rechazar
  // uno válido bloquearía al negocio.
  static String? validateTaxId(String? value, {bool required = true}) {
    final id = value?.trim() ?? '';
    if (id.isEmpty) return required ? 'Ingresa tu cédula o RUC' : null;
    if (!RegExp(r'^(\d{10}|\d{13})$').hasMatch(id)) {
      return 'La cédula tiene 10 dígitos y el RUC 13';
    }
    return null;
  }

  static String? validateRewardName(String? value) {
    if ((value?.trim() ?? '').isEmpty) return 'Indica qué premio entregas';
    return null;
  }

  static String? validatePointsRequired(String? value) {
    final points = int.tryParse(value?.trim() ?? '');
    if (points == null || points < 1) return 'Mínimo 1 punto';
    if (points > 100) return 'Máximo 100 puntos';
    return null;
  }

  // Validar confirmación de contraseña
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }

    if (value != password) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }
}
