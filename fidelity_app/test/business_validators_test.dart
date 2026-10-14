import 'package:fidelity_app/core/validators/app_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateTaxId', () {
    test('acepta cédula de 10 dígitos y RUC de 13', () {
      expect(AppValidators.validateTaxId('1712345678'), isNull);
      expect(AppValidators.validateTaxId('1712345678001'), isNull);
      expect(AppValidators.validateTaxId(' 1712345678 '), isNull);
    });

    test('rechaza otras longitudes y caracteres no numéricos', () {
      expect(AppValidators.validateTaxId('12345'), isNotNull);
      expect(AppValidators.validateTaxId('17123456789'), isNotNull);
      expect(AppValidators.validateTaxId('171234567A'), isNotNull);
    });

    test('vacío: error si es obligatorio, válido si es opcional', () {
      expect(AppValidators.validateTaxId(''), isNotNull);
      expect(AppValidators.validateTaxId(null), isNotNull);
      expect(AppValidators.validateTaxId('', required: false), isNull);
      expect(AppValidators.validateTaxId('123', required: false), isNotNull);
    });
  });

  group('validateBusinessPhone', () {
    test('acepta celular (10) y convencional (9)', () {
      expect(AppValidators.validateBusinessPhone('0991234567'), isNull);
      expect(AppValidators.validateBusinessPhone('022345678'), isNull);
    });

    test('rechaza vacío, longitudes inválidas y letras', () {
      expect(AppValidators.validateBusinessPhone(''), isNotNull);
      expect(AppValidators.validateBusinessPhone('12345678'), isNotNull);
      expect(AppValidators.validateBusinessPhone('09912345678'), isNotNull);
      expect(AppValidators.validateBusinessPhone('09912345ab'), isNotNull);
    });
  });

  group('validatePointsRequired', () {
    test('acepta de 1 a 100', () {
      expect(AppValidators.validatePointsRequired('1'), isNull);
      expect(AppValidators.validatePointsRequired('10'), isNull);
      expect(AppValidators.validatePointsRequired('100'), isNull);
    });

    test('rechaza 0, negativos, vacío, texto y más de 100', () {
      expect(AppValidators.validatePointsRequired('0'), isNotNull);
      expect(AppValidators.validatePointsRequired('-3'), isNotNull);
      expect(AppValidators.validatePointsRequired(''), isNotNull);
      expect(AppValidators.validatePointsRequired('diez'), isNotNull);
      expect(AppValidators.validatePointsRequired('101'), isNotNull);
    });
  });

  group('validateBusinessName / validateRewardName', () {
    test('exigen texto no vacío', () {
      expect(AppValidators.validateBusinessName('  '), isNotNull);
      expect(AppValidators.validateBusinessName('A'), isNotNull);
      expect(AppValidators.validateBusinessName('La Reforma'), isNull);
      expect(AppValidators.validateRewardName(''), isNotNull);
      expect(AppValidators.validateRewardName('Café gratis'), isNull);
    });
  });
}
