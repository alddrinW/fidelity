import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/my_cards_repository.dart';
import '../../../core/services/realtime_sync_service.dart';

final myCardsRepositoryProvider = Provider<MyCardsRepository>((ref) {
  return MyCardsRepository();
});

class MyCardsState {
  final bool isLoading;
  final List<Map<String, dynamic>> cards;
  final String userName;
  final String? avatarUrl;
  final String? error;
  final DateTime? sessionLastViewedAt;

  MyCardsState({
    this.isLoading = true,
    this.cards = const [],
    this.userName = '',
    this.avatarUrl,
    this.error,
    this.sessionLastViewedAt,
  });

  MyCardsState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? cards,
    String? userName,
    String? avatarUrl,
    String? error,
    DateTime? sessionLastViewedAt,
  }) {
    return MyCardsState(
      isLoading: isLoading ?? this.isLoading,
      cards: cards ?? this.cards,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      error: error,
      sessionLastViewedAt: sessionLastViewedAt ?? this.sessionLastViewedAt,
    );
  }
}

class MyCardsNotifier extends Notifier<MyCardsState> {
  late MyCardsRepository _repository;
  StreamSubscription? _cardsSub;
  StreamSubscription? _scansSub;

  void Function()? onCardCompleted;
  void Function()? onPointEarned;

  Timer? _refreshDebounce;

  @override
  MyCardsState build() {
    _repository = ref.watch(myCardsRepositoryProvider);
    Future.microtask(() => _loadInitialData());

    ref.onDispose(() {
      _refreshDebounce?.cancel();
      _cardsSub?.cancel();
      _scansSub?.cancel();
    });

    return MyCardsState();
  }

  void scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 350), () {
      refreshCards(silent: true);
    });
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastViewedStr = prefs.getString('cards_last_viewed_at');
      DateTime? sessionLastViewedAt;
      if (lastViewedStr != null) {
        sessionLastViewedAt = DateTime.tryParse(lastViewedStr);
      }

      final profile = await _repository.getUserProfile();
      final String userName = profile?['full_name'] ?? '';
      final String? avatarUrl = profile?['avatar_url'];

      final cards = await _repository.getLoyaltyCards();

      state = state.copyWith(
        isLoading: false,
        userName: userName,
        avatarUrl: avatarUrl,
        cards: cards,
        sessionLastViewedAt: sessionLastViewedAt,
      );

      _setupRealtimeSubscription();
      
      await prefs.setString('cards_last_viewed_at', DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refreshCards({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final cards = await _repository.getLoyaltyCards();
      final profile = await _repository.getUserProfile();
      final String userName = profile?['full_name'] ?? state.userName;
      final String? avatarUrl = profile?['avatar_url'] ?? state.avatarUrl;

      state = state.copyWith(
        isLoading: false,
        cards: cards,
        userName: userName,
        avatarUrl: avatarUrl,
      );
    } catch (e) {
      if (!silent) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  void _setupRealtimeSubscription() {
    _cardsSub?.cancel();
    _scansSub?.cancel();

    _cardsSub = RealtimeSyncService().onLoyaltyCardsChanged.listen((newData) {
      if (newData == null) return;
      scheduleRefresh();
    });

    _scansSub = RealtimeSyncService().onScansChanged.listen((newData) {
      if (newData == null) return;
      scheduleRefresh();
    });
  }
}

final myCardsProvider = NotifierProvider<MyCardsNotifier, MyCardsState>(() {
  return MyCardsNotifier();
});
