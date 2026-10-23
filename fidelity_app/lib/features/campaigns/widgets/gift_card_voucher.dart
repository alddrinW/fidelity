import 'package:flutter/material.dart' hide Text;

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/image_source.dart';
import '../../../core/widgets/scratch_card.dart';
import '../data/campaigns_repository.dart';
import 'birthday_art.dart';

/// El cheque de la gift card: el diseño que ve el cliente.
///
/// Es un vale troquelado: a la izquierda el local y el nombre de la gift
/// card, a la derecha el beneficio (que el cliente raspa para verlo), la
/// fecha de vigencia y su código de letras.
class GiftCardVoucher extends StatelessWidget {
  /// La plantilla de la gift card: título, beneficio, imagen de fondo y fecha.
  final Campaign campaign;

  /// El código de letras del cliente (vacío en la plantilla del dueño).
  final String? code;

  /// Si la gift card ya se canjeó (se muestra apagada).
  final bool redeemed;

  /// Si el beneficio se revela raspando (así lo ve el cliente).
  final bool scratchable;

  /// El logo del local y su nombre.
  final String? logoUrl;
  final String? businessName;

  const GiftCardVoucher({
    super.key,
    required this.campaign,
    this.code,
    this.redeemed = false,
    this.scratchable = false,
    this.logoUrl,
    this.businessName,
  });

  @override
  Widget build(BuildContext context) {
    final benefit = _benefit();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AppColors.white,
      ),
      // El borde va por delante: la imagen de fondo nunca lo tapa.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.black, width: 1.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // La plantilla de cumpleaños trae su propio diseño.
          if (campaign.isBirthday)
            const Positioned.fill(child: BirthdayArt())
          else if (_background != null)
            Positioned.fill(
              child: Image(image: _background!, fit: BoxFit.cover),
            ),
          if (!campaign.isBirthday && _background != null)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xCCFFFFFF)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            // IntrinsicHeight: las dos mitades del cheque miden lo mismo.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 6, child: _leftSide()),
                  const PerforatedDivider(),
                  Expanded(flex: 5, child: benefit),
                ],
              ),
            ),
          ),
          // Canjeada: un velo blanco la apaga sin volverla transparente, así
          // no se ve a través de ella la tarjeta que tiene debajo.
          if (redeemed)
            const Positioned.fill(
              child: DecoratedBox(
                key: ValueKey('redeemed-veil'),
                decoration: BoxDecoration(color: Color(0x99FFFFFF)),
              ),
            ),
        ],
      ),
    );
  }

  ImageProvider? get _background => imageProviderFromUrl(campaign.imageUrl);

  /// La izquierda: el local, el nombre de la gift card y el mensaje.
  Widget _leftSide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            // Solo el logo del local, sin marco alrededor.
            SizedBox(width: 40, height: 40, child: _logo),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                (businessName ??
                        campaign.businesses.firstOrNull?.name ??
                        'Fidelity')
                    .toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(size: 12, tracking: 2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (campaign.isBirthday) ...[
          const Icon(Icons.cake_rounded, size: 26, color: AppColors.black),
          const SizedBox(height: 4),
        ],
        Text(
          campaign.title.toUpperCase(),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.display(size: 26),
        ),
        if (campaign.description?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            campaign.description!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(size: 13, weight: FontWeight.w300),
          ),
        ],
      ],
    );
  }

  /// La derecha: el beneficio (raspable), la vigencia y el código.
  Widget _benefit() {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _benefitLabel,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.display(size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          _validity,
          textAlign: TextAlign.center,
          style: AppTypography.body(size: 12, weight: FontWeight.w300),
        ),
        if (code != null && code!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              code!,
              style: AppTypography.label(
                  size: 13, tracking: 2, color: AppColors.white),
            ),
          ),
        ],
      ],
    );

    if (!scratchable) return content;

    return ScratchCard(
      hint: 'RASPE AQUÍ',
      coverColor: AppColors.pink,
      child: content,
    );
  }

  /// "30% DE DESCUENTO" o el texto del mini premio.
  String get _benefitLabel {
    final label = campaign.benefitLabel?.trim();
    if (label != null && label.isNotEmpty) return label.toUpperCase();
    final value = campaign.benefitValue;
    if (value != null && value > 0) return '$value% DE DESCUENTO';
    return 'GIFT CARD';
  }

  /// "VÁLIDA HASTA 10.12.25" o "SIN FECHA DE FIN".
  String get _validity {
    final ends = campaign.endsAt;
    if (ends == null) return 'SIN FECHA DE FIN';
    final day =
        EcuadorDateUtils.formatEcuadorDate(ends.toUtc().toIso8601String());
    // La de cumpleaños vale un solo día.
    return campaign.isBirthday ? 'VÁLIDA SOLO EL $day' : 'VÁLIDA HASTA $day';
  }

  Widget get _logo {
    final image = imageProviderFromUrl(logoUrl);
    return image == null
        ? const Icon(Icons.storefront_outlined,
            size: 20, color: AppColors.black)
        : Image(image: image, fit: BoxFit.contain);
  }
}
