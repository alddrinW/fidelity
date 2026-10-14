import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
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

  /// Crea el negocio con su campaña y genera el QR inicial. El nombre y el
  /// teléfono del dueño ya se guardaron al registrarse; se editan después
  /// desde "Ajustar mis datos".
  Future<void> submitBusiness({
    String? logoDataUri,
    required String businessName,
    required String phone,
    required String taxId,
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
      final businessRepo = ref.read(businessRepositoryProvider);

      // 1. Crear el negocio
      final businessId = await businessRepo.createBusiness(
        name: businessName,
        phone: phone,
        taxId: taxId,
        logoDataUri: logoDataUri,
        address: address.trim().isEmpty ? null : address.trim(),
        latitude: latitude,
        longitude: longitude,
        categoryId: categoryId,
        rewardDescription: rewardDescription,
        rewardLongDescription: rewardLongDescription,
        pointsRequired: pointsRequired,
      );

      // 2. Crear QR inicial
      await businessRepo.generateInitialQrCode(businessId);

      // 3. Refrescar el perfil de autenticación
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
