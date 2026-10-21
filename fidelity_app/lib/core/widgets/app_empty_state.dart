import 'package:flutter/material.dart' hide Text;

import '../theme/app_typography.dart';
import '../l10n/tr_text.dart';
import 'fido_mascot.dart';

/// Estado vacío de marca: Fido, un título de impacto y un texto breve.
class AppEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final double imageHeight;

  /// Cómo se ve Fido (tranquilo por defecto; triste en los errores).
  final FidoMood mood;

  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.imageHeight = 170,
    this.mood = FidoMood.calm,
  });

  /// Cuando algo no se pudo cargar: Fido triste y el título de siempre.
  const AppEmptyState.error({
    super.key,
    required this.message,
    this.imageHeight = 170,
  })  : title = 'Algo salió mal',
        mood = FidoMood.sad;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FidoMascot(mood: mood, height: imageHeight),
            const SizedBox(height: 8),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTypography.display(size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 15, weight: FontWeight.w300),
            ),
          ],
        ),
      ),
    );
  }
}
