import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_source.dart';

/// Un comercio como "misión" de la ruta: su avance hacia el próximo premio.
class Mission {
  final Map<String, dynamic> card;
  final String name;
  final String? logoUrl;
  final String? category;
  final String? reward;
  final int points;
  final int required;

  /// Premios ganados que el local todavía no entrega.
  final int readyRewards;

  /// Escaneos que el local aún no aprueba.
  final int pendingScans;

  const Mission({
    required this.card,
    required this.name,
    required this.points,
    required this.required,
    this.logoUrl,
    this.category,
    this.reward,
    this.readyRewards = 0,
    this.pendingScans = 0,
  });

  /// Arma la misión a partir de una tarjeta de `myCardsProvider`.
  factory Mission.fromCard(Map<String, dynamic> card) {
    final business = Map<String, dynamic>.from((card['businesses'] as Map?) ?? const {});
    final rewards = (card['rewards'] as List?) ?? const [];
    final reward = business['reward_description']?.toString();
    return Mission(
      card: card,
      name: business['name']?.toString() ?? 'Negocio',
      logoUrl: business['logo_url']?.toString(),
      category: (business['business_categories'] as Map?)?['name']?.toString(),
      reward: (reward == null || reward.trim().isEmpty) ? null : reward.trim(),
      points: (card['current_points'] as num?)?.toInt() ?? 0,
      required: math.max(1, (business['points_required'] as num?)?.toInt() ?? 10),
      readyRewards: rewards.where((r) => (r as Map)['status'] == 'pending').length,
      pendingScans: (card['pending_scans'] as num?)?.toInt() ?? 0,
    );
  }

  /// Avance de 0 a 1 hacia el próximo premio.
  double get progress => (points / required).clamp(0.0, 1.0);

  int get pointsLeft => math.max(0, required - points);

  bool get hasReadyReward => readyRewards > 0;
}

/// La misión a destacar: un premio listo para reclamar y, si no hay, la que más
/// cerca está de completarse. `null` si no hay misiones.
Mission? nextMission(List<Mission> missions) {
  if (missions.isEmpty) return null;
  final ready = missions.where((m) => m.hasReadyReward);
  if (ready.isNotEmpty) return ready.first;
  final byProgress = [...missions]..sort((a, b) => b.progress.compareTo(a.progress));
  return byProgress.first;
}

/// "Ruta de Misiones": los negocios del cliente como nodos de un camino en
/// zigzag, cada uno con su anillo de progreso y sus sellos, y arriba un aviso
/// de cuánto falta para el próximo premio.
class MissionsRoute extends StatelessWidget {
  final List<Mission> missions;
  final ValueChanged<Mission> onOpen;

  const MissionsRoute({super.key, required this.missions, required this.onOpen});

  static const double _rowHeight = 176;
  static const double _nodeSize = 96;

  @override
  Widget build(BuildContext context) {
    final next = nextMission(missions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Semantics(
            header: true,
            child: Text('MI RUTA DE MISIONES', style: AppTypography.label(size: 16, tracking: 0.5)),
          ),
        ),
        if (next != null) NextRewardBanner(mission: next, onTap: () => onOpen(next)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = missions.length * _rowHeight;
            // Los nodos se alternan a izquierda y derecha; la etiqueta va en el
            // lado de adentro.
            double centerX(int i) => i.isEven ? _nodeSize / 2 + 8 : width - _nodeSize / 2 - 8;
            double centerY(int i) => i * _rowHeight + _nodeSize / 2 + 12;

            return SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: RoutePathPainter(
                        points: [for (var i = 0; i < missions.length; i++) Offset(centerX(i), centerY(i))],
                      ),
                    ),
                  ),
                  for (var i = 0; i < missions.length; i++)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: i * _rowHeight,
                      height: _rowHeight,
                      child: _MissionNodeRow(
                        mission: missions[i],
                        nodeSize: _nodeSize,
                        nodeOnLeft: i.isEven,
                        onTap: () => onOpen(missions[i]),
                      )
                          .animate(delay: (math.min(i, 6) * 90).ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.06, curve: Curves.easeOutCubic, duration: 500.ms),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Aviso de "cuánto falta" para el próximo premio, con su barra de progreso.
class NextRewardBanner extends StatelessWidget {
  final Mission mission;
  final VoidCallback onTap;

  const NextRewardBanner({super.key, required this.mission, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final String title;
    final String subtitle;
    if (m.hasReadyReward) {
      title = '¡Premio listo en ${m.name}!';
      subtitle = m.reward == null ? 'Acércate al local a reclamarlo.' : 'Reclama: ${m.reward}';
    } else if (m.pointsLeft == 1) {
      title = '¡Te falta 1 punto en ${m.name}!';
      subtitle = m.reward == null ? 'Tu próximo premio está a un escaneo.' : 'Y ganas: ${m.reward}';
    } else {
      title = 'Te faltan ${m.pointsLeft} puntos en ${m.name}';
      subtitle = m.reward == null ? 'Vas ${m.points} de ${m.required}.' : 'Para ganar: ${m.reward}';
    }

    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: AppColors.pink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: AppColors.black, width: 1.2),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      m.hasReadyReward ? Icons.card_giftcard_rounded : Icons.flag_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title, style: AppTypography.body(size: 16, weight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.body(size: 14, weight: FontWeight.w300)),
                const SizedBox(height: 12),
                ProgressBar(value: m.hasReadyReward ? 1 : m.progress, height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de progreso de marca (negra sobre blanco, con contorno).
class ProgressBar extends StatelessWidget {
  final double value;
  final double height;

  const ProgressBar({super.key, required this.value, this.height = 10});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      value: '${(value * 100).round()}%',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(height),
          border: Border.all(color: AppColors.black, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: const ColoredBox(color: AppColors.black, child: SizedBox.expand()),
          ),
        ),
      ),
    );
  }
}

class _MissionNodeRow extends StatelessWidget {
  final Mission mission;
  final double nodeSize;
  final bool nodeOnLeft;
  final VoidCallback onTap;

  const _MissionNodeRow({
    required this.mission,
    required this.nodeSize,
    required this.nodeOnLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final node = MissionNode(mission: mission, size: nodeSize, onTap: onTap);
    final label = Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: nodeOnLeft ? 16 : 0, right: nodeOnLeft ? 0 : 16, top: 8),
        child: _MissionLabel(mission: mission, alignEnd: !nodeOnLeft),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: nodeOnLeft
            ? [Padding(padding: const EdgeInsets.only(left: 8), child: node), label]
            : [label, Padding(padding: const EdgeInsets.only(right: 8), child: node)],
      ),
    );
  }
}

/// El nodo: el logo del negocio dentro de un círculo, con su badge de premio
/// listo o de escaneo pendiente. El logo se muestra completo, sin recortes.
class MissionNode extends StatelessWidget {
  final Mission mission;
  final double size;
  final VoidCallback onTap;

  const MissionNode({super.key, required this.mission, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final fallback = Icon(
      AppTheme.getCategoryIcon(m.category ?? 'Otra'),
      color: AppColors.black,
      size: size * 0.4,
    );
    final image = imageProviderFromUrl(m.logoUrl);

    return Semantics(
      button: true,
      label: '${m.name}, ${m.points} de ${m.required} puntos',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // El círculo del logo: fondo claro (rosa si hay premio listo) y
              // el contorno de marca.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: m.hasReadyReward ? AppColors.pink : AppColors.surfaceMuted,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.black, width: 1.2),
                  ),
                ),
              ),
              // El logo entra entero (contain) y con aire para que no se toque
              // el borde del círculo.
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(size * 0.15),
                  child: image == null
                      ? fallback
                      : Image(
                          image: image,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => fallback,
                        ),
                ),
              ),
              if (m.hasReadyReward)
                Positioned(
                  right: -4,
                  top: -4,
                  child: const _Badge(icon: Icons.card_giftcard_rounded, filled: true)
                      .animate(onPlay: (c) => c.repeat(reverse: true, count: 6))
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.15, 1.15),
                        duration: 700.ms,
                        curve: Curves.easeInOut,
                      ),
                )
              else if (m.pendingScans > 0)
                const Positioned(
                  right: -4,
                  top: -4,
                  child: _Badge(icon: Icons.hourglass_top_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final bool filled;

  const _Badge({required this.icon, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: filled ? AppColors.black : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.black, width: 1.2),
      ),
      child: Icon(icon, size: 16, color: filled ? AppColors.white : AppColors.black),
    );
  }
}

/// Nombre, premio, sellos y barra de un negocio.
class _MissionLabel extends StatelessWidget {
  final Mission mission;
  final bool alignEnd;

  const _MissionLabel({required this.mission, required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.end : TextAlign.start;

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          m.name.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: AppTypography.display(size: 22),
        ),
        if (m.reward != null)
          Text(
            m.reward!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: AppTypography.body(size: 13, weight: FontWeight.w300),
          ),
        const SizedBox(height: 6),
        StampRow(points: m.points, required: m.required, alignEnd: alignEnd),
        const SizedBox(height: 6),
        Text(
          m.hasReadyReward
              ? 'PREMIO LISTO'
              : m.pendingScans > 0
                  ? '${m.points}/${m.required} · PENDIENTE'
                  : '${m.points}/${m.required}',
          textAlign: textAlign,
          style: AppTypography.label(size: 14, tracking: 1.5),
        ),
      ],
    );
  }
}

/// Los sellos requeridos: un círculo por punto, lleno si ya se ganó. Con
/// muchos sellos se resume en una barra para no saturar.
class StampRow extends StatelessWidget {
  final int points;
  final int required;
  final bool alignEnd;

  static const int maxStamps = 12;

  const StampRow({super.key, required this.points, required this.required, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    if (required > maxStamps) {
      return ProgressBar(value: points / required, height: 10);
    }
    return Wrap(
      alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < required; i++)
          Container(
            key: ValueKey(i < points ? 'stamp-on-$i' : 'stamp-off-$i'),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: i < points ? AppColors.black : AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.black, width: 1.2),
            ),
          ),
      ],
    );
  }
}

/// El camino punteado que une un nodo con el siguiente.
class RoutePathPainter extends CustomPainter {
  final List<Offset> points;

  RoutePathPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = AppColors.black;

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final midY = (a.dy + b.dy) / 2;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);

      // Trazo punteado: tramos cortos separados por huecos.
      for (final PathMetric metric in path.computeMetrics()) {
        var distance = 0.0;
        while (distance < metric.length) {
          final end = math.min(distance + 6, metric.length);
          canvas.drawPath(metric.extractPath(distance, end), paint);
          distance += 14;
        }
      }
    }
  }

  @override
  bool shouldRepaint(RoutePathPainter old) {
    if (old.points.length != points.length) return true;
    for (var i = 0; i < points.length; i++) {
      if (old.points[i] != points[i]) return true;
    }
    return false;
  }
}
