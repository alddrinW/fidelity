import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_profile_repository.dart';
import '../../auth/data/auth_repository.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository();
});

class UserProfileState {
  final bool isLoading;
  final String fullName;
  final String phone;
  final String? avatarUrl;
  final String? error;
  final String? email;

  UserProfileState({
    this.isLoading = true,
    this.fullName = '',
    this.phone = '',
    this.avatarUrl,
    this.error,
    this.email,
  });

  UserProfileState copyWith({
    bool? isLoading,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? error,
    String? email,
  }) {
    return UserProfileState(
      isLoading: isLoading ?? this.isLoading,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      error: error,
      email: email ?? this.email,
    );
  }
}

class UserProfileNotifier extends Notifier<UserProfileState> {
  late UserProfileRepository _repository;

  @override
  UserProfileState build() {
    _repository = ref.watch(userProfileRepositoryProvider);
    final user = ref.watch(authRepositoryProvider).currentUser;
    Future.microtask(() => _loadProfile());
    return UserProfileState(
      email: user?.email,
      fullName: user?.fullName ?? '',
      phone: user?.phone ?? '',
      avatarUrl: user?.avatarUrl,
    );
  }

  Future<void> _loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) return;
      final profile = await _repository.getProfile(user.id) ?? {};
      state = state.copyWith(
        isLoading: false,
        fullName: profile['full_name'] ?? '',
        phone: profile['phone'] ?? '',
        avatarUrl: profile['avatar_url'],
        email: profile['email'] ?? user.email,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> saveProfile({
    required String fullName,
    required String phone,
    String? avatarDataUri,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) return false;
      await _repository.updateProfile(
        userId: user.id,
        fullName: fullName,
        phone: phone,
        avatarDataUri: avatarDataUri,
      );
      await _loadProfile();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) return false;
      await _repository.deleteAccount(user.id);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfileState>(() {
  return UserProfileNotifier();
});
