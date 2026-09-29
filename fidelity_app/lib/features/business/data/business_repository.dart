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

  Future<String?> uploadLogo({
    required String userId,
    required List<int> fileBytes,
    required String fileExt,
  }) async {
    // Para simplificar y unificar, podemos enviar base64 data uri o guardar URL
    return null;
  }

  Future<String> createBusiness({
    required String userId,
    required String name,
    String? description,
    String? logoUrl,
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
      if (description != null && description.isNotEmpty) 'description': description.trim(),
      if (logoUrl != null && logoUrl.isNotEmpty) 'logoUrl': logoUrl,
      if (address != null && address.isNotEmpty) 'address': address.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (categoryId != null) 'categoryId': int.tryParse(categoryId),
      'rewardDescription': rewardDescription.trim(),
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
