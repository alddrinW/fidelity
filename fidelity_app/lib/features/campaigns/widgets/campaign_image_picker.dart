import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_source.dart';

class CampaignImagePicker extends StatelessWidget {
  /// La imagen recién elegida (con sus bytes, para verla al instante).
  final Uint8List? bytes;

  /// La imagen que ya tenía (URL o data URI), cuando no hay una nueva.
  final String? imageUri;

  final VoidCallback onPick;
  final VoidCallback onRemove;

  const CampaignImagePicker({
    super.key,
    this.bytes,
    this.imageUri,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = bytes != null || (imageUri != null && imageUri!.isNotEmpty);

    if (!hasImage) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.image_outlined),
        label: const Text('AGREGAR IMAGEN (OPCIONAL)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.black,
          side: const BorderSide(color: AppColors.black, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: const StadiumBorder(),
          textStyle: AppTypography.label(size: 13, tracking: 1.5),
        ),
      );
    }

    final image = bytes != null
        ? MemoryImage(bytes!)
        : imageProviderFromUrl(imageUri);

    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: image == null
              ? const SizedBox(height: 160, width: double.infinity)
              : Image(image: image, height: 160, width: double.infinity, fit: BoxFit.cover),
        ),
        IconButton.filled(
          tooltip: 'Quitar imagen',
          style: IconButton.styleFrom(backgroundColor: AppColors.black),
          icon: const Icon(Icons.close_rounded, color: AppColors.white),
          onPressed: onRemove,
        ),
      ],
    );
  }
}
