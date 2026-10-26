import 'package:fidelity_app/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

AuthUser _user(Map<String, dynamic> extra) => AuthUser.fromJson({
      'id': 'u1',
      'email': 'ana@mail.com',
      'fullName': 'Ana',
      'role': 'client',
      ...extra,
    });

void main() {
  group('la bienvenida de la primera entrada', () {
    test('una cuenta nueva (el servidor dice que no la vio) la verá', () {
      expect(_user({'hasSeenWelcome': false}).hasSeenWelcome, isFalse);
    });

    test('sin el dato tampoco la ha visto', () {
      expect(_user({}).hasSeenWelcome, isFalse);
    });

    test('si el servidor dice que ya la vio, no sale otra vez (aunque inicie sesión de nuevo)', () {
      expect(_user({'hasSeenWelcome': true}).hasSeenWelcome, isTrue);
    });

    test('las sesiones guardadas por versiones anteriores siguen valiendo', () {
      expect(_user({'has_seen_welcome': true}).hasSeenWelcome, isTrue);
    });
  });
}
