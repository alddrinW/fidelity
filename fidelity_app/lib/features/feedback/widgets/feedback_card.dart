import 'package:flutter/material.dart' hide Text;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../data/feedback_repository.dart';
import '../../../core/l10n/tr_text.dart';

/// Una sugerencia, reclamo o felicitación: calificación, motivos, comentario,
/// respuesta (si la hay) y, para quien puede resolverla, el botón de respuesta.
class FeedbackCard extends StatelessWidget {
  final FeedbackItem item;
  final bool showUser;
  final bool showBusiness;
  final VoidCallback? onResolve;

  const FeedbackCard({
    super.key,
    required this.item,
    this.showUser = false,
    this.showBusiness = true,
    this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final rating = item.rating;
    final (AppChipStyle kindStyle) = switch (item.kind) {
      FeedbackKind.complaint => AppChipStyle.dark,
      FeedbackKind.suggestion => AppChipStyle.pink,
      FeedbackKind.praise => AppChipStyle.outline,
    };
    final date = item.createdAt == null
        ? ''
        : EcuadorDateUtils.formatEcuadorTime(item.createdAt!.toUtc().toIso8601String());

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rating != null) ...[
                Icon(rating.icon, size: 36),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showBusiness)
                      Text(
                        item.businessName.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.display(size: 22),
                      ),
                    if (showUser && (item.userName ?? item.userEmail) != null)
                      Text(
                        item.userName ?? item.userEmail!,
                        style: AppTypography.body(size: 14, weight: FontWeight.w500),
                      ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: AppTypography.body(
                          size: 12,
                          weight: FontWeight.w300,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppChip(label: item.kind.label, style: kindStyle),
                  const SizedBox(height: 6),
                  if (item.isResolved)
                    const AppChip(label: 'Resuelto', style: AppChipStyle.outline, icon: Icons.check_rounded)
                  else
                    const AppChip(label: 'Abierto', style: AppChipStyle.pink),
                ],
              ),
            ],
          ),
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in item.tags)
                  AppChip(label: tag, style: AppChipStyle.outline),
              ],
            ),
          ],
          if (item.message != null && item.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(item.message!, style: AppTypography.body(size: 15, weight: FontWeight.w300)),
          ],
          if (item.reply != null && item.reply!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RESPUESTA', style: AppTypography.label(size: 11, tracking: 3)),
                  const SizedBox(height: 4),
                  Text(item.reply!, style: AppTypography.body(size: 14, weight: FontWeight.w400)),
                ],
              ),
            ),
          ],
          if (onResolve != null && !item.isResolved) ...[
            const SizedBox(height: 16),
            AppPrimaryButton(label: 'Responder y resolver', onPressed: onResolve),
          ],
        ],
      ),
    );
  }
}
