import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../../core/models/business_category.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository();
});

class BusinessRepository {
  final ApiClient _api = ApiClient();

  BusinessRepository();

  Future<List<BusinessCategory>> getCategories() async {
    final response = await _api.get('businesses/categories');
    if (response is! List) return [];
    return response.map((c) => BusinessCategory.fromJson(Map<String, dynamic>.from(c as Map))).toList();
  }

  /// Crea el negocio. [logoDataUri] es la imagen como data URI base64
  /// (ver `image_source.dart`).
  Future<String> createBusiness({
    required String name,
    required String phone,
    required String taxId,
    String? description,
    String? logoDataUri,
    String? address,
    double? latitude,
    double? longitude,
    String? categoryId,
    required String rewardDescription,
    String? rewardLongDescription,
    required int pointsRequired,
  }) async {
    final response = await _api.post('businesses', body: {
      'name': name.trim(),
      'phone': phone.trim(),
      'taxId': taxId.trim(),
      if (description != null && description.isNotEmpty) 'description': description.trim(),
      if (logoDataUri != null && logoDataUri.isNotEmpty) 'logoUrl': logoDataUri,
      if (address != null && address.isNotEmpty) 'address': address.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (categoryId != null) 'categoryId': int.tryParse(categoryId),
      'rewardDescription': rewardDescription.trim(),
      if (rewardLongDescription != null && rewardLongDescription.trim().isNotEmpty)
        'rewardLongDescription': rewardLongDescription.trim(),
      'pointsRequired': pointsRequired,
      'cooldownHours': 4,
    });

    if (response is Map<String, dynamic>) {
      final businessId = response['id']?.toString() ?? '';

      // Actualizar información local del usuario
      final current = Map<String, dynamic>.from(_api.currentUser ?? {});
      current['role'] = 'business';
      current['business_id'] = businessId;
      await _api.updateUser(current);

      return businessId;
    }
    throw ApiException('Error al crear negocio');
  }

  /// Actualiza los datos generales del negocio ("Mi negocio").
  /// [taxId] vacío no se envía; [logoDataUri] solo si el logo cambió.
  Future<void> updateBusinessData({
    required String businessId,
    required String name,
    required String phone,
    String? taxId,
    required String address,
    required double latitude,
    required double longitude,
    int? categoryId,
    String? logoDataUri,
  }) async {
    await _api.put('businesses/$businessId', body: {
      'name': name.trim(),
      'phone': phone.trim(),
      if (taxId != null && taxId.trim().isNotEmpty) 'taxId': taxId.trim(),
      'address': address.trim(),
      'latitude': latitude,
      'longitude': longitude,
      if (categoryId != null) 'categoryId': categoryId,
      if (logoDataUri != null) 'logoUrl': logoDataUri,
    });
  }

  /// Actualiza el premio y los puntos requeridos ("Mi campaña").
  Future<void> updateCampaign({
    required String businessId,
    required String rewardDescription,
    required String rewardLongDescription,
    required int pointsRequired,
  }) async {
    await _api.put('businesses/$businessId', body: {
      'rewardDescription': rewardDescription.trim(),
      'rewardLongDescription': rewardLongDescription.trim(),
      'pointsRequired': pointsRequired,
    });
  }

  Future<void> generateInitialQrCode(String businessId) async {
    try {
      await _api.post('qr-codes', body: {
        'businessId': businessId,
        'label': 'QR Principal',
      });
    } catch (_) {}
  }

  Future<void> updateBusinessRoleInAuth(String businessId) async {
    // Ya gestionado por createBusiness en backend
  }
}
