import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_nav_row.dart';
import 'app_language.dart';
import 'tr_text.dart';
import 'translator.dart';

/// Abre la hoja para elegir el idioma de la app.
Future<void> showLanguageSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final current = ref.watch(languageProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text('IDIOMA', style: AppTypography.display(size: 28)),
              ),
              for (final language in AppLanguage.values)
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Text(
                    language.label,
                    style: AppTypography.body(
                      size: 18,
                      weight: language == current ? FontWeight.w500 : FontWeight.w300,
                    ),
                  ),
                  trailing: language == current
                      ? const Icon(Icons.check_rounded, color: AppColors.black)
                      : null,
                  onTap: () {
                    ref.read(languageProvider.notifier).select(language);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ),
  );
}

/// Fila de ajustes "Idioma" con el idioma actual; abre la hoja de selección.
class LanguageRow extends ConsumerWidget {
  const LanguageRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(languageProvider);
    return AppNavRow(
      icon: Icons.language_rounded,
      label: '${context.tr('Idioma')}: ${current.label}',
      onTap: () => showLanguageSheet(context, ref),
    );
  }
}

/// Botón compacto de idioma (globo + código), para pantallas sin ajustes
/// como el inicio de sesión.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(languageProvider);
    return TextButton.icon(
      onPressed: () => showLanguageSheet(context, ref),
      icon: const Icon(Icons.language_rounded, size: 20, color: AppColors.black),
      label: Text(
        current.code.toUpperCase(),
        style: AppTypography.label(size: 13, tracking: 2),
      ),
    );
  }
}
