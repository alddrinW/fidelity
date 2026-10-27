import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/services/api_client.dart';

/// Qué pasa cuando el cliente toca un banner que subió el administrador.
enum BannerAction {
  none('none', 'Ninguna'),
  invite('invite', 'Invitar amigos'),
  weeklyGame('weekly_game', 'Juego de la semana'),
  offers('offers', 'Tarjetas en venta'),
  scan('scan', 'Escanear'),
  link('link', 'Abrir un enlace');

  final String code;

  /// Cómo se llama en el panel del administrador.
  final String label;

  const BannerAction(this.code, this.label);

  static BannerAction fromCode(Object? code) =>
      BannerAction.values.firstWhere((a) => a.code == code, orElse: () => BannerAction.none);
}

/// Un banner del administrador, tal como lo ve el cliente.
class ClientBanner {
  final String id;
  final String title;

  /// URL o data URI (la versión en inglés ya viene elegida por el servidor).
  final String imageUrl;
  final BannerAction action;
  final String? linkUrl;

  /// Si los bordes se funden con el fondo blanco de la pantalla.
  final bool blendWhite;

  const ClientBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.action = BannerAction.none,
    this.linkUrl,
    this.blendWhite = true,
  });

  factory ClientBanner.fromJson(Map<String, dynamic> json) => ClientBanner(
        id: json['id'].toString(),
        title: json['title']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString() ?? '',
        action: BannerAction.fromCode(json['action']),
        linkUrl: json['linkUrl']?.toString(),
        blendWhite: json['blendWhite'] != false,
      );
}

/// Un banner en el panel del administrador (con todo lo que puede cambiar).
class AdminBanner {
  final String id;
  final String title;
  final String imageUrl;
  final String? imageUrlEn;
  final BannerAction action;
  final String? linkUrl;
  final bool blendWhite;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const AdminBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.imageUrlEn,
    this.action = BannerAction.none,
    this.linkUrl,
    this.blendWhite = true,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
  });

  factory AdminBanner.fromJson(Map<String, dynamic> json) => AdminBanner(
        id: json['id'].toString(),
        title: json['title']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString() ?? '',
        imageUrlEn: json['imageUrlEn']?.toString(),
        action: BannerAction.fromCode(json['action']),
        linkUrl: json['linkUrl']?.toString(),
        blendWhite: json['blendWhite'] != false,
        isActive: json['isActive'] != false,
        startsAt: DateTime.tryParse('${json['startsAt'] ?? ''}')?.toLocal(),
        endsAt: DateTime.tryParse('${json['endsAt'] ?? ''}')?.toLocal(),
      );

  /// ¿Se está viendo ahora? (activo y dentro de su horario).
  bool isLiveAt(DateTime now) =>
      isActive && (startsAt == null || !startsAt!.isAfter(now)) && (endsAt == null || endsAt!.isAfter(now));
}

class BannersRepository {
  final ApiClient _api = ApiClient();

  /// Los banners que ve el cliente (con la imagen en el idioma de la app).
  Future<List<ClientBanner>> forClient(AppLanguage language) async {
    final data = await _api.get('banners', queryParams: {'lang': language.code});
    return ((data as List?) ?? const []).map((b) => ClientBanner.fromJson(Map<String, dynamic>.from(b as Map))).toList();
  }

  Future<List<AdminBanner>> all() async {
    final data = await _api.get('banners/admin');
    return ((data as List?) ?? const []).map((b) => AdminBanner.fromJson(Map<String, dynamic>.from(b as Map))).toList();
  }

  Future<void> create(Map<String, dynamic> body) => _api.post('banners/admin', body: body);

  Future<void> update(String id, Map<String, dynamic> body) => _api.patch('banners/admin/$id', body: body);

  Future<void> remove(String id) => _api.delete('banners/admin/$id');

  /// Guarda el orden: los id de todos los banners, del primero al último.
  Future<void> reorder(List<String> ids) => _api.put('banners/admin/order', body: {'ids': ids});
}

final bannersRepositoryProvider = Provider<BannersRepository>((ref) => BannersRepository());

/// Los banners del administrador para el inicio del cliente.
final clientBannersProvider = FutureProvider.autoDispose<List<ClientBanner>>(
  (ref) => ref.watch(bannersRepositoryProvider).forClient(ref.watch(languageProvider)),
);

final adminBannersProvider = FutureProvider.autoDispose<List<AdminBanner>>(
  (ref) => ref.watch(bannersRepositoryProvider).all(),
);
