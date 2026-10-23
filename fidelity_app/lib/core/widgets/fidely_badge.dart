import 'package:flutter/material.dart' hide Text;

import '../l10n/tr_text.dart';
import '../l10n/translator.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Lo que cuenta de un cliente en un local para su insignia de fidelidad.
class FidelyInfo {
  /// Escaneos reales aprobados por el local.
  final int verifiedScans;

  /// Escaneos que se necesitan para ser FidelyUsuario (lo fija el administrador).
  final int required;
  final bool isFidely;

  const FidelyInfo({this.verifiedScans = 0, this.required = 3, this.isFidely = false});

  /// Lee los datos que trae el servidor (`verified_scans`, `fidely_required`, `is_fidely`).
  factory FidelyInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const FidelyInfo();
    return FidelyInfo(
      verifiedScans: (map['verified_scans'] as num?)?.toInt() ?? 0,
      required: (map['fidely_required'] as num?)?.toInt() ?? 3,
      isFidely: map['is_fidely'] == true,
    );
  }

  /// Cuántos escaneos le faltan (0 si ya lo es).
  int get missing => isFidely ? 0 : (required - verifiedScans).clamp(0, required);
}

/// La insignia FidelyUsuario: la gana quien es fiel a un local (por defecto, a
/// partir de su 3.er escaneo aprobado ahí). Es una píldora rosa con un corazón.
class FidelyBadge extends StatelessWidget {
  /// Más chica, para listas.
  final bool compact;

  const FidelyBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.tr('FidelyUsuario'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 3 : 6),
        decoration: BoxDecoration(
          color: AppColors.pink,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.black, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, size: compact ? 12 : 16, color: AppColors.black),
            SizedBox(width: compact ? 4 : 6),
            Text(
              'FIDELYUSUARIO',
              style: AppTypography.label(size: compact ? 10 : 12, tracking: compact ? 1 : 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lo que ve el cliente al entrar en la tarjeta de un local: su insignia si ya
/// la ganó, o cuánto le falta para ganarla.
class FidelyStatusCard extends StatelessWidget {
  final FidelyInfo info;
  final String businessName;

  const FidelyStatusCard({super.key, required this.info, required this.businessName});

  @override
  Widget build(BuildContext context) {
    final String message;
    if (info.isFidely) {
      message = 'Por tu fidelidad a $businessName';
    } else if (info.missing == 1) {
      message = 'Te falta 1 escaneo para ser FidelyUsuario';
    } else {
      message = 'Te faltan ${info.missing} escaneos para ser FidelyUsuario';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: info.isFidely ? AppColors.pink : AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.black, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: info.isFidely ? AppColors.white : AppColors.pink,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.black, width: 1.2),
            ),
            child: const Icon(Icons.favorite_rounded, size: 22, color: AppColors.black),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info.isFidely)
                  Text('FIDELYUSUARIO', style: AppTypography.display(size: 22))
                else
                  Text(
                    message,
                    style: AppTypography.body(size: 15, weight: FontWeight.w600),
                  ),
                if (info.isFidely)
                  Text(message, style: AppTypography.body(size: 14, weight: FontWeight.w300))
                else ...[
                  const SizedBox(height: 8),
                  _Dots(done: info.verifiedScans, total: info.required),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un punto por cada escaneo que se necesita; los ya hechos van llenos.
class _Dots extends StatelessWidget {
  final int done;
  final int total;

  const _Dots({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    // Con cantidades grandes (hasta 50) se muestra una barra en vez de puntos.
    if (total > 10) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: (done / total).clamp(0.0, 1.0),
          minHeight: 8,
          backgroundColor: AppColors.surfaceMuted,
          color: AppColors.black,
        ),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? AppColors.black : AppColors.white,
              border: Border.all(color: AppColors.black, width: 1.2),
            ),
          ),
      ],
    );
  }
}
