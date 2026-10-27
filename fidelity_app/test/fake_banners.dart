import 'package:fidelity_app/features/banners/data/banners_repository.dart';

/// Un servidor de banners de mentira para las pruebas: devuelve lo que se le da y
/// anota lo que el administrador hace.
class FakeBannersRepository extends BannersRepository {
  List<ClientBanner> client;
  List<AdminBanner> admin;
  final List<Map<String, dynamic>> created = [];
  final Map<String, Map<String, dynamic>> updated = {};
  final List<String> removed = [];
  final List<List<String>> reorders = [];

  /// El idioma con que el cliente pidió los banners.
  final List<String> languages = [];

  FakeBannersRepository({this.client = const [], this.admin = const []});

  @override
  Future<List<ClientBanner>> forClient(language) async {
    languages.add(language.code);
    return client;
  }

  @override
  Future<List<AdminBanner>> all() async => admin;

  @override
  Future<void> create(Map<String, dynamic> body) async => created.add(body);

  @override
  Future<void> update(String id, Map<String, dynamic> body) async => updated[id] = body;

  @override
  Future<void> remove(String id) async => removed.add(id);

  @override
  Future<void> reorder(List<String> ids) async => reorders.add(ids);
}
