import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';

enum PaymentStatus {
  pending,
  reported,
  paid,
  rejected;

  static PaymentStatus parse(Object? value) => switch (value) {
        'reported' => reported,
        'paid' => paid,
        'rejected' => rejected,
        _ => pending,
      };

  /// El pago todavía espera que el dueño lo reporte o que el admin lo resuelva.
  bool get isOpen => this == pending || this == reported || this == rejected;
}

enum PaymentMethod {
  transfer('transfer', 'Transferencia bancaria', Icons.account_balance_outlined),
  card('card', 'Tarjeta débito/crédito', Icons.credit_card_rounded),
  deposit('deposit', 'Depósito', Icons.receipt_long_outlined),
  cash('cash', 'Efectivo', Icons.payments_outlined);

  /// Métodos que ofrece la app al pagar (depósito y efectivo solo se ven si
  /// ya vienen registrados en un pago).
  static const offered = [transfer, card];

  final String apiValue;
  final String label;
  final IconData icon;

  const PaymentMethod(this.apiValue, this.label, this.icon);

  static PaymentMethod? parse(Object? value) {
    for (final m in values) {
      if (m.apiValue == value) return m;
    }
    return null;
  }
}

/// Cuenta bancaria a la que se transfiere el pago.
class BankAccount {
  final String? bank;
  final String accountNumber;
  final String? accountType;
  final String? holder;
  final String? taxId;

  const BankAccount({
    required this.accountNumber,
    this.bank,
    this.accountType,
    this.holder,
    this.taxId,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        bank: json['bank']?.toString(),
        accountNumber: json['accountNumber']?.toString() ?? '',
        accountType: json['accountType']?.toString(),
        holder: json['holder']?.toString(),
        taxId: json['taxId']?.toString(),
      );
}

/// Precios vigentes del registro y métodos de pago disponibles (los define el
/// backend).
class PaymentPlan {
  final String currency;
  final double registrationFee;
  final double branchFee;

  /// Cuentas para transferencias; vacía si no hay ninguna configurada.
  final List<BankAccount> bankAccounts;

  /// Hay pago con tarjeta (PayPhone) configurado en el backend.
  final bool cardEnabled;

  const PaymentPlan({
    required this.currency,
    required this.registrationFee,
    required this.branchFee,
    this.bankAccounts = const [],
    this.cardEnabled = false,
  });

  /// Métodos que se pueden usar con la configuración actual.
  List<PaymentMethod> get availableMethods => [
        if (bankAccounts.isNotEmpty) PaymentMethod.transfer,
        if (cardEnabled) PaymentMethod.card,
      ];

  factory PaymentPlan.fromJson(Map<String, dynamic> json) {
    final banks = json['bankAccounts'];
    return PaymentPlan(
      currency: json['currency']?.toString() ?? 'USD',
      registrationFee: (json['registrationFee'] as num?)?.toDouble() ?? 0,
      branchFee: (json['branchFee'] as num?)?.toDouble() ?? 0,
      bankAccounts: banks is List
          ? banks
              .whereType<Map>()
              .map((b) => BankAccount.fromJson(Map<String, dynamic>.from(b)))
              .where((b) => b.accountNumber.isNotEmpty)
              .toList()
          : const [],
      cardEnabled: json['cardEnabled'] == true,
    );
  }
}

/// Datos del negocio de un pago (los ve el administrador al revisarlo).
class PaymentBusiness {
  final String id;
  final String name;
  final String? logoUrl;
  final String? category;
  final String? description;
  final String? phone;
  final String? taxId;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? rewardDescription;
  final int? pointsRequired;
  final bool isActive;
  final DateTime? createdAt;

  const PaymentBusiness({
    required this.id,
    required this.name,
    required this.isActive,
    this.logoUrl,
    this.category,
    this.description,
    this.phone,
    this.taxId,
    this.address,
    this.latitude,
    this.longitude,
    this.rewardDescription,
    this.pointsRequired,
    this.createdAt,
  });

  bool get hasLocation => latitude != null && longitude != null;

  factory PaymentBusiness.fromJson(Map<String, dynamic> json) {
    // Los decimales de Postgres llegan como texto.
    double? number(Object? v) => v == null ? null : double.tryParse(v.toString());
    String? text(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    final category = json['categoryRef'];
    return PaymentBusiness(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Negocio',
      logoUrl: text(json['logoUrl']),
      category: category is Map ? text(category['name']) : text(json['category']),
      description: text(json['description']),
      phone: text(json['phone']),
      taxId: text(json['taxId']),
      address: text(json['address']),
      latitude: number(json['latitude']),
      longitude: number(json['longitude']),
      rewardDescription: text(json['rewardDescription']),
      pointsRequired: (json['pointsRequired'] as num?)?.toInt(),
      isActive: json['isActive'] == true,
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal(),
    );
  }
}

/// Dueño del negocio de un pago.
class PaymentOwner {
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;

  const PaymentOwner({required this.name, required this.email, this.phone, this.avatarUrl});

  factory PaymentOwner.fromJson(Map<String, dynamic> json) => PaymentOwner(
        name: (json['fullName'] ?? json['full_name'] ?? '').toString(),
        email: json['email']?.toString() ?? '',
        phone: json['phone']?.toString(),
        avatarUrl: json['avatarUrl']?.toString(),
      );

  /// Nombre para mostrar: el nombre completo o, si falta, el correo.
  String get displayName => name.trim().isEmpty ? email : name;
}

/// Orden de pago por registrar un negocio.
class PaymentOrder {
  final String id;
  final String businessId;
  final String businessName;
  final String concept;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String reference;
  final PaymentMethod? method;
  final String? note;
  final String? proofUrl;
  final String? adminNote;
  final String? receiptNumber;
  final DateTime? createdAt;
  final DateTime? reportedAt;
  final DateTime? paidAt;

  /// Dueño (solo lo trae el listado del administrador).
  final String? ownerName;
  final String? ownerEmail;

  /// Hay una foto de comprobante (el listado no la trae; el detalle sí).
  final bool hasProof;

  /// Datos completos del negocio y del dueño (listado y detalle del admin).
  final PaymentBusiness? businessInfo;
  final PaymentOwner? ownerInfo;

  const PaymentOrder({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.concept,
    required this.amount,
    required this.currency,
    required this.status,
    required this.reference,
    this.method,
    this.note,
    this.proofUrl,
    this.adminNote,
    this.receiptNumber,
    this.createdAt,
    this.reportedAt,
    this.paidAt,
    this.ownerName,
    this.ownerEmail,
    this.hasProof = false,
    this.businessInfo,
    this.ownerInfo,
  });

  bool get isBranch => concept == 'branch';

  String get conceptLabel => isBranch ? 'Alta de sucursal' : 'Registro de negocio';

  String get amountLabel => '\$${amount.toStringAsFixed(2)} $currency';

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    final business = json['business'] as Map?;
    final owner = json['owner'] as Map?;
    DateTime? date(String key) => DateTime.tryParse('${json[key] ?? ''}')?.toLocal();

    return PaymentOrder(
      id: json['id'].toString(),
      businessId: json['businessId']?.toString() ?? '',
      businessName: business?['name']?.toString() ?? 'Mi negocio',
      concept: json['concept']?.toString() ?? 'registration',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      status: PaymentStatus.parse(json['status']),
      reference: json['reference']?.toString() ?? '',
      method: PaymentMethod.parse(json['method']),
      note: json['note']?.toString(),
      proofUrl: json['proofUrl']?.toString(),
      adminNote: json['adminNote']?.toString(),
      receiptNumber: json['receiptNumber']?.toString(),
      createdAt: date('createdAt'),
      reportedAt: date('reportedAt'),
      paidAt: date('paidAt'),
      ownerName: (owner?['fullName'] ?? owner?['full_name'])?.toString(),
      ownerEmail: owner?['email']?.toString(),
      hasProof: json['hasProof'] == true || (json['proofUrl']?.toString().isNotEmpty ?? false),
      businessInfo: business == null
          ? null
          : PaymentBusiness.fromJson(Map<String, dynamic>.from(business)),
      ownerInfo:
          owner == null ? null : PaymentOwner.fromJson(Map<String, dynamic>.from(owner)),
    );
  }
}

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) => PaymentsRepository());

/// Pagos del propio negocio.
final myPaymentsProvider = FutureProvider.autoDispose<List<PaymentOrder>>(
  (ref) => ref.watch(paymentsRepositoryProvider).listMine(),
);

final paymentPlanProvider = FutureProvider.autoDispose<PaymentPlan>(
  (ref) => ref.watch(paymentsRepositoryProvider).getPlan(),
);

class PaymentsRepository {
  final ApiClient _api = ApiClient();

  Future<PaymentPlan> getPlan() async {
    final response = await _api.get('payments/plan');
    return PaymentPlan.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// El administrador fija los precios; devuelve el plan ya actualizado.
  Future<PaymentPlan> updatePrices({
    required double registrationFee,
    required double branchFee,
  }) async {
    final response = await _api.patch('payments/plan', body: {
      'registrationFee': registrationFee,
      'branchFee': branchFee,
    });
    return PaymentPlan.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<List<PaymentOrder>> listMine() async {
    final response = await _api.get('payments/mine');
    return _parseList(response);
  }

  /// Orden vigente del negocio (el backend la crea si aún no existe).
  Future<PaymentOrder> ensureOrder(String businessId) async {
    final response = await _api.post('payments/order', body: {'businessId': businessId});
    return PaymentOrder.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Inicia el pago con tarjeta: devuelve la página de pago de PayPhone. El
  /// cobro lo confirma el servidor cuando el cliente vuelve de PayPhone.
  Future<Uri> startCardPayment(String paymentId) async {
    final response = await _api.post('payments/$paymentId/card');
    final url = (response as Map)['payUrl']?.toString() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw Exception('No se pudo abrir la página de pago.');
    }
    return uri;
  }

  /// El dueño avisa que ya pagó. [proofDataUri] es la foto del comprobante.
  Future<PaymentOrder> report(
    String paymentId, {
    required PaymentMethod method,
    String? note,
    String? proofDataUri,
  }) async {
    final response = await _api.post('payments/$paymentId/report', body: {
      'method': method.apiValue,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (proofDataUri != null && proofDataUri.isNotEmpty) 'proofUrl': proofDataUri,
    });
    return PaymentOrder.fromJson(Map<String, dynamic>.from(response as Map));
  }

  // --- Administración ---

  Future<List<PaymentOrder>> listAll() async {
    final response = await _api.get('payments');
    return _parseList(response);
  }

  /// Un pago completo (con comprobante, negocio y dueño).
  Future<PaymentOrder> getOne(String paymentId) async {
    final response = await _api.get('payments/$paymentId');
    return PaymentOrder.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> validate(String paymentId) async {
    await _api.patch('payments/$paymentId/validate');
  }

  Future<void> reject(String paymentId, String reason) async {
    await _api.patch('payments/$paymentId/reject', body: {'reason': reason});
  }

  List<PaymentOrder> _parseList(dynamic response) {
    if (response is! List) return [];
    return response
        .map((p) => PaymentOrder.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
  }
}
