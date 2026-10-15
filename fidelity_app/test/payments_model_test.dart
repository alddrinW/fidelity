import 'package:fidelity_app/features/payments/data/payments_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentOrder.fromJson', () {
    test('lee una orden reportada con su negocio y dueño', () {
      final order = PaymentOrder.fromJson({
        'id': 'p1',
        'businessId': 'b1',
        'business': {'name': 'Café Aurora'},
        'owner': {'fullName': 'Ana Torres', 'email': 'ana@mail.com'},
        'concept': 'registration',
        'amount': 20,
        'currency': 'USD',
        'status': 'reported',
        'reference': 'FID-ABC234',
        'method': 'transfer',
        'note': 'Transf 8842',
        'reportedAt': '2026-10-14T15:00:00.000Z',
      });

      expect(order.status, PaymentStatus.reported);
      expect(order.method, PaymentMethod.transfer);
      expect(order.businessName, 'Café Aurora');
      expect(order.ownerName, 'Ana Torres');
      expect(order.amountLabel, '\$20.00 USD');
      expect(order.conceptLabel, 'Registro de negocio');
      expect(order.reportedAt, isNotNull);
      expect(order.paidAt, isNull);
    });

    test('un valor desconocido de estado se trata como pendiente', () {
      final order = PaymentOrder.fromJson({'id': 'p1', 'status': 'algo-raro'});

      expect(order.status, PaymentStatus.pending);
      expect(order.method, isNull);
      expect(order.businessName, 'Mi negocio');
    });

    test('una sucursal se etiqueta como alta de sucursal', () {
      final order = PaymentOrder.fromJson({'id': 'p1', 'concept': 'branch', 'amount': 10.5});

      expect(order.isBranch, isTrue);
      expect(order.conceptLabel, 'Alta de sucursal');
      expect(order.amountLabel, '\$10.50 USD');
    });
  });

  test('solo los pagos sin pagar se consideran abiertos', () {
    expect(PaymentStatus.pending.isOpen, isTrue);
    expect(PaymentStatus.reported.isOpen, isTrue);
    expect(PaymentStatus.rejected.isOpen, isTrue);
    expect(PaymentStatus.paid.isOpen, isFalse);
  });

  test('PaymentPlan lee los precios del backend', () {
    final plan = PaymentPlan.fromJson({
      'currency': 'USD',
      'registrationFee': 20,
      'branchFee': 10,
    });

    expect(plan.registrationFee, 20);
    expect(plan.branchFee, 10);
  });

  group('métodos de pago del plan', () {
    test('sin cuenta ni PayPhone no hay métodos disponibles', () {
      final plan = PaymentPlan.fromJson({'currency': 'USD', 'registrationFee': 20, 'branchFee': 10});

      expect(plan.availableMethods, isEmpty);
      expect(plan.bankAccounts, isEmpty);
      expect(plan.cardEnabled, isFalse);
    });

    test('con cuenta bancaria se ofrece la transferencia', () {
      final plan = PaymentPlan.fromJson({
        'registrationFee': 20,
        'bankAccounts': [
          {
            'bank': 'Banco de Loja',
            'accountNumber': '2900000001',
            'accountType': 'Cuenta de ahorros',
            'holder': 'Titular Uno',
            'taxId': '1100000001',
          },
          {'bank': 'Banco Pichincha', 'accountNumber': '2200000002'},
          {'bank': 'Sin número'},
        ],
      });

      expect(plan.availableMethods, [PaymentMethod.transfer]);
      expect(plan.bankAccounts.map((b) => b.bank), ['Banco de Loja', 'Banco Pichincha']);
      expect(plan.bankAccounts.first.holder, 'Titular Uno');
    });

    test('con PayPhone configurado se ofrece la tarjeta', () {
      final plan = PaymentPlan.fromJson({'cardEnabled': true});

      expect(plan.availableMethods, [PaymentMethod.card]);
    });

    test('con las dos configuraciones se ofrecen ambos métodos', () {
      final plan = PaymentPlan.fromJson({
        'bankAccounts': [
          {'accountNumber': '1'},
        ],
        'cardEnabled': true,
      });

      expect(plan.availableMethods, [PaymentMethod.transfer, PaymentMethod.card]);
      expect(PaymentMethod.offered, [PaymentMethod.transfer, PaymentMethod.card]);
    });
  });
}
