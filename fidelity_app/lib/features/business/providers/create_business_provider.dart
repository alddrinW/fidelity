import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../data/business_repository.dart';

class CreateBusinessState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  CreateBusinessState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
  });

  CreateBusinessState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
  }) {
    return CreateBusinessState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class CreateBusinessNotifier extends Notifier<CreateBusinessState> {
  @override
  CreateBusinessState build() {
    return CreateBusinessState();
  }

  Future<void> submitBusiness({
    required String fullName,
    required String phone,
    XFile? logoFile,
    required String businessName,
    String? businessDescription,
    required String address,
    required double? latitude,
    required double? longitude,
    String? categoryId,
    required String rewardDescription,
    String? rewardLongDescription,
    required int pointsRequired,
  }) async {
    final authUser = ref.read(authRepositoryProvider).currentUser;

    if (authUser == null) {
      state = state.copyWith(error: 'Usuario no autenticado', isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final profileRepo = ref.read(userProfileRepositoryProvider);
      final businessRepo = ref.read(businessRepositoryProvider);

      // 1. Actualizar Perfil
      await profileRepo.updateProfile(
        userId: authUser.id,
        fullName: fullName.trim(),
        phone: phone.trim(),
      );

      // 2. Crear el negocio
      final businessId = await businessRepo.createBusiness(
        userId: authUser.id,
        name: businessName.trim(),
        description: businessDescription?.trim().isEmpty ?? true ? null : businessDescription!.trim(),
        address: address.trim().isEmpty ? null : address.trim(),
        latitude: latitude,
        longitude: longitude,
        categoryId: categoryId,
        rewardDescription: rewardDescription.trim(),
        rewardLongDescription:
            (rewardLongDescription?.trim().isEmpty ?? true) ? null : rewardLongDescription!.trim(),
        pointsRequired: pointsRequired,
      );

      // 3. Crear QR inicial
      await businessRepo.generateInitialQrCode(businessId);

      // 4. Refrescar el perfil de autenticación
      await ref.read(authRepositoryProvider).refreshProfile();

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final createBusinessProvider = NotifierProvider<CreateBusinessNotifier, CreateBusinessState>(() {
  return CreateBusinessNotifier();
});
