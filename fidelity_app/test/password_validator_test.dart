import 'package:fidelity_app/core/utils/auth_error_translator.dart';
import 'package:fidelity_app/core/validators/app_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppValidators.validatePassword', () {
    test('acepta una contraseña con letras y números de 8 o más', () {
      for (final ok in ['Clave2026', 'mi-clave-1', 'ñandú2026', 'a1b2c3d4']) {
        expect(AppValidators.validatePassword(ok), isNull, reason: ok);
      }
    });

    test('pide algo cuando está vacía', () {
      expect(AppValidators.validatePassword(''), 'Ingresa tu contraseña');
      expect(AppValidators.validatePassword(null), 'Ingresa tu contraseña');
    });

    test('exige 8 caracteres (antes bastaban 6)', () {
      expect(AppValidators.validatePassword('Abc1234'), 'Mínimo 8 caracteres');
      expect(AppValidators.validatePassword('123456'), 'Mínimo 8 caracteres');
    });

    test('exige letras y números', () {
      expect(AppValidators.validatePassword('sololetrasaqui'), 'Usa letras y números');
      expect(AppValidators.validatePassword('123456789012'), 'Usa letras y números');
    });
  });

  group('mensajes de error de contraseña', () {
    test('el aviso de contraseña corta dice 8', () {
      expect(AuthErrorTranslator.translate('password is too short 6'), contains('8 caracteres'));
    });
  });
}
