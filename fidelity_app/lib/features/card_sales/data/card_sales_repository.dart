import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../../campaigns/data/campaigns_repository.dart';
import '../../payments/data/payments_repository.dart' show BankAccount;

/// Las reglas de la venta de tarjetas que fijó el administrador.
class CardSalesRules {
  /// Con `false` no se vende nada nuevo (lo ya comprado se sigue canjeando).
  final bool enabled;

  /// Lo que se queda Fidelity de cada venta (incluye lo que cobra PayPhone).
  final int commissionPercent;
  final int minPriceCents;
  final int maxPriceCents;

  /// Se puede pagar con tarjeta en PayPhone.
  final bool cardEnabled;

  /// Se puede pagar por transferencia (con comprobante que revisa el administrador).
  final bool transferEnabled;

  /// Las cuentas donde transferir.
  final List<BankAccount> bankAccounts;

  const CardSalesRules({
    this.enabled = false,
    this.commissionPercent = 10,
    this.minPriceCents = 25,
    this.maxPriceCents = 2500,
    this.cardEnabled = true,
    this.transferEnabled = false,
    this.bankAccounts = const [],
  });

  /// Hay más de una forma de pagar (el cliente elige).
  bool get canChoose => cardEnabled && transferEnabled;

  factory CardSalesRules.fromJson(Map<String, dynamic> json) => CardSalesRules(
        enabled: json['enabled'] == true,
        commissionPercent: (json['commissionPercent'] as num?)?.toInt() ?? 10,
        minPriceCents: (json['minPriceCents'] as num?)?.toInt() ?? 25,
        maxPriceCents: (json['maxPriceCents'] as num?)?.toInt() ?? 2500,
        cardEnabled: json['cardEnabled'] != false,
        transferEnabled: json['transferEnabled'] == true,
        bankAccounts: ((json['bankAccounts'] as List?) ?? const [])
            .map((b) => BankAccount.fromJson(Map<String, dynamic>.from(b as Map)))
            .toList(),
      );
}

/// Lo que se necesita para pagar una tarjeta por transferencia: la referencia, el monto y las cuentas.
class TransferStart {
  final String purchaseId;
  final String reference;
  final int amountCents;
  final DateTime? reservedUntil;
  final List<BankAccount> bankAccounts;

  const TransferStart({
    required this.purchaseId,
    required this.reference,
    required this.amountCents,
    this.reservedUntil,
    this.bankAccounts = const [],
  });

  factory TransferStart.fromJson(Map<String, dynamic> json) => TransferStart(
        purchaseId: json['purchaseId'].toString(),
        reference: json['reference']?.toString() ?? '',
        amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
        reservedUntil: DateTime.tryParse('${json['reservedUntil'] ?? ''}')?.toLocal(),
        bankAccounts: ((json['bankAccounts'] as List?) ?? const [])
            .map((b) => BankAccount.fromJson(Map<String, dynamic>.from(b as Map)))
            .toList(),
      );
}

/// Un comprobante de transferencia por revisar (vista del administrador).
class CardReview {
  final String id;
  final String reference;
  final int amountCents;
  final String? title;
  final String? buyer;
  final String? buyerEmail;
  final String? businessName;
  final String? proofUrl;
  final String? note;
  final DateTime? reportedAt;

  const CardReview({
    required this.id,
    required this.reference,
    required this.amountCents,
    this.title,
    this.buyer,
    this.buyerEmail,
    this.businessName,
    this.proofUrl,
    this.note,
    this.reportedAt,
  });

  factory CardReview.fromJson(Map<String, dynamic> json) => CardReview(
        id: json['id'].toString(),
        reference: json['reference']?.toString() ?? '',
        amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString(),
        buyer: json['buyer']?.toString(),
        buyerEmail: json['buyerEmail']?.toString(),
        businessName: json['businessName']?.toString(),
        proofUrl: json['proofUrl']?.toString(),
        note: json['note']?.toString(),
        reportedAt: DateTime.tryParse('${json['reportedAt'] ?? ''}')?.toLocal(),
      );
}

/// Una venta reciente de una tarjeta (vista del dueño).
class SaleRow {
  final String? title;
  final String? buyer;
  final int amountCents;
  final int netCents;
  final DateTime? paidAt;
  final bool redeemed;
  final bool settled;

  const SaleRow({
    this.title,
    this.buyer,
    required this.amountCents,
    required this.netCents,
    this.paidAt,
    this.redeemed = false,
    this.settled = false,
  });

  factory SaleRow.fromJson(Map<String, dynamic> json) => SaleRow(
        title: json['title']?.toString(),
        buyer: json['buyer']?.toString(),
        amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
        netCents: (json['netCents'] as num?)?.toInt() ?? 0,
        paidAt: DateTime.tryParse('${json['paidAt'] ?? ''}')?.toLocal(),
        redeemed: json['redeemed'] == true,
        settled: json['settled'] == true,
      );
}

/// Lo vendido por el local y lo que le toca (vista del dueño).
class SalesSummary {
  final int sold;
  final int grossCents;
  final int commissionCents;
  final int netCents;
  final int redeemed;

  /// Lo que ya puede cobrar: tarjetas canjeadas y aún no pagadas.
  final int payableCents;

  /// Lo ya pagado al local.
  final int paidOutCents;

  /// Vendido, pero todavía sin canjear.
  final int pendingCents;
  final List<SaleRow> recent;

  const SalesSummary({
    this.sold = 0,
    this.grossCents = 0,
    this.commissionCents = 0,
    this.netCents = 0,
    this.redeemed = 0,
    this.payableCents = 0,
    this.paidOutCents = 0,
    this.pendingCents = 0,
    this.recent = const [],
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num?)?.toInt() ?? 0;
    return SalesSummary(
      sold: n('sold'),
      grossCents: n('grossCents'),
      commissionCents: n('commissionCents'),
      netCents: n('netCents'),
      redeemed: n('redeemed'),
      payableCents: n('payableCents'),
      paidOutCents: n('paidOutCents'),
      pendingCents: n('pendingCents'),
      recent: ((json['recent'] as List?) ?? const [])
          .map((r) => SaleRow.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
    );
  }
}

/// Lo que se le debe pagar a un local por sus tarjetas canjeadas (vista del administrador).
class PayoutRow {
  final String businessId;
  final String? businessName;
  final String? ownerName;
  final String? ownerEmail;
  final int cards;
  final int netCents;

  const PayoutRow({
    required this.businessId,
    this.businessName,
    this.ownerName,
    this.ownerEmail,
    required this.cards,
    required this.netCents,
  });

  factory PayoutRow.fromJson(Map<String, dynamic> json) => PayoutRow(
        businessId: json['businessId'].toString(),
        businessName: json['businessName']?.toString(),
        ownerName: json['ownerName']?.toString(),
        ownerEmail: json['ownerEmail']?.toString(),
        cards: (json['cards'] as num?)?.toInt() ?? 0,
        netCents: (json['netCents'] as num?)?.toInt() ?? 0,
      );
}

/// Una compra cobrada dos veces, por devolver (vista del administrador).
class RefundRow {
  final String id;
  final String reference;
  final int amountCents;
  final String? buyer;
  final String? buyerEmail;
  final String? businessName;

  const RefundRow({
    required this.id,
    required this.reference,
    required this.amountCents,
    this.buyer,
    this.buyerEmail,
    this.businessName,
  });

  factory RefundRow.fromJson(Map<String, dynamic> json) => RefundRow(
        id: json['id'].toString(),
        reference: json['reference']?.toString() ?? '',
        amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
        buyer: json['buyer']?.toString(),
        buyerEmail: json['buyerEmail']?.toString(),
        businessName: json['businessName']?.toString(),
      );
}

class PayoutsOverview {
  final List<PayoutRow> payouts;
  final List<RefundRow> refunds;

  const PayoutsOverview({this.payouts = const [], this.refunds = const []});

  int get totalCents => payouts.fold(0, (t, p) => t + p.netCents);

  factory PayoutsOverview.fromJson(Map<String, dynamic> json) => PayoutsOverview(
        payouts: ((json['payouts'] as List?) ?? const [])
            .map((r) => PayoutRow.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList(),
        refunds: ((json['refunds'] as List?) ?? const [])
            .map((r) => RefundRow.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList(),
      );
}

class CardSalesRepository {
  final ApiClient _api = ApiClient();

  Future<CardSalesRules> rules() async =>
      CardSalesRules.fromJson(Map<String, dynamic>.from(await _api.get('card-sales/rules') as Map));

  /// Las tarjetas en venta que el cliente puede comprar.
  Future<List<Campaign>> offers() async {
    final response = await _api.get('card-sales/offers');
    if (response is! List) return [];
    return response.map((c) => Campaign.fromJson(Map<String, dynamic>.from(c as Map))).toList();
  }

  /// Empieza la compra: devuelve la página de pago de PayPhone. El servidor
  /// entrega la tarjeta cuando PayPhone confirma el cobro.
  Future<Uri> startPurchase(String campaignId) async {
    final response = await _api.post('card-sales/$campaignId/purchase');
    final url = (response as Map)['payUrl']?.toString() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw Exception('No se pudo abrir la página de pago.');
    }
    return uri;
  }

  /// El cliente va a pagar por transferencia: se le guarda la tarjeta y se le dan las cuentas y la referencia.
  Future<TransferStart> startTransfer(String campaignId) async {
    final response = await _api.post('card-sales/$campaignId/purchase', body: {'method': 'transfer'});
    return TransferStart.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Sube la foto del comprobante: el administrador lo revisa y, al aprobarlo, llega la tarjeta.
  Future<void> submitProof(String purchaseId, String proofDataUri, {String? note}) async {
    await _api.post('card-sales/purchases/$purchaseId/proof', body: {
      'proofUrl': proofDataUri,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  /// Los comprobantes por revisar (administrador).
  Future<List<CardReview>> reviews() async {
    final response = await _api.get('card-sales/admin/reviews');
    if (response is! List) return [];
    return response.map((r) => CardReview.fromJson(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<void> approveReview(String purchaseId) async {
    await _api.post('card-sales/admin/reviews/$purchaseId/approve');
  }

  Future<void> rejectReview(String purchaseId, String reason) async {
    await _api.post('card-sales/admin/reviews/$purchaseId/reject', body: {'reason': reason.trim()});
  }

  Future<SalesSummary> mySales() async =>
      SalesSummary.fromJson(Map<String, dynamic>.from(await _api.get('card-sales/mine') as Map));

  Future<PayoutsOverview> payouts() async => PayoutsOverview.fromJson(
      Map<String, dynamic>.from(await _api.get('card-sales/admin/payouts') as Map));

  /// El administrador registra que ya le pagó al local lo de sus tarjetas canjeadas.
  Future<void> settle(String businessId, {String? note}) async {
    await _api.post('card-sales/admin/payouts/$businessId', body: {
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<void> markRefunded(String purchaseId, {String? note}) async {
    await _api.post('card-sales/admin/refunds/$purchaseId', body: {
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }
}

final cardSalesRepositoryProvider = Provider<CardSalesRepository>((ref) => CardSalesRepository());

final cardSalesRulesProvider = FutureProvider.autoDispose<CardSalesRules>(
  (ref) => ref.watch(cardSalesRepositoryProvider).rules(),
);

/// Las tarjetas en venta del cliente.
final cardOffersProvider = FutureProvider.autoDispose<List<Campaign>>(
  (ref) => ref.watch(cardSalesRepositoryProvider).offers(),
);

/// Los comprobantes de transferencia por revisar (administrador).
final cardReviewsProvider = FutureProvider.autoDispose<List<CardReview>>(
  (ref) => ref.watch(cardSalesRepositoryProvider).reviews(),
);

final mySalesProvider = FutureProvider.autoDispose<SalesSummary>(
  (ref) => ref.watch(cardSalesRepositoryProvider).mySales(),
);

final cardPayoutsProvider = FutureProvider.autoDispose<PayoutsOverview>(
  (ref) => ref.watch(cardSalesRepositoryProvider).payouts(),
);
