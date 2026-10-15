import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';

/// Un negocio (o sucursal) del dueño con sus cifras: la matriz de control.
class BusinessOverview {
  final String id;
  final String name;
  final String? logoUrl;

  /// Id del negocio principal si esto es una sucursal.
  final String? parentId;
  final bool isActive;
  final int customers;
  final int scansToday;
  final int scansTotal;
  final int pendingScans;
  final int approvers;

  const BusinessOverview({
    required this.id,
    required this.name,
    required this.isActive,
    this.logoUrl,
    this.parentId,
    this.customers = 0,
    this.scansToday = 0,
    this.scansTotal = 0,
    this.pendingScans = 0,
    this.approvers = 0,
  });

  bool get isBranch => parentId != null;

  factory BusinessOverview.fromJson(Map<String, dynamic> json) {
    int number(String key) => (json[key] as num?)?.toInt() ?? 0;
    return BusinessOverview(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Negocio',
      logoUrl: json['logoUrl']?.toString(),
      parentId: json['parentId']?.toString(),
      isActive: json['isActive'] == true,
      customers: number('customers'),
      scansToday: number('scansToday'),
      scansTotal: number('scansTotal'),
      pendingScans: number('pendingScans'),
      approvers: number('approvers'),
    );
  }

  /// Ordena los negocios principales primero, cada uno seguido de sus
  /// sucursales (las sucursales huérfanas van al final).
  static List<BusinessOverview> grouped(List<BusinessOverview> all) {
    final principals = all.where((b) => !b.isBranch).toList();
    final result = <BusinessOverview>[];
    for (final principal in principals) {
      result.add(principal);
      result.addAll(all.where((b) => b.parentId == principal.id));
    }
    final listed = result.map((b) => b.id).toSet();
    result.addAll(all.where((b) => !listed.contains(b.id)));
    return result;
  }
}

final branchesRepositoryProvider = Provider<BranchesRepository>((ref) => BranchesRepository());

final businessOverviewProvider = FutureProvider.autoDispose<List<BusinessOverview>>(
  (ref) => ref.watch(branchesRepositoryProvider).overview(),
);

class BranchesRepository {
  final ApiClient _api = ApiClient();

  Future<List<BusinessOverview>> overview() async {
    final response = await _api.get('businesses/my-businesses/overview');
    if (response is! List) return [];
    final list = response
        .map((b) => BusinessOverview.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList();
    return BusinessOverview.grouped(list);
  }
}
