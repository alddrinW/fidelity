import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/services/api_client.dart';
import '../../core/services/realtime_sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_pill_tab_bar.dart';
import '../../core/widgets/person_avatar.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'admin_user_rewards_detail_screen.dart';
import 'data/admin_date_filter.dart';
import 'widgets/admin_widgets.dart';
import '../../core/l10n/tr_text.dart';

class AdminRewardsScreen extends StatefulWidget {
  const AdminRewardsScreen({super.key});

  @override
  State<AdminRewardsScreen> createState() => _AdminRewardsScreenState();
}

class _AdminRewardsScreenState extends State<AdminRewardsScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _businessesList = [];
  List<Map<String, dynamic>> _allTransfers = [];
  List<Map<String, dynamic>> _userSummaries = [];

  String _selectedBusinessId = 'all';
  String _searchQuery = '';
  AdminDateFilter _filter = AdminDateFilter.all;
  DateTimeRange? _customRange;

  StreamSubscription<void>? _rewardsSub;
  StreamSubscription<void>? _transfersSub;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _loadRewards();

    _rewardsSub = RealtimeSyncService().onRewardsChanged.listen((_) {
      if (mounted) _loadRewards(silent: true);
    });
    _transfersSub = RealtimeSyncService().onRewardTransfersChanged.listen((_) {
      if (mounted) _loadRewards(silent: true);
    });
  }

  @override
  void dispose() {
    _rewardsSub?.cancel();
    _transfersSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    try {
      final response = await ApiClient().get('businesses', queryParams: {'all': 'true'});
      if (mounted && response is List) {
        setState(() => _businessesList = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      debugPrint('Error loading businesses: $e');
    }
  }

  /// Nombre legible de una persona del backend (camelCase o snake_case).
  static String? _personName(Map? person) {
    if (person == null) return null;
    final name = person['fullName'] ?? person['full_name'] ?? person['email'];
    return name?.toString();
  }

  Future<void> _loadRewards({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final range = AdminDateRange.resolve(_filter, custom: _customRange);

      final rewardsRaw = await ApiClient().get('admin/rewards', queryParams: {
        if (_selectedBusinessId != 'all') 'businessId': _selectedBusinessId,
        if (range != null) 'startDate': range.start.toIso8601String(),
        if (range != null) 'endDate': range.end.toIso8601String(),
      });
      final transfersRaw = await ApiClient().get('rewards/transfers');

      final rewards = rewardsRaw is List
          ? List<Map<String, dynamic>>.from(rewardsRaw)
          : <Map<String, dynamic>>[];
      final transfers = transfersRaw is List
          ? List<Map<String, dynamic>>.from(transfersRaw)
          : <Map<String, dynamic>>[];

      // Agrupa por el usuario que ganó el premio (el remitente si se transfirió).
      final groups = <String, Map<String, dynamic>>{};

      for (final reward in rewards) {
        final rewardId = reward['id'];
        final business = (reward['business'] ?? reward['businesses'] ?? {}) as Map;

        final transfer = transfers
            .where((t) => (t['rewardId'] ?? t['reward_id']) == rewardId)
            .firstOrNull;

        var ownerId = (reward['userId'] ?? reward['user_id'])?.toString() ?? '';
        var owner = (reward['user'] ?? reward['profiles'] ?? {}) as Map;
        var ownerName = _personName(owner);
        var ownerEmail = owner['email']?.toString();

        if (transfer != null) {
          ownerId = (transfer['fromUserId'] ?? transfer['from_user_id'])?.toString() ?? ownerId;
          final from = transfer['fromUser'] as Map?;
          if (from != null) {
            ownerName = _personName(from) ?? 'Remitente';
            ownerEmail = from['email']?.toString();
          }
        }

        final group = groups.putIfAbsent(
          ownerId,
          () => {
            'user_id': ownerId,
            'user_name': ownerName ?? 'Usuario desconocido',
            'user_email': ownerEmail ?? '',
            'rewards': <Map<String, dynamic>>[],
          },
        );

        (group['rewards'] as List<Map<String, dynamic>>).add({
          'reward_id': rewardId,
          'reward_description':
              reward['rewardDescription'] ?? business['rewardDescription'],
          'business_name': business['name'],
          'points_used': reward['pointsUsed'] ?? business['pointsRequired'],
          'earned_at': reward['earnedAt'] ?? reward['earned_at'],
          'transferred': transfer != null,
          'transferred_to_name': transfer == null ? null : _personName(transfer['toUser'] as Map?),
          'transferred_at': transfer?['transferredAt'] ?? transfer?['transferred_at'],
        });
      }

      final summaries = groups.values.toList()
        ..sort((a, b) => (a['user_name'] as String).compareTo(b['user_name'] as String));

      if (mounted) {
        setState(() {
          _allTransfers = transfers;
          _userSummaries = summaries;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rewards: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        DashboardAnimatedToast.show(context, 'Error al cargar premios', isError: true);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _userSummaries;
    final query = _searchQuery.toLowerCase();
    return _userSummaries.where((u) {
      final name = (u['user_name'] ?? '').toString().toLowerCase();
      final email = (u['user_email'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredTransfers {
    final range = AdminDateRange.resolve(_filter, custom: _customRange);
    return _allTransfers.where((t) {
      if (_selectedBusinessId != 'all' &&
          (t['businessId'] ?? t['business_id']) != _selectedBusinessId) {
        return false;
      }
      if (range != null) {
        final at = DateTime.tryParse('${t['transferredAt'] ?? t['transferred_at'] ?? ''}');
        if (at == null || !range.contains(at)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;
    final transfers = _filteredTransfers;

    return DefaultTabController(
      length: 2,
      child: AdminPageFrame(
        title: 'Premios',
        body: Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: AdminSearchField(
                        controller: _searchController,
                        hint: 'Usuario por nombre o correo',
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    AdminDateFilterBar(
                      selected: _filter,
                      customRange: _customRange,
                      onChanged: (filter, range) {
                        setState(() {
                          _filter = filter;
                          _customRange = range;
                        });
                        _loadRewards();
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
                            _loadRewards();
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const AppPillTabBar(labels: ['Ganadores', 'Traspasos']),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const AdminLoading()
                  : TabBarView(
                      children: [
                        _WinnersList(
                          users: users,
                          isSearching: _searchQuery.isNotEmpty,
                          onRefresh: _loadRewards,
                        ),
                        _TransfersList(transfers: transfers, onRefresh: _loadRewards),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WinnersList extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final bool isSearching;
  final Future<void> Function({bool silent}) onRefresh;

  const _WinnersList({
    required this.users,
    required this.isSearching,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return AppEmptyState(
        title: isSearching ? 'Sin resultados' : 'Sin ganadores',
        message: isSearching
            ? 'Ningún usuario coincide con tu búsqueda.'
            : 'Nadie ha ganado premios en este periodo.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.black,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final summary = users[index];
          final name = summary['user_name'] as String;
          final email = summary['user_email'] as String;
          final rewards = List<Map<String, dynamic>>.from(summary['rewards'] as List);

          return AppCard(
            radius: 28,
            padding: const EdgeInsets.all(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminUserRewardsDetailScreen(
                  userId: summary['user_id'] as String,
                  userName: name,
                  userEmail: email,
                  rewards: rewards,
                ),
              ),
            ),
            child: Row(
              children: [
                PersonAvatar(name: name, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(size: 16, weight: FontWeight.w500),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            size: 13,
                            weight: FontWeight.w300,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppChip(label: '${rewards.length}', icon: Icons.card_giftcard_rounded),
                const Icon(Icons.chevron_right_rounded, size: 28),
              ],
            ),
          ).animate(delay: Duration(milliseconds: 30 * (index % 8))).fadeIn();
        },
      ),
    );
  }
}

class _TransfersList extends StatelessWidget {
  final List<Map<String, dynamic>> transfers;
  final Future<void> Function({bool silent}) onRefresh;

  const _TransfersList({required this.transfers, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (transfers.isEmpty) {
      return const AppEmptyState(
        title: 'Sin traspasos',
        message: 'Aún no hay premios transferidos entre usuarios.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.black,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: transfers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final transfer = transfers[index];
          final from = transfer['fromUser'] as Map?;
          final to = transfer['toUser'] as Map?;
          final business = transfer['business'] as Map?;
          final reward = transfer['reward'] as Map?;
          final at = '${transfer['transferredAt'] ?? transfer['transferred_at'] ?? ''}';

          return AppCard(
            radius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TransferParty(
                  label: 'Remitente',
                  name: _AdminRewardsScreenState._personName(from) ?? 'Usuario desconocido',
                  email: from?['email']?.toString() ?? '',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Icon(Icons.arrow_downward_rounded, size: 20),
                ),
                _TransferParty(
                  label: 'Destinatario',
                  name: _AdminRewardsScreenState._personName(to) ?? 'Usuario desconocido',
                  email: to?['email']?.toString() ?? '',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: AppColors.black),
                ),
                Row(
                  children: [
                    Expanded(
                      child: AdminInfoLine(
                        icon: Icons.storefront_rounded,
                        text: '${business?['name'] ?? 'Local desconocido'}',
                      ),
                    ),
                    if (reward?['pointsUsed'] != null)
                      AppChip(label: '${reward!['pointsUsed']} pts', style: AppChipStyle.dark),
                  ],
                ),
                if (at.isNotEmpty)
                  AdminInfoLine(
                    icon: Icons.schedule_rounded,
                    text: EcuadorDateUtils.formatEcuadorTime(at),
                  ),
              ],
            ),
          ).animate(delay: Duration(milliseconds: 30 * (index % 8))).fadeIn();
        },
      ),
    );
  }
}

class _TransferParty extends StatelessWidget {
  final String label;
  final String name;
  final String email;

  const _TransferParty({required this.label, required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.label(size: 11, tracking: 3, color: AppColors.textSecondary),
        ),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body(size: 16, weight: FontWeight.w500),
        ),
        if (email.isNotEmpty)
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              size: 13,
              weight: FontWeight.w300,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}
