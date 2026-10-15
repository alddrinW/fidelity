import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'data/admin_date_filter.dart';
import 'widgets/admin_widgets.dart';
import '../../core/l10n/tr_text.dart';

class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  static const int _pageSize = 20;

  final ApiClient _apiClient = ApiClient();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _businessesList = [];

  AdminDateFilter _filter = AdminDateFilter.all;
  DateTimeRange? _customRange;
  String _selectedBusinessId = 'all';

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _loadActivity();
    _scrollController.addListener(() {
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 200 &&
          !_isFetchingMore &&
          !_isLoading &&
          _hasMore) {
        _fetchMoreActivity();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    try {
      final response = await _apiClient.get('businesses', queryParams: {'all': 'true'});
      if (mounted && response is List) {
        setState(() => _businessesList = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      debugPrint('Error loading businesses: $e');
    }
  }

  /// El backend no pagina por cursor: pide los primeros [limit] registros.
  Future<List<Map<String, dynamic>>> _fetch(int limit) async {
    final range = AdminDateRange.resolve(_filter, custom: _customRange);
    final response = await _apiClient.get('admin/activity', queryParams: {
      'limit': '$limit',
      if (range != null) 'startDate': range.start.toIso8601String(),
      if (range != null) 'endDate': range.end.toIso8601String(),
      if (_selectedBusinessId != 'all') 'businessId': _selectedBusinessId,
    });
    final list = response is List
        ? List<Map<String, dynamic>>.from(response)
        : <Map<String, dynamic>>[];
    return list.map(_normalize).toList();
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> s) {
    final user = (s['user'] ?? s['profiles'] ?? {}) as Map;
    final business = (s['business'] ?? s['businesses'] ?? {}) as Map;
    return {
      'date': s['scannedAt'] ?? s['scanned_at'],
      'user_name': user['fullName'] ?? user['full_name'] ?? user['email'],
      'business_name': business['name'],
      'status': s['status'] ?? 'pending',
      'is_demo': s['isDemo'] ?? s['is_demo'] ?? false,
      // Un escaneo sin código QR fue un punto regalado por el dueño del local.
      'is_gifted': (s['qrCodeId'] ?? s['qr_code_id']) == null,
    };
  }

  Future<void> _loadActivity() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMore = true;
      _activities = [];
    });
    try {
      final items = await _fetch(_pageSize);
      if (mounted) {
        setState(() {
          _activities = items;
          _hasMore = items.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading activities: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        DashboardAnimatedToast.show(context, 'Error al cargar la actividad', isError: true);
      }
    }
  }

  Future<void> _fetchMoreActivity() async {
    setState(() => _isFetchingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final totalToFetch = (nextPage + 1) * _pageSize;
      final items = await _fetch(totalToFetch);
      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _activities = items;
          _hasMore = items.length == totalToFetch;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more activities: $e');
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: 'Actividad',
      body: RefreshIndicator(
        onRefresh: _loadActivity,
        color: AppColors.black,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  AdminDateFilterBar(
                    selected: _filter,
                    customRange: _customRange,
                    onChanged: (filter, range) {
                      setState(() {
                        _filter = filter;
                        _customRange = range;
                      });
                      _loadActivity();
                    },
                  ),
                  if (_businessesList.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: AdminSelectField(
                        icon: Icons.storefront_rounded,
                        title: 'Local',
                        selected: _selectedBusinessId,
                        options: [
                          ('all', 'Todos los locales'),
                          for (final b in _businessesList)
                            ('${b['id']}', '${b['name'] ?? 'Desconocido'}'),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedBusinessId = value);
                          _loadActivity();
                        },
                      ),
                    ),
                  if (!_isLoading)
                    AdminCountLabel(
                      '${_activities.length} ${_activities.length == 1 ? 'registro' : 'registros'}',
                    ),
                ],
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(hasScrollBody: false, child: AdminLoading())
            else if (_activities.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  title: 'Sin actividad',
                  message: 'No hay escaneos en este periodo.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                sliver: SliverList.separated(
                  itemCount: _activities.length + (_isFetchingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == _activities.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: AdminLoading(),
                      );
                    }
                    return _ActivityCard(activity: _activities[index])
                        .animate(delay: Duration(milliseconds: 30 * (index % 8)))
                        .fadeIn(duration: 250.ms);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;

  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final isGifted = activity['is_gifted'] == true;
    final status = activity['status'] as String;
    final date = activity['date']?.toString();
    final userName = activity['user_name'] ?? 'Usuario desconocido';
    final action = isGifted ? 'recibió un punto de regalo' : 'escaneó QR';

    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGifted ? AppColors.pink : AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGifted ? Icons.redeem_rounded : Icons.qr_code_scanner_rounded,
              color: AppColors.black,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$userName $action',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(size: 15, weight: FontWeight.w500),
                ),
                AdminInfoLine(
                  icon: Icons.storefront_rounded,
                  text: '${activity['business_name'] ?? 'Negocio desconocido'}',
                ),
                AdminInfoLine(
                  icon: Icons.schedule_rounded,
                  text: date == null || date.isEmpty
                      ? 'Fecha desconocida'
                      : EcuadorDateUtils.formatEcuadorTime(date),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppChip(
                label: switch (status) {
                  'approved' => 'Aprobado',
                  'rejected' => 'Rechazado',
                  _ => 'Pendiente',
                },
                style: switch (status) {
                  'approved' => AppChipStyle.dark,
                  'rejected' => AppChipStyle.outline,
                  _ => AppChipStyle.pink,
                },
              ),
              if (activity['is_demo'] == true) ...[
                const SizedBox(height: 6),
                const AppChip(label: 'Demo', style: AppChipStyle.outline),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
