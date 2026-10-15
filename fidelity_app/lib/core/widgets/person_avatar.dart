import 'package:flutter/material.dart' hide Text;

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/image_source.dart';
import '../l10n/tr_text.dart';

/// Avatar de otra persona (p. ej. un cliente): su foto si la tiene o, si no,
/// la inicial de su nombre sobre gris.
class PersonAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const PersonAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final image = imageProviderFromUrl(avatarUrl);
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        shape: BoxShape.circle,
        image: image == null ? null : DecorationImage(image: image, fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: image == null
          ? Text(initial, style: AppTypography.display(size: size * 0.5))
          : null,
    );
  }
}
