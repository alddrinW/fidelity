import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/services/api_client.dart';
import '../../core/services/export_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/image_source.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/person_avatar.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'data/admin_date_filter.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/export_preview_dialog.dart';
import '../../core/l10n/tr_text.dart';

class AdminBusinessesScreen extends StatefulWidget {
  const AdminBusinessesScreen({super.key});

  @override
  State<AdminBusinessesScreen> createState() => _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends State<AdminBusinessesScreen> {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _businesses = [];
  String _searchQuery = '';
  // 'all' | 'pending' (por activar) | 'active'
  String _statusFilter = 'all';
  AdminDateFilter _filter = AdminDateFilter.all;
  DateTimeRange? _customRange;

  static const _statusOptions = <(String, String)>[
    ('all', 'Todos'),
    ('pending', 'Por activar'),
    ('active', 'Activos'),
  ];

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.get('businesses', queryParams: {'all': 'true'});
      var list = response is List
          ? List<Map<String, dynamic>>.from(response)
          : <Map<String, dynamic>>[];

      final range = AdminDateRange.resolve(_filter, custom: _customRange);
      if (range != null) {
        list = list.where((b) {
          final created = DateTime.tryParse('${b['createdAt'] ?? b['created_at'] ?? ''}');
          return created != null && range.contains(created);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _businesses = _normalizeBusinesses(list);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading businesses: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        DashboardAnimatedToast.show(context, 'Error al cargar negocios', isError: true);
      }
    }
  }

  List<Map<String, dynamic>> _normalizeBusinesses(List<Map<String, dynamic>> raw) {
    return raw.map((b) {
      final category = b['categoryRef'] ?? b['business_categories'] ?? {};
      final owner = b['owner'] ?? b['profiles'] ?? {};
      final rawCards = (b['loyaltyCards'] ?? b['loyalty_cards'] ?? []) as List;
      final loyaltyCards = rawCards.map((card) {
        final u = card['user'] ?? card['profiles'] ?? {};
        return {
          'profiles': {
            'full_name': u['fullName'] ?? u['full_name'],
            'email': u['email'],
            'phone': u['phone'],
            'avatar_url': u['avatarUrl'] ?? u['avatar_url'],
            'is_demo': u['isDemo'] ?? u['is_demo'] ?? false,
          },
        };
      }).toList();

      return {
        ...b,
        'id': b['id'],
        'name': b['name'],
        'logo_url': b['logoUrl'] ?? b['logo_url'],
        'is_active': b['isActive'] ?? b['is_active'] ?? false,
        'is_demo': b['isDemo'] ?? b['is_demo'] ?? false,
        'created_at': b['createdAt'] ?? b['created_at'],
        'reward_description': b['rewardDescription'] ?? b['reward_description'],
        'points_required': b['pointsRequired'] ?? b['points_required'],
        'business_categories': {
          'name': category['name'] ?? b['category'] ?? 'Otra',
        },
        'profiles': {
          'full_name': owner['fullName'] ?? owner['full_name'] ?? 'Desconocido',
          'email': owner['email'] ?? 'Sin correo',
          'phone': owner['phone'] ?? 'Sin celular',
          'is_demo': owner['isDemo'] ?? owner['is_demo'] ?? false,
        },
        'loyalty_cards': loyaltyCards,
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredBusinesses {
    final query = _searchQuery.toLowerCase();
    return _businesses.where((b) {
      final isActive = b['is_active'] == true;
      if (_statusFilter == 'pending' && isActive) return false;
      if (_statusFilter == 'active' && !isActive) return false;
      if (query.isEmpty) return true;
      final name = (b['name'] ?? '').toString().toLowerCase();
      final owner = (b['profiles']?['full_name'] ?? '').toString().toLowerCase();
      final email = (b['profiles']?['email'] ?? '').toString().toLowerCase();
      return name.contains(query) || owner.contains(query) || email.contains(query);
    }).toList();
  }

  /// Activar o desactivar una cuenta pide confirmación: activar equivale a
  /// confirmar que se validó el pago del registro del negocio.
  void _confirmToggle(Map<String, dynamic> business) {
    final name = '${business['name'] ?? 'el negocio'}';
    final isActive = business['is_active'] == true;

    showDialog(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: isActive ? Icons.block_rounded : Icons.verified_rounded,
        title: isActive ? '¿Desactivar cuenta?' : '¿Activar cuenta?',
        message: isActive
            ? '$name dejará de recibir escaneos hasta que vuelvas a activarla.'
            : 'Confirma que ya validaste el pago del registro de $name. '
                'Su dueño podrá empezar a usar Fidelity.',
        primaryLabel: isActive ? 'Desactivar' : 'Sí, activar',
        onPrimary: () => _toggleBusinessStatus(business['id'] as String, isActive),
        secondaryLabel: 'Cancelar',
      ),
    );
  }

  Future<void> _toggleBusinessStatus(String id, bool currentStatus) async {
    void setStatus(bool value) {
      final index = _businesses.indexWhere((b) => b['id'] == id);
      if (index != -1) _businesses[index]['is_active'] = value;
    }

    // Actualización optimista; se revierte si el servidor rechaza el cambio.
    setState(() => setStatus(!currentStatus));
    try {
      await _apiClient.patch('businesses/$id/status', body: {'isActive': !currentStatus});
      if (mounted) {
        DashboardAnimatedToast.show(
          context,
          currentStatus ? 'Cuenta desactivada' : 'Cuenta activada',
        );
      }
    } catch (e) {
      debugPrint('Error toggling status: $e');
      if (!mounted) return;
      setState(() => setStatus(currentStatus));
      DashboardAnimatedToast.show(context, 'Error al cambiar el estado', isError: true);
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (_) => ExportPreviewDialog(
        data: _filteredBusinesses,
        entity: ExportEntity.businesses,
        exportService: AppExportService(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final businesses = _filteredBusinesses;

    return AdminPageFrame(
      title: 'Negocios',
      bottom: AdminExportButton(
        onPressed: _isLoading || businesses.isEmpty ? null : _showExportDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _loadBusinesses,
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
                      hint: 'Nombre, dueño o correo',
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _statusOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final (value, label) = _statusOptions[index];
                        return AdminFilterPill(
                          label: label,
                          selected: _statusFilter == value,
                          onTap: () => setState(() => _statusFilter = value),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  AdminDateFilterBar(
                    selected: _filter,
                    customRange: _customRange,
                    onChanged: (filter, range) {
                      setState(() {
                        _filter = filter;
                        _customRange = range;
                      });
                      _loadBusinesses();
                    },
                  ),
                  if (!_isLoading)
                    AdminCountLabel(
                      '${businesses.length} ${businesses.length == 1 ? 'negocio' : 'negocios'}',
                    ),
                ],
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(hasScrollBody: false, child: AdminLoading())
            else if (businesses.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  title: _searchQuery.isEmpty ? 'Sin negocios' : 'Sin resultados',
                  message: _searchQuery.isEmpty
                      ? 'No hay negocios registrados en este periodo.'
                      : 'Ningún negocio coincide con tu búsqueda.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                sliver: SliverList.separated(
                  itemCount: businesses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final business = businesses[index];
                    return _BusinessCard(
                      business: business,
                      onToggle: () => _confirmToggle(business),
                    )
                        .animate(delay: Duration(milliseconds: 40 * (index.clamp(0, 8))))
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.06);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final Map<String, dynamic> business;
  final VoidCallback onToggle;

  const _BusinessCard({required this.business, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final owner = (business['profiles'] ?? {}) as Map;
    final isActive = business['is_active'] == true;
    final logo = imageProviderFromUrl(business['logo_url']?.toString());
    final clients = List<Map<String, dynamic>>.from(business['loyalty_cards'] ?? []);
    final createdAt = business['created_at']?.toString();

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                  image: logo == null
                      ? null
                      : DecorationImage(image: logo, fit: BoxFit.cover),
                ),
                child: logo == null
                    ? const Icon(Icons.storefront_rounded, color: AppColors.placeholderIcon)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (business['name'] ?? 'Sin nombre').toString().toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(size: 24),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AppChip(
                          label: '${business['business_categories']?['name'] ?? 'Otra'}',
                          style: AppChipStyle.outline,
                        ),
                        if (!isActive)
                          const AppChip(label: 'Por activar')
                        else
                          const AppChip(label: 'Activo', style: AppChipStyle.dark),
                        if (business['is_demo'] == true)
                          const AppChip(label: 'Demo', style: AppChipStyle.dark),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AdminInfoLine(
            icon: Icons.person_outline_rounded,
            text: '${owner['full_name'] ?? 'Desconocido'}',
            strong: true,
          ),
          AdminInfoLine(icon: Icons.mail_outline_rounded, text: '${owner['email'] ?? 'Sin correo'}'),
          AdminInfoLine(icon: Icons.phone_outlined, text: '${owner['phone'] ?? 'Sin celular'}'),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CAMPAÑA', style: AppTypography.label(size: 12, tracking: 4)),
                const SizedBox(height: 8),
                _CampaignRow(
                  label: 'Premio',
                  value: '${business['reward_description'] ?? 'No definido'}',
                ),
                _CampaignRow(label: 'Puntos', value: '${business['points_required'] ?? 0} pts'),
                _CampaignRow(
                  label: 'Desde',
                  value: createdAt == null || createdAt.isEmpty
                      ? 'N/A'
                      : EcuadorDateUtils.formatEcuadorDate(createdAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!isActive) ...[
            AppPrimaryButton(label: 'Activar cuenta', onPressed: onToggle),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 8),
              child: Text(
                'Actívala cuando valides el pago del registro.',
                style: AppTypography.body(
                  size: 13,
                  weight: FontWeight.w300,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: AppTextAction(label: 'Desactivar cuenta', onPressed: onToggle),
            ),
          const SizedBox(height: 8),
          if (clients.isEmpty)
            Text(
              'Aún no tiene clientes',
              style: AppTypography.body(
                size: 14,
                weight: FontWeight.w300,
                color: AppColors.textSecondary,
              ),
            )
          else
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                iconColor: AppColors.black,
                collapsedIconColor: AppColors.black,
                title: Text(
                  '${clients.length} ${clients.length == 1 ? 'CLIENTE' : 'CLIENTES'}',
                  style: AppTypography.label(size: 12, tracking: 4),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: clients.map((c) {
                        final p = (c['profiles'] ?? {}) as Map;
                        final name = '${p['full_name'] ?? p['email'] ?? 'Desconocido'}';
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PersonAvatar(
                              name: name,
                              avatarUrl: p['avatar_url']?.toString(),
                              size: 32,
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(size: 14, weight: FontWeight.w300),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CampaignRow extends StatelessWidget {
  final String label;
  final String value;

  const _CampaignRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: AppTypography.body(
                size: 14,
                weight: FontWeight.w300,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: AppTypography.body(size: 14, weight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
