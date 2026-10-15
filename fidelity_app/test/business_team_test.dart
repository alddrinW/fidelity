import 'package:fidelity_app/features/auth/data/auth_repository.dart';
import 'package:fidelity_app/features/business/branches/branches_repository.dart';
import 'package:fidelity_app/features/business/team/team_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthRepository.pickBusinessId', () {
    final active = {'id': 'a', 'isActive': true};
    final inactive = {'id': 'b', 'isActive': false};

    test('conserva el negocio elegido si sigue en la lista', () {
      expect(AuthRepository.pickBusinessId([active, inactive], 'b'), 'b');
    });

    test('sin elección previa prefiere el primer negocio activo', () {
      expect(AuthRepository.pickBusinessId([inactive, active], null), 'a');
    });

    test('si el elegido ya no existe, vuelve al primer activo', () {
      expect(AuthRepository.pickBusinessId([inactive, active], 'borrado'), 'a');
    });

    test('si ninguno está activo toma el primero', () {
      expect(AuthRepository.pickBusinessId([inactive], null), 'b');
    });

    test('sin negocios devuelve null', () {
      expect(AuthRepository.pickBusinessId([], 'a'), isNull);
    });

    test('entiende el formato snake_case', () {
      expect(
        AuthRepository.pickBusinessId([
          {'id': 'x', 'is_active': false},
          {'id': 'y', 'is_active': true},
        ], null),
        'y',
      );
    });
  });

  test('solo dueños y aprobadores operan sobre un negocio', () {
    expect(AuthRepository.isBusinessSide('business'), isTrue);
    expect(AuthRepository.isBusinessSide('approver'), isTrue);
    expect(AuthRepository.isBusinessSide('client'), isFalse);
    expect(AuthRepository.isBusinessSide('admin'), isFalse);
    expect(AuthRepository.isBusinessSide(null), isFalse);
  });

  group('BusinessOverview', () {
    BusinessOverview make(String id, {String? parentId}) =>
        BusinessOverview(id: id, name: id, isActive: true, parentId: parentId);

    test('agrupa cada sucursal debajo de su negocio principal', () {
      final ordered = BusinessOverview.grouped([
        make('norte', parentId: 'a'),
        make('b'),
        make('a'),
        make('sur', parentId: 'a'),
        make('b-centro', parentId: 'b'),
      ]);

      expect(ordered.map((b) => b.id), ['b', 'b-centro', 'a', 'norte', 'sur']);
    });

    test('una sucursal huérfana no se pierde', () {
      final ordered = BusinessOverview.grouped([make('a'), make('sola', parentId: 'inexistente')]);

      expect(ordered.map((b) => b.id), ['a', 'sola']);
    });

    test('lee las cifras del backend', () {
      final b = BusinessOverview.fromJson({
        'id': 'b1',
        'name': 'Café',
        'isActive': true,
        'parentId': null,
        'customers': 12,
        'scansToday': 4,
        'scansTotal': 33,
        'pendingScans': 2,
        'approvers': 1,
      });

      expect(b.customers, 12);
      expect(b.scansToday, 4);
      expect(b.pendingScans, 2);
      expect(b.approvers, 1);
      expect(b.isBranch, isFalse);
    });
  });

  group('TeamMember', () {
    test('usa el nombre y cae al correo si falta', () {
      final named = TeamMember.fromJson({
        'id': 'm1',
        'userId': 'u1',
        'fullName': 'Luis Mora',
        'email': 'luis@mail.com',
      });
      final unnamed = TeamMember.fromJson({'id': 'm2', 'userId': 'u2', 'fullName': '  ', 'email': 'x@mail.com'});

      expect(named.displayName, 'Luis Mora');
      expect(unnamed.displayName, 'x@mail.com');
    });
  });
}
