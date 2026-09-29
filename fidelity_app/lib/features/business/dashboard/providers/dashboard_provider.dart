import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/realtime_sync_service.dart';
import '../../../auth/data/auth_repository.dart';
import '../data/dashboard_repository.dart';

class DashboardState {
  final bool isLoading;
  final String? error;
  final String? toastMessage;
  final bool toastIsError;
  final Map<String, dynamic>? business;
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> pendingScans;
  final List<Map<String, dynamic>> pendingRewards;
  final String ownerName;

  DashboardState({
    this.isLoading = true,
    this.error,
    this.toastMessage,
    this.toastIsError = false,
    this.business,
    this.customers = const [],
    this.pendingScans = const [],
    this.pendingRewards = const [],
    this.ownerName = '',
  });

  DashboardState copyWith({
    bool? isLoading,
    String? error,
    String? toastMessage,
    bool? toastIsError,
    Map<String, dynamic>? business,
    List<Map<String, dynamic>>? customers,
    List<Map<String, dynamic>>? pendingScans,
    List<Map<String, dynamic>>? pendingRewards,
    String? ownerName,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      toastMessage: toastMessage,
      toastIsError: toastIsError ?? false,
      business: business ?? this.business,
      customers: customers ?? this.customers,
      pendingScans: pendingScans ?? this.pendingScans,
      pendingRewards: pendingRewards ?? this.pendingRewards,
      ownerName: ownerName ?? this.ownerName,
    );
  }
}

class DashboardNotifier extends Notifier<DashboardState> {
  StreamSubscription? _scansSub;
  StreamSubscription? _rewardsSub;
  StreamSubscription? _loyaltyCardsSub;

  Timer? _reloadDebounce;
  DateTime? _lastLoadedAt;

  @override
  DashboardState build() {
    Future.microtask(() => loadData());

    ref.onDispose(() {
      _reloadDebounce?.cancel();
      _scansSub?.cancel();
      _rewardsSub?.cancel();
      _loyaltyCardsSub?.cancel();
    });

    return DashboardState();
  }

  void _scheduleReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 350), () {
      loadData(silent: true);
    });
  }

  void reloadIfStale({Duration maxAge = const Duration(seconds: 20)}) {
    if (state.isLoading) return;
    final last = _lastLoadedAt;
    if (last == null || DateTime.now().difference(last) > maxAge) {
      _scheduleReload();
    }
  }

  Future<void> loadData({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final repo = ref.read(dashboardRepositoryProvider);
      final user = ref.read(authRepositoryProvider).currentUser;

      if (user == null) {
        state = state.copyWith(isLoading: false, error: 'Usuario no autenticado');
        return;
      }

      final ownerName = user.fullName;
      final business = await repo.fetchBusiness(user.id);

      if (business == null) {
        state = state.copyWith(
          isLoading: false,
          business: null,
          ownerName: ownerName,
        );
        return;
      }

      final businessId = business['id'] as String;

      final results = await Future.wait([
        repo.fetchCustomers(businessId),
        repo.fetchPendingScans(businessId),
        repo.fetchPendingRewards(businessId),
      ]);

      state = state.copyWith(
        isLoading: false,
        business: business,
        customers: results[0],
        pendingScans: results[1],
        pendingRewards: results[2],
        ownerName: ownerName,
      );

      _lastLoadedAt = DateTime.now();
      _setupRealtimeSubscription(businessId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _setupRealtimeSubscription(String businessId) {
    _scansSub?.cancel();
    _rewardsSub?.cancel();
    _loyaltyCardsSub?.cancel();

    RealtimeSyncService().joinBusiness(businessId);

    _scansSub = RealtimeSyncService().onScansChanged.listen((_) => _scheduleReload());
    _rewardsSub = RealtimeSyncService().onRewardsChanged.listen((_) => _scheduleReload());
    _loyaltyCardsSub = RealtimeSyncService().onLoyaltyCardsChanged.listen((_) => _scheduleReload());
  }

  Future<void> addManualPoints(String userId, int points) async {
    final businessId = state.business?['id'];
    if (businessId == null) return;

    try {
      await ref.read(dashboardRepositoryProvider).addManualPoints(
        userId: userId,
        businessId: businessId,
        points: points,
      );
      state = state.copyWith(toastMessage: 'Puntos agregados exitosamente', toastIsError: false);
      _scheduleReload();
    } catch (e) {
      if (e.toString().contains('PENDING_REWARD')) {
        state = state.copyWith(toastMessage: 'ERROR_PENDING_REWARD', toastIsError: true);
      } else {
        state = state.copyWith(toastMessage: 'Error al agregar puntos', toastIsError: true);
      }
    }
  }

  Future<void> approveScan(String scanId, String loyaltyCardId) async {
    try {
      final rewardGenerated = await ref.read(dashboardRepositoryProvider).approveScan(
        scanId: scanId,
        loyaltyCardId: loyaltyCardId,
      );
      
      state = state.copyWith(
        toastMessage: rewardGenerated ? 'Escaneo aprobado. ¡Premio generado!' : 'Escaneo aprobado',
        toastIsError: false,
      );
      _scheduleReload();
    } catch (e) {
      state = state.copyWith(toastMessage: 'Error: $e', toastIsError: true);
    }
  }

  Future<void> rejectScan(String scanId) async {
    try {
      await ref.read(dashboardRepositoryProvider).rejectScan(scanId);
      state = state.copyWith(toastMessage: 'Escaneo rechazado', toastIsError: false);
      _scheduleReload();
    } catch (e) {
      state = state.copyWith(toastMessage: 'Error: $e', toastIsError: true);
    }
  }

  Future<void> redeemReward(String userId, String cardId) async {
    final businessId = state.business?['id'];
    if (businessId == null) return;

    try {
      await ref.read(dashboardRepositoryProvider).redeemReward(
        userId: userId,
        businessId: businessId,
        cardId: cardId,
      );
      state = state.copyWith(toastMessage: 'Premio canjeado', toastIsError: false);
      _scheduleReload();
    } catch (e) {
      state = state.copyWith(toastMessage: 'Error: $e', toastIsError: true);
    }
  }
}

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(() {
  return DashboardNotifier();
});
