import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Círculo para elegir una imagen (foto de perfil, logo de negocio) con su
/// leyenda debajo. Sin imagen muestra un "+" gris; con imagen la muestra y,
/// si [showEditBadge] es true, agrega el lápiz de edición del mockup.
///
/// Recibe un [ImageProvider] para servir igual con bytes recién elegidos
/// (`MemoryImage`) o con una imagen ya guardada (`imageProviderFromUrl`).
class AppPhotoPicker extends StatelessWidget {
  final String caption;
  final ImageProvider? image;
  final VoidCallback onTap;
  final bool showEditBadge;

  /// Si se indica, el círculo se envuelve en un `Hero` con esta etiqueta para
  /// animar la transición desde otra pantalla (p. ej. el logo del dashboard).
  final String? heroTag;

  const AppPhotoPicker({
    super.key,
    required this.caption,
    required this.image,
    required this.onTap,
    this.showEditBadge = false,
    this.heroTag,
  });

  static const double _diameter = 100;

  @override
  Widget build(BuildContext context) {
    final provider = image;
    final circle = Container(
      width: _diameter,
      height: _diameter,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        shape: BoxShape.circle,
        image: provider != null
            ? DecorationImage(image: provider, fit: BoxFit.cover)
            : null,
      ),
      child: provider == null
          ? const Icon(
              Icons.add_rounded,
              size: 44,
              color: AppColors.placeholderIcon,
            )
          : null,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: caption,
          child: GestureDetector(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                heroTag == null ? circle : Hero(tag: heroTag!, child: circle),
                if (provider != null && showEditBadge)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.black, width: 1),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: AppColors.black,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          caption.toUpperCase(),
          style: AppTypography.body(size: 12, weight: FontWeight.w300),
        ),
      ],
    );
  }
}
