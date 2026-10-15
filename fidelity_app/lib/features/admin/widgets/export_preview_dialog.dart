import 'package:flutter/material.dart' hide Text;

import '../../../core/services/export_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_message_dialog.dart';
import '../../../core/l10n/tr_text.dart';

/// Vista previa de la exportación a CSV: indica cuántos registros se
/// exportarán y bloquea la acción si se supera el límite.
class ExportPreviewDialog extends StatelessWidget {
  static const int maxRows = 5000;

  final List<Map<String, dynamic>> data;
  final ExportEntity entity;
  final ExportService exportService;

  const ExportPreviewDialog({
    super.key,
    required this.data,
    required this.entity,
    required this.exportService,
  });

  Future<void> _export(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final rootContext = navigator.context;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.white),
      ),
    );

    try {
      final csvContent = await exportService.generateCsv(data, entity);
      navigator.pop(); // cierra el indicador de carga

      final filename =
          'fidelity_export_${entity.name}_${DateTime.now().millisecondsSinceEpoch}.csv';
      await exportService.shareCsv(csvContent, filename);
      navigator.pop(); // cierra esta vista previa
    } on ExportException catch (e) {
      navigator.pop(); // cierra el indicador de carga
      if (rootContext.mounted) {
        showDialog(
          context: rootContext,
          builder: (_) => AppMessageDialog(
            icon: Icons.error_outline_rounded,
            title: 'No se pudo exportar',
            message: e.message,
          ),
        );
      }
    } catch (_) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ocurrió un error al exportar.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOverLimit = data.length > maxRows;

    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
            child: Icon(
              isOverLimit ? Icons.warning_amber_rounded : Icons.download_rounded,
              size: 44,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            (isOverLimit ? 'Límite excedido' : 'Exportar a CSV').toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTypography.display(size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            isOverLimit
                ? 'El máximo permitido es $maxRows filas. Ajusta los filtros e inténtalo de nuevo.'
                : 'Se exportarán ${data.length} ${data.length == 1 ? 'registro' : 'registros'} '
                    'según los filtros activos.',
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 16, weight: FontWeight.w400),
          ),
        ],
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isOverLimit)
              SizedBox(
                width: double.infinity,
                height: 66,
                child: ElevatedButton(
                  onPressed: () => _export(context),
                  child: Text(
                    'EXPORTAR',
                    style: AppTypography.label(size: 16, tracking: 6, color: AppColors.white),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(isOverLimit ? 'Entendido' : 'Cancelar'),
            ),
          ],
        ),
      ],
    );
  }
}
