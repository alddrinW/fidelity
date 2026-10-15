import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../payments/data/payments_repository.dart';
import '../data/business_repository.dart';

class CreateBusinessState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  /// Orden de pago del negocio recién creado (para abrir PAGA YA).
  final PaymentOrder? createdPayment;

  CreateBusinessState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.createdPayment,
  });

  CreateBusinessState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    PaymentOrder? createdPayment,
  }) {
    return CreateBusinessState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      createdPayment: createdPayment ?? this.createdPayment,
    );
  }
}

class CreateBusinessNotifier extends Notifier<CreateBusinessState> {
  @override
  CreateBusinessState build() {
    return CreateBusinessState();
  }

  /// Crea el negocio y genera el QR inicial. Un negocio nuevo no define su
  /// campaña aquí: la configura cuando su cuenta ya está activa. Una sucursal
  /// hereda la campaña del negocio principal. El nombre y el
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
    String? rewardDescription,
    String? rewardLongDescription,
    int? pointsRequired,
    String? parentId,
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
      final created = await businessRepo.createBusiness(
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
        parentId: parentId,
        selectAsCurrent: parentId == null,
      );

      // 2. Crear QR inicial
      await businessRepo.generateInitialQrCode(created.id);

      // 3. Refrescar el perfil de autenticación (un negocio nuevo lleva a la
      // pantalla de activación; una sucursal conserva el negocio actual)
      await ref.read(authRepositoryProvider).refreshProfile();

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        createdPayment: created.payment,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final createBusinessProvider = NotifierProvider<CreateBusinessNotifier, CreateBusinessState>(() {
  return CreateBusinessNotifier();
});
