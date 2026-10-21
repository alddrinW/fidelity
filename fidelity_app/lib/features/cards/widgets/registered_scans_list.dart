import 'package:flutter/material.dart' hide Text;

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_source.dart';
import '../../../core/widgets/app_card.dart';

/// "MIS ESCANEOS REGISTRADOS": los locales donde el cliente ya escaneó, con
/// su avance hacia el premio. Tocar uno abre su historial (escaneos y premios).
class RegisteredScansList extends StatelessWidget {
  /// Las tarjetas del cliente (las que trae `myCardsProvider`).
  final List<Map<String, dynamic>> cards;

  final ValueChanged<Map<String, dynamic>> onOpen;

  /// Si es `false` no pone el título de la sección (cuando la pantalla ya
  /// tiene su propio encabezado).
  final bool showTitle;

  const RegisteredScansList({
    super.key,
    required this.cards,
    required this.onOpen,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Semantics(
              header: true,
              child: Text(
                'MIS ESCANEOS REGISTRADOS',
                style: AppTypography.label(size: 16, tracking: 0.5),
              ),
            ),
          ),
        for (final card in cards) ...[
          _ScanCard(card: card, onTap: () => onOpen(card)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Un local con su logo, su premio y cuánto lleva acumulado.
class _ScanCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final VoidCallback onTap;

  const _ScanCard({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final business = Map<String, dynamic>.from((card['businesses'] as Map?) ?? const {});
    final name = business['name']?.toString() ?? 'Negocio';
    final reward = business['reward_description']?.toString().trim();
    final points = (card['current_points'] as num?)?.toInt() ?? 0;
    final required = (business['points_required'] as num?)?.toInt() ?? 10;
    final image = imageProviderFromUrl(business['logo_url']?.toString());

    return AppCard(
      radius: 32,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Row(
        children: [
          // El logo del local, completo y sin recortes.
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: image == null
                ? const Icon(Icons.storefront_outlined, color: AppColors.black, size: 28)
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image(image: image, fit: BoxFit.contain),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(size: 24),
                ),
                if (reward != null && reward.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('PREMIO', style: AppTypography.label(size: 11, tracking: 2)),
                  Text(
                    reward,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(size: 15, weight: FontWeight.w300),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '$points/$required',
                  style: AppTypography.display(size: 26),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 32, color: AppColors.black),
        ],
      ),
    );
  }
}
