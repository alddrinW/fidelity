import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import 'data/admin_date_filter.dart';
import 'widgets/admin_widgets.dart';
import '../../core/l10n/tr_text.dart';

/// Escaneos aprobados de un negocio en el periodo elegido.
class BusinessScanStats {
  final String businessId;
  final String businessName;
  final int scanCount;

  const BusinessScanStats({
    required this.businessId,
    required this.businessName,
    required this.scanCount,
  });
}

class AdminQrStatsScreen extends StatefulWidget {
  const AdminQrStatsScreen({super.key});

  @override
  State<AdminQrStatsScreen> createState() => _AdminQrStatsScreenState();
}

class _AdminQrStatsScreenState extends State<AdminQrStatsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  AdminDateFilter _filter = AdminDateFilter.week;
  DateTimeRange? _customRange;

  int _totalScans = 0;
  List<BusinessScanStats> _ranking = [];

  @override
  void initState() {
    super.initState();
    _loadScanData();
  }

  Future<void> _loadScanData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // `includeAll` es false en esta pantalla, así que siempre hay rango.
      final range = AdminDateRange.resolve(_filter, custom: _customRange)!;

      final raw = await ApiClient().get('admin/qr-stats', queryParams: {
        'startDate': range.start.toUtc().toIso8601String(),
        'endDate': range.end.toUtc().toIso8601String(),
      });
      final rows = raw is List ? List<Map<String, dynamic>>.from(raw) : <Map<String, dynamic>>[];

      final byBusiness = <String, BusinessScanStats>{};
      for (final row in rows) {
        final businessId = (row['businessId'] ?? row['business_id'])?.toString();
        if (businessId == null) continue;
        final business = (row['business'] ?? row['businesses']) as Map?;
        final previous = byBusiness[businessId];
        byBusiness[businessId] = BusinessScanStats(
          businessId: businessId,
          businessName: previous?.businessName ?? (business?['name'] as String?) ?? 'Sin nombre',
          scanCount: (previous?.scanCount ?? 0) + 1,
        );
      }

      final ranking = byBusiness.values.toList()
        ..sort((a, b) => b.scanCount.compareTo(a.scanCount));

      if (mounted) {
        setState(() {
          _totalScans = rows.length;
          _ranking = ranking;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading scan stats: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudieron cargar las estadísticas.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: 'Estadísticas QR',
      body: Column(
        children: [
          const SizedBox(height: 8),
          AdminDateFilterBar(
            includeAll: false,
            selected: _filter,
            customRange: _customRange,
            onChanged: (filter, range) {
              setState(() {
                _filter = filter;
                _customRange = range;
              });
              _loadScanData();
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const AdminLoading()
                : _errorMessage != null
                    ? _ErrorState(onRetry: _loadScanData)
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadScanData,
      color: AppColors.black,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          _SummaryCard(total: _totalScans)
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.06),
          const SizedBox(height: 24),
          if (_ranking.isEmpty)
            const SizedBox(
              height: 360,
              child: AppEmptyState(
                title: 'Sin escaneos',
                message: 'No hay escaneos aprobados en este periodo.',
              ),
            )
          else ...[
            const AdminSectionLabel('Top 10 negocios'),
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
              child: SizedBox(
                height: 300,
                child: _TopBusinessesChart(businesses: _ranking.take(10).toList()),
              ),
            ).animate(delay: 100.ms).fadeIn(duration: 300.ms),
            const SizedBox(height: 24),
            const AdminSectionLabel('Ranking'),
            for (var i = 0; i < _ranking.length; i++) ...[
              _RankingRow(position: i + 1, stats: _ranking[i]),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int total;

  const _SummaryCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL DE ESCANEOS',
                  style: AppTypography.label(size: 12, tracking: 3, color: AppColors.pink),
                ),
                Text(
                  '$total',
                  style: AppTypography.display(size: 64, color: AppColors.white),
                ),
                Text(
                  'en el periodo seleccionado',
                  style: AppTypography.body(
                    size: 14,
                    weight: FontWeight.w300,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
            child: const Icon(Icons.qr_code_scanner_rounded, size: 28, color: AppColors.black),
          ),
        ],
      ),
    );
  }
}

class _TopBusinessesChart extends StatelessWidget {
  final List<BusinessScanStats> businesses;

  const _TopBusinessesChart({required this.businesses});

  @override
  Widget build(BuildContext context) {
    final maxY = (businesses.first.scanCount * 1.2).clamp(1.0, double.infinity);
    final labelStyle = AppTypography.body(
      size: 11,
      weight: FontWeight.w300,
      color: AppColors.textSecondary,
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.black,
            tooltipPadding: const EdgeInsets.all(10),
            tooltipRoundedRadius: 16,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final business = businesses[group.x];
              return BarTooltipItem(
                '${business.businessName}\n',
                AppTypography.body(size: 14, weight: FontWeight.w500, color: AppColors.white),
                children: [
                  TextSpan(
                    text: '${business.scanCount} escaneos',
                    style: AppTypography.body(
                      size: 12,
                      weight: FontWeight.w300,
                      color: AppColors.pink,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 90,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= businesses.length) return const SizedBox.shrink();
                final name = businesses[index].businessName;
                // Texto vertical: evita que los nombres se solapen.
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      name.length > 14 ? '${name.substring(0, 14)}…' : name,
                      maxLines: 1,
                      style: labelStyle,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                if (value != value.roundToDouble()) return const SizedBox.shrink();
                return Text(value.toInt().toString(), style: labelStyle);
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0x1F000000), strokeWidth: 1),
        ),
        barGroups: [
          for (var i = 0; i < businesses.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: businesses[i].scanCount.toDouble(),
                  // El líder del ranking resalta en rosa.
                  color: i == 0 ? AppColors.pink : AppColors.black,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  borderSide: i == 0
                      ? const BorderSide(color: AppColors.black, width: 1.2)
                      : BorderSide.none,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int position;
  final BusinessScanStats stats;

  const _RankingRow({required this.position, required this.stats});

  @override
  Widget build(BuildContext context) {
    final isPodium = position <= 3;

    return AppCard(
      radius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isPodium ? AppColors.pink : AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Text('$position', style: AppTypography.display(size: 22)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              stats.businessName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(size: 16, weight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Text('${stats.scanCount}', style: AppTypography.display(size: 28)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: AppEmptyState.error(message: 'No se pudieron cargar las estadísticas. Inténtalo de nuevo.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: AppPrimaryButton(label: 'Reintentar', onPressed: onRetry),
        ),
      ],
    );
  }
}
