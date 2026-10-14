import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/realtime_sync_service.dart';
import 'admin_businesses_screen.dart';
import 'admin_users_screen.dart';
import 'admin_activity_screen.dart';
import 'admin_rewards_screen.dart';
import 'admin_qr_stats_screen.dart';
import 'admin_categories_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import 'data/admin_repository.dart';
import 'dart:async';
import '../../core/utils/image_source.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _adminRepo = AdminRepository();
  bool _isLoading = true;

  // Metrics
  int _totalBusinesses = 0;
  int _totalUsers = 0;
  int _totalScans = 0;
  int _totalRewards = 0;
  int _approvedRewards = 0;
  int _rejectedRewards = 0;
  int _pendingBusinessesCount = 0;

  StreamSubscription? _scansSub;
  StreamSubscription? _rewardsSub;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    _setupRealtimeNotifications();
  }

  void _setupRealtimeNotifications() {
    _scansSub = RealtimeSyncService().onScansChanged.listen((_) {
      if (mounted) _loadMetrics();
    });
    _rewardsSub = RealtimeSyncService().onRewardsChanged.listen((_) {
      if (mounted) _loadMetrics();
    });
  }

  void _showNotification(String title, String message, {String? logoUrl}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 5),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.accentPurple,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentPurple.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (logoUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.white,
                        backgroundImage: imageProviderFromUrl(logoUrl.toString()),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.notifications_active, color: Colors.white),
                    ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.5, end: 0, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  void dispose() {
    _scansSub?.cancel();
    _rewardsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _adminRepo.getDashboardStats();
      if (mounted) {
        setState(() {
          _totalBusinesses = (stats['totalBusinesses'] as num?)?.toInt() ?? 0;
          _pendingBusinessesCount = (stats['pendingBusinesses'] as num?)?.toInt() ?? 0;
          _totalUsers = (stats['totalUsers'] as num?)?.toInt() ?? 0;
          _totalScans = (stats['totalScans'] as num?)?.toInt() ?? 0;
          _totalRewards = (stats['totalRewards'] as num?)?.toInt() ?? 0;
          _approvedRewards = (stats['claimedRewards'] as num?)?.toInt() ?? 0;
          _rejectedRewards = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(authStateProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetrics,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadMetrics,
                color: Colors.black,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen General',
                      style: GoogleFonts.anton(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: 'Negocios',
                                value: _totalBusinesses.toString(),
                                icon: Icons.storefront,
                                color: AppTheme.accentPurple,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AdminBusinessesScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _MetricCard(
                                title: 'Clientes',
                                value: _totalUsers.toString(),
                                icon: Icons.people_outline,
                                color: AppTheme.accentYellow,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AdminUsersScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                    const SizedBox(height: 16),
                    Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: 'Escaneos',
                                value: _totalScans.toString(),
                                icon: Icons.qr_code_scanner,
                                color: AppTheme.accentPink,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AdminActivityScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _MetricCard(
                                title: 'Premios',
                                value: _totalRewards.toString(),
                                icon: Icons.card_giftcard,
                                color: AppTheme.accentGreen,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const AdminRewardsScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                        .animate(delay: 100.ms)
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                    const SizedBox(height: 32),
                    Text(
                      'Módulos',
                      style: GoogleFonts.anton(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ModuleListTile(
                          title: 'Gestión de Negocios',
                          subtitle: 'Ver lista, rendimiento y detalles',
                          icon: Icons.store,
                          badgeCount: _pendingBusinessesCount,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminBusinessesScreen(),
                              ),
                            );
                          },
                        )
                        .animate(delay: 300.ms)
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                    _ModuleListTile(
                          title: 'Gestión de Categorías',
                          subtitle: 'Agregar o eliminar categorías de negocios',
                          icon: Icons.category_rounded,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminCategoriesScreen(),
                              ),
                            );
                          },
                        )
                        .animate(delay: 350.ms)
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                    const SizedBox(height: 12),
                    _ModuleListTile(
                          title: 'Gestión de Usuarios',
                          subtitle: 'Ver todos los perfiles y roles',
                          icon: Icons.group,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminUsersScreen(),
                              ),
                            );
                          },
                        )
                        .animate(delay: 400.ms)
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                    const SizedBox(height: 12),
                    _ModuleListTile(
                          title: 'Estadísticas QR',
                          subtitle: 'Ver ranking de negocios por escaneos',
                          icon: Icons.bar_chart,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminQrStatsScreen(),
                              ),
                            );
                          },
                        )
                        .animate(delay: 450.ms)
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                    const SizedBox(height: 12),
                    _ModuleListTile(
                          title: 'Gestión de Actividad',
                          subtitle: 'Ver historial de escaneos y validaciones',
                          icon: Icons.history,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminActivityScreen(),
                              ),
                            );
                          },
                        )
                        .animate(delay: 500.ms)
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                    const SizedBox(height: 12),
                    _ModuleListTile(
                          title: 'Gestión de Premios',
                          subtitle: 'Ver historial de premios canjeados',
                          icon: Icons.card_giftcard,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminRewardsScreen(),
                              ),
                            );
                          },
                        )
                        .animate(delay: 600.ms)
                        .fadeIn(duration: AppTheme.animDurationStandard)
                        .slideY(
                          begin: AppTheme.animSlideYBegin,
                          curve: AppTheme.animCurveStandard,
                        ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.anton(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }
    return content;
  }
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final String count;
  final Color color;

  const _StatusIndicator({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  const _ModuleListTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.black),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentPink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (badgeCount > 0) const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }
}
