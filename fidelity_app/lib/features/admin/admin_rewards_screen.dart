import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/services/api_client.dart';
import '../../core/services/realtime_sync_service.dart';
import 'admin_user_rewards_detail_screen.dart';

class AdminRewardsScreen extends StatefulWidget {
  const AdminRewardsScreen({super.key});

  @override
  State<AdminRewardsScreen> createState() => _AdminRewardsScreenState();
}

class _AdminRewardsScreenState extends State<AdminRewardsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rewards = [];
  List<Map<String, dynamic>> _businessesList = [];
  List<Map<String, dynamic>> _allTransfers = [];
  String _selectedBusinessId = 'all';
  String _selectedFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  StreamSubscription<void>? _rewardsSub;
  StreamSubscription<void>? _transfersSub;

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _loadRewards();

    _rewardsSub = RealtimeSyncService().onRewardsChanged.listen((_) {
      if (mounted) _loadRewards();
    });
    _transfersSub = RealtimeSyncService().onRewardTransfersChanged.listen((_) {
      if (mounted) _loadRewards();
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
        setState(() {
          _businessesList = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading businesses: $e');
    }
  }

  List<Map<String, dynamic>> _userSummaries = [];

  Future<void> _loadRewards() async {
    setState(() => _isLoading = true);
    try {
      final startOfDayUtc = EcuadorDateUtils.getStartOfDayEcuadorUtc();
      String? startDate;
      
      if (_selectedFilter == 'today') {
        startDate = startOfDayUtc.toIso8601String();
      } else if (_selectedFilter == 'week') {
        startDate = startOfDayUtc.subtract(const Duration(days: 7)).toIso8601String();
      } else if (_selectedFilter == 'month') {
        startDate = startOfDayUtc.subtract(const Duration(days: 30)).toIso8601String();
      }

      final rewardsRaw = await ApiClient().get('admin/rewards', queryParams: {
        if (_selectedBusinessId != 'all') 'businessId': _selectedBusinessId,
        if (startDate != null) 'startDate': startDate,
      });

      final transfersRaw = await ApiClient().get('rewards/transfers');

      final response = rewardsRaw is List ? List<Map<String, dynamic>>.from(rewardsRaw) : <Map<String, dynamic>>[];
      final transfers = transfersRaw is List ? List<Map<String, dynamic>>.from(transfersRaw) : <Map<String, dynamic>>[];

      // Agrupar por usuario original (el que ganó el premio)
      Map<String, Map<String, dynamic>> userGroups = {};

      for (var reward in response) {
        final rewardId = reward['id'];
        final business = (reward['business'] ?? reward['businesses']) as Map<String, dynamic>? ?? {};
        
        // Buscar si este premio fue transferido
        final transferInfo = transfers.where((t) => (t['rewardId'] ?? t['reward_id']) == rewardId).toList();
        
        bool isTransferred = transferInfo.isNotEmpty;
        String originalUserId = (reward['userId'] ?? reward['user_id'])?.toString() ?? '';
        final userObj = (reward['user'] ?? reward['profiles']) as Map<String, dynamic>? ?? {};
        Map<String, dynamic> originalProfile = {
          'id': userObj['id'] ?? originalUserId,
          'full_name': userObj['fullName'] ?? userObj['full_name'],
          'email': userObj['email'],
        };

        String? transferredToId;
        String? transferredAt;
        
        if (isTransferred) {
          final firstTransfer = transferInfo.first;
          originalUserId = (firstTransfer['fromUserId'] ?? firstTransfer['from_user_id'])?.toString() ?? originalUserId;
          transferredToId = (firstTransfer['toUserId'] ?? firstTransfer['to_user_id'])?.toString();
          transferredAt = (firstTransfer['transferredAt'] ?? firstTransfer['transferred_at'])?.toString();
          
          final fromUser = firstTransfer['fromUser'] as Map<String, dynamic>?;
          if (fromUser != null) {
            originalProfile = {
              'id': originalUserId,
              'full_name': fromUser['fullName'] ?? fromUser['full_name'] ?? 'Usuario (Remitente)',
              'email': fromUser['email'] ?? 'Transferencia',
            };
          }
        }

        if (!userGroups.containsKey(originalUserId)) {
          userGroups[originalUserId] = {
            'user_id': originalUserId,
            'user_name': originalProfile['full_name'] ?? originalProfile['email'] ?? 'Usuario Desconocido',
            'user_email': originalProfile['email'] ?? '',
            'rewards': <Map<String, dynamic>>[],
          };
        }

        userGroups[originalUserId]!['rewards'].add({
          'reward_id': rewardId,
          'reward_description': business['rewardDescription'] ?? business['reward_description'],
          'business_name': business['name'],
          'points_used': reward['pointsRequired'] ?? reward['points_used'] ?? business['pointsRequired'] ?? business['points_required'],
          'points_required': business['pointsRequired'] ?? business['points_required'],
          'earned_at': reward['earnedAt'] ?? reward['earned_at'],
          'transferred': isTransferred,
          'transferred_to_name': transferredToId,
          'transferred_at': transferredAt,
        });
      }

      if (mounted) {
        setState(() {
          _rewards = response;
          _allTransfers = transfers;
          _userSummaries = userGroups.values.toList();
          // Sort by user name
          _userSummaries.sort((a, b) => (a['user_name'] as String).compareTo(b['user_name'] as String));
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rewards: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar premios: $e',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _userSummaries;
    final query = _searchQuery.toLowerCase();
    return _userSummaries.where((u) {
      final userName = (u['user_name'] ?? '').toString().toLowerCase();
      final userEmail = (u['user_email'] ?? '').toString().toLowerCase();
      return userName.contains(query) || userEmail.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Premios Canjeados'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Usuarios Ganadores'),
              Tab(text: 'Historial Traspasos'),
            ],
            labelColor: AppTheme.accentPurple,
            unselectedLabelColor: Colors.black54,
            indicatorColor: AppTheme.accentPurple,
          ),
        ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_filteredUsers.length} usuarios ganadores',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFilter,
                            icon: const Icon(
                              Icons.filter_list,
                              color: Colors.black,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('Todos (Últimos 100)'),
                              ),
                              DropdownMenuItem(value: 'today', child: Text('Hoy')),
                              DropdownMenuItem(
                                value: 'week',
                                child: Text('Esta Semana'),
                              ),
                              DropdownMenuItem(
                                value: 'month',
                                child: Text('Este Mes'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedFilter = value;
                                });
                                _loadRewards();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    // Business Filter
                    if (_businessesList.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Local:',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBusinessId,
                              icon: const Icon(
                                Icons.store,
                                color: Colors.black,
                                size: 18,
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Todos los locales'),
                                ),
                                ..._businessesList.map((b) {
                                  return DropdownMenuItem(
                                    value: b['id'] as String,
                                    child: Text(
                                      b['name'] != null
                                          ? (b['name'].toString().length > 20
                                                ? '${b['name'].toString().substring(0, 20)}...'
                                                : b['name'])
                                          : 'Desconocido',
                                    ),
                                  );
                                }).toList(),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedBusinessId = value;
                                  });
                                  _loadRewards();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Barra de Búsqueda
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Buscar usuario por nombre o email...',
                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.accentPurple),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple),
                ),
              )
            : TabBarView(
                    children: [
                      // TAB 1: Usuarios Ganadores
                      _filteredUsers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty 
                                        ? 'No hay usuarios que hayan ganado premios en este período' 
                                        : 'No se encontraron usuarios',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadRewards,
                              color: Colors.black,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final userSummary = _filteredUsers[index];
                                  final userName = userSummary['user_name'];
                                  final userEmail = userSummary['user_email'];
                                  final rewardsList = userSummary['rewards'] as List;
                                  final rewardCount = rewardsList.length;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AdminUserRewardsDetailScreen(
                                                userId: userSummary['user_id'],
                                                userName: userName,
                                                userEmail: userEmail,
                                                rewards: List<Map<String, dynamic>>.from(rewardsList),
                                              ),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 24,
                                                backgroundColor: AppTheme.accentPurple.withValues(alpha: 0.1),
                                                child: Text(
                                                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                                  style: const TextStyle(
                                                    color: AppTheme.accentPurple,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      userName,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: Colors.black87,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (userEmail.isNotEmpty)
                                                      Text(
                                                        userEmail,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black54,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accentPurple,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '$rewardCount',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(
                                                      Icons.card_giftcard,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .animate(delay: Duration(milliseconds: 50 * index))
                                  .fadeIn(duration: 400.ms)
                                  .slideX(begin: 0.1, curve: Curves.easeOutBack);
                                },
                              ),
                            ),
                            
                      // TAB 2: Historial Traspasos
                      _buildTransfersList(),
                    ],
                  ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredTransfers {
    if (_selectedBusinessId == 'all') return _allTransfers;
    return _allTransfers.where((t) => t['business_id'] == _selectedBusinessId).toList();
  }

  Widget _buildTransfersList() {
    final filtered = _filteredTransfers;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No hay traspasos registrados',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadRewards,
      color: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final transfer = filtered[index];
          final fromName = transfer['from_user']?['full_name'] ?? 'Usuario Desconocido';
          final fromEmail = transfer['from_user']?['email'] ?? '';
          final toName = transfer['to_user']?['full_name'] ?? 'Usuario Desconocido';
          final toEmail = transfer['to_user']?['email'] ?? '';
          final businessName = transfer['businesses']?['name'] ?? 'Local Desconocido';
          final pts = transfer['rewards']?['points_used'] ?? '?';
          final dateStr = transfer['transferred_at'] != null 
              ? EcuadorDateUtils.formatEcuadorTime(transfer['transferred_at']) 
              : '';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'REMITENTE',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 0.5),
                          ),
                          Text(
                            fromName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          if (fromEmail.isNotEmpty)
                            Text(
                              fromEmail,
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Icon(Icons.arrow_downward_rounded, size: 14, color: AppTheme.accentPurple),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DESTINATARIO',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 0.5),
                          ),
                          Text(
                            toName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          if (toEmail.isNotEmpty)
                            Text(
                              toEmail,
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Colors.black12),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.store, size: 14, color: Colors.black45),
                        const SizedBox(width: 6),
                        Text(
                          businessName,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                    Text(
                      '$pts pts',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.accentPurple),
                    ),
                  ],
                ),
              ],
            ),
          )
          .animate(delay: Duration(milliseconds: 50 * index))
          .fadeIn(duration: 400.ms)
          .slideX(begin: 0.1, curve: Curves.easeOutBack);
        },
      ),
    );
  }
}
