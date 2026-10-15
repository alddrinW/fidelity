import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/services/api_client.dart';
import '../../core/services/export_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/person_avatar.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'data/admin_date_filter.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/export_preview_dialog.dart';
import '../../core/l10n/tr_text.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _roleFilter = 'all';
  String _searchQuery = '';
  AdminDateFilter _filter = AdminDateFilter.all;
  DateTimeRange? _customRange;

  static const _roleOptions = <(String, String)>[
    ('all', 'Todos'),
    ('business', 'Negocios'),
    ('client', 'Clientes'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().get('admin/users', queryParams: {
        if (_roleFilter != 'all') 'role': _roleFilter,
      });

      final users = response is List
          ? response
              .map<Map<String, dynamic>>((u) => {
                    'id': u['id'],
                    'full_name': u['fullName'] ?? u['full_name'],
                    'email': u['email'],
                    'phone': u['phone'],
                    'avatar_url': u['avatarUrl'] ?? u['avatar_url'],
                    'role': u['role'],
                    'is_demo': u['isDemo'] ?? u['is_demo'] ?? false,
                    'created_at': u['createdAt'] ?? u['created_at'],
                    'businesses': u['businesses'] ?? [],
                  })
              .toList()
          : <Map<String, dynamic>>[];

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        DashboardAnimatedToast.show(context, 'Error al cargar usuarios', isError: true);
      }
    }
  }

  /// Búsqueda y periodo se aplican aquí: el backend solo filtra por rol.
  List<Map<String, dynamic>> get _filteredUsers {
    final range = AdminDateRange.resolve(_filter, custom: _customRange);
    final query = _searchQuery.toLowerCase();

    return _users.where((u) {
      if (range != null) {
        final created = DateTime.tryParse('${u['created_at'] ?? ''}');
        if (created == null || !range.contains(created)) return false;
      }
      if (query.isEmpty) return true;
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  void _showExportDialog(List<Map<String, dynamic>> users) {
    showDialog(
      context: context,
      builder: (_) => ExportPreviewDialog(
        data: users,
        entity: ExportEntity.users,
        exportService: AppExportService(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;

    return AdminPageFrame(
      title: 'Usuarios',
      bottom: AdminExportButton(
        onPressed: _isLoading || users.isEmpty ? null : () => _showExportDialog(users),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        color: AppColors.black,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: AdminSearchField(
                      controller: _searchController,
                      hint: 'Nombre o correo',
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _roleOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final (value, label) = _roleOptions[index];
                        return AdminFilterPill(
                          label: label,
                          selected: _roleFilter == value,
                          onTap: () {
                            setState(() => _roleFilter = value);
                            _loadUsers();
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  AdminDateFilterBar(
                    selected: _filter,
                    customRange: _customRange,
                    onChanged: (filter, range) => setState(() {
                      _filter = filter;
                      _customRange = range;
                    }),
                  ),
                  if (!_isLoading)
                    AdminCountLabel(
                      '${users.length} ${users.length == 1 ? 'usuario' : 'usuarios'}',
                    ),
                ],
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(hasScrollBody: false, child: AdminLoading())
            else if (users.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  title: _searchQuery.isEmpty ? 'Sin usuarios' : 'Sin resultados',
                  message: _searchQuery.isEmpty
                      ? 'No hay usuarios registrados con estos filtros.'
                      : 'Ningún usuario coincide con tu búsqueda.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                sliver: SliverList.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => _UserCard(user: users[index])
                      .animate(delay: Duration(milliseconds: 40 * (index.clamp(0, 8))))
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.06),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _UserCard({required this.user});

  static String _roleLabel(String? role) => switch (role) {
        'admin' => 'Administrador',
        'business' => 'Negocio',
        _ => 'Cliente',
      };

  @override
  Widget build(BuildContext context) {
    final name = (user['full_name'] ?? 'Sin nombre').toString();
    final role = user['role'] as String?;
    final phone = user['phone']?.toString();
    final businesses = (user['businesses'] as List?) ?? const [];
    final created = user['created_at']?.toString() ?? '';

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonAvatar(name: name, avatarUrl: user['avatar_url']?.toString()),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(size: 22),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppChip(
                      label: _roleLabel(role),
                      style: role == 'admin'
                          ? AppChipStyle.dark
                          : role == 'business'
                              ? AppChipStyle.pink
                              : AppChipStyle.outline,
                    ),
                    if (user['is_demo'] == true)
                      const AppChip(label: 'Demo', style: AppChipStyle.dark),
                  ],
                ),
                const SizedBox(height: 8),
                AdminInfoLine(
                  icon: Icons.mail_outline_rounded,
                  text: (user['email'] ?? 'Sin correo').toString(),
                ),
                if (phone != null && phone.isNotEmpty)
                  AdminInfoLine(icon: Icons.phone_outlined, text: phone),
                if (role == 'business' && businesses.isNotEmpty)
                  AdminInfoLine(
                    icon: Icons.storefront_rounded,
                    text: 'Dueño de ${businesses.first['name']}',
                    strong: true,
                  ),
                if (created.isNotEmpty)
                  AdminInfoLine(
                    icon: Icons.calendar_today_rounded,
                    text: 'Registro ${EcuadorDateUtils.formatEcuadorTime(created)}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
