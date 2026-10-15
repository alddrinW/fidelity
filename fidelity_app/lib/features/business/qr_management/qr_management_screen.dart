import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/api_client.dart';
import '../../../core/services/realtime_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/file_download.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_message_dialog.dart';
import '../dashboard/widgets/dashboard_animated_toast.dart';
import '../../../core/l10n/tr_text.dart';

/// Códigos QR del negocio: ver, descargar como imagen o PDF para imprimir y,
/// si un código quedó dañado, regenerarlo.
class QRManagementScreen extends StatefulWidget {
  final String businessId;
  const QRManagementScreen({super.key, required this.businessId});

  @override
  State<QRManagementScreen> createState() => _QRManagementScreenState();
}

class _QRManagementScreenState extends State<QRManagementScreen> {
  List<Map<String, dynamic>> _qrCodes = [];
  bool _isLoading = true;

  StreamSubscription<void>? _qrCodesSub;

  @override
  void initState() {
    super.initState();
    _loadQRCodes();
    _qrCodesSub = RealtimeSyncService().onQrCodesChanged.listen((_) {
      if (mounted) _loadQRCodes();
    });
  }

  @override
  void dispose() {
    _qrCodesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadQRCodes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().get('qr-codes/business/${widget.businessId}');

      if (mounted) {
        setState(() {
          if (response is List) {
            _qrCodes = response
                .map((q) => {
                      'id': q['id'],
                      'business_id': q['businessId'] ?? q['business_id'],
                      'qr_code': q['qrCode'] ?? q['qr_code'],
                      'label': q['label'] ?? 'Código QR',
                      'is_active': q['isActive'] ?? q['is_active'] ?? true,
                      'created_at': q['createdAt'] ?? q['created_at'],
                    })
                .toList();
          } else {
            _qrCodes = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading QR codes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateFirstQRCode() async {
    setState(() => _isLoading = true);
    try {
      final newCode = const Uuid().v4();
      await ApiClient().post('qr-codes', body: {
        'businessId': widget.businessId,
        'qrCode': newCode,
        'label': 'Código QR Único',
      });
      await _loadQRCodes();
      if (mounted) {
        DashboardAnimatedToast.show(context, 'Código QR generado');
      }
    } catch (e) {
      if (mounted) {
        DashboardAnimatedToast.show(context, 'Error al generar QR: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _cleanLabel(String label) =>
      label.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');

  Future<void> _shareQRImage(String code, String label) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando y guardando imagen...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final painter = QrPainter(
        data: code,
        version: QrVersions.auto,
        gapless: true,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );

      final picRecorder = ui.PictureRecorder();
      final canvas = Canvas(picRecorder);

      // Fondo blanco (900x900) y el QR con margen en el centro.
      canvas.drawRect(const Rect.fromLTWH(0, 0, 900, 900), Paint()..color = Colors.white);
      canvas.translate(50, 50);
      painter.paint(canvas, const Size(800, 800));

      final image = await picRecorder.endRecording().toImage(900, 900);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      final cleanLabel = _cleanLabel(label);

      // En el navegador no hay galería ni carpeta temporal: se descarga el PNG.
      if (kIsWeb) {
        downloadBytesInBrowser(pngBytes, 'qr_$cleanLabel.png', 'image/png');
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          DashboardAnimatedToast.show(
            context,
            'Imagen descargada. Búscala en tu carpeta de descargas.',
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/qr_$cleanLabel.png').create();
      await file.writeAsBytes(pngBytes);

      // Guardar en la galería primero
      try {
        final hasAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAccess) {
          await Gal.requestAccess(toAlbum: true);
        }
        await Gal.putImage(file.path, album: 'Fidelity');
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showDialog<void>(
            context: context,
            builder: (_) => const AppMessageDialog(
              icon: Icons.check_circle_outline_rounded,
              title: '¡Código guardado!',
              message: 'La imagen del código QR se guardó en tu galería de fotos.',
              primaryLabel: 'Listo',
            ),
          );
        }
      } catch (e) {
        debugPrint('Error guardando en galería: $e');
      }

      if (mounted) {
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Código QR: $label',
          subject: 'QR Fidelity - $label',
        );
      }
    } catch (e) {
      if (mounted) {
        DashboardAnimatedToast.show(context, 'Error al compartir imagen: $e', isError: true);
      }
    }
  }

  Future<void> _shareQRPdf(String code, String label) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando PDF...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final doc = pw.Document();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    label,
                    style: pw.TextStyle(fontSize: 40, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 32),
                  pw.Stack(
                    alignment: pw.Alignment.center,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(
                          errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high,
                        ),
                        data: code,
                        width: 300,
                        height: 300,
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    code,
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 32),
                  pw.Text(
                    'Escanea este código para ganar puntos',
                    style: const pw.TextStyle(fontSize: 20),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final bytes = await doc.save();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        DashboardAnimatedToast.show(
          context,
          'PDF generado. Guárdalo o compártelo para imprimirlo.',
        );
      }

      // sharePdf abre "Guardar en Archivos" o "Compartir" en el teléfono, y
      // descarga el archivo en el navegador.
      await Printing.sharePdf(bytes: bytes, filename: 'qr_${_cleanLabel(label)}.pdf');
    } catch (e) {
      if (mounted) {
        DashboardAnimatedToast.show(context, 'Error al generar PDF: $e', isError: true);
      }
    }
  }

  void _showQRDialog(String code, String label) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTypography.display(size: 30),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.black, width: 1.2),
                ),
                child: QrImageView(
                  data: code,
                  version: QrVersions.auto,
                  size: 220,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                code,
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  size: 11,
                  weight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _QrActionButton(
                      icon: Icons.image_outlined,
                      label: 'Imagen',
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _shareQRImage(code, label);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QrActionButton(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'PDF',
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _shareQRPdf(code, label);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppPrimaryButton(label: 'Listo', onPressed: () => Navigator.pop(dialogContext)),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRegenerateQR(int index, String label) {
    showDialog<void>(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.refresh_rounded,
        title: 'Regenerar QR',
        message: 'El código actual dejará de funcionar. ¿Estás seguro?',
        primaryLabel: 'Regenerar',
        onPrimary: () => _regenerateQR(index, label),
        secondaryLabel: 'Cancelar',
      ),
    );
  }

  Future<void> _regenerateQR(int index, String label) async {
    try {
      final newCode = const Uuid().v4();
      final qrId = _qrCodes[index]['id'];

      if (qrId == null) throw Exception('ID de QR no encontrado');

      await ApiClient().patch('qr-codes/$qrId', body: {'qrCode': newCode});

      setState(() {
        _qrCodes[index]['qr_code'] = newCode;
      });

      if (mounted) {
        DashboardAnimatedToast.show(context, 'QR regenerado correctamente');
        _showQRDialog(newCode, label);
      }
    } catch (e) {
      if (mounted) {
        DashboardAnimatedToast.show(context, 'Error al regenerar: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_qrCodes.isEmpty) {
      return Column(
        children: [
          const Expanded(
            child: AppEmptyState(
              title: 'Sin códigos QR',
              message: 'Genera uno para empezar a recibir clientes.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 8, 48, 32),
            child: AppPrimaryButton(label: 'Generar mi QR', onPressed: _generateFirstQRCode),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      itemCount: _qrCodes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final qr = _qrCodes[index];
        final String safeCode = (qr['qr_code'] ?? '').toString();
        final String safeLabel = (qr['label'] ?? 'QR').toString();
        final String displayDate =
            EcuadorDateUtils.formatEcuadorDate((qr['created_at'] ?? '').toString());
        final bool isCorrupt = safeCode.isEmpty;

        return AppCard(
          onTap: () => isCorrupt
              ? _confirmRegenerateQR(index, safeLabel)
              : _showQRDialog(safeCode, safeLabel),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isCorrupt ? AppColors.pink : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCorrupt ? Icons.warning_amber_rounded : Icons.qr_code_2_rounded,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(safeLabel.toUpperCase(), style: AppTypography.display(size: 22)),
                    Text(
                      isCorrupt
                          ? 'Código dañado: toca para regenerarlo'
                          : 'Creado el $displayDate',
                      style: AppTypography.body(
                        size: 14,
                        weight: FontWeight.w300,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 32),
            ],
          ),
        )
            .animate(delay: (index.clamp(0, 6) * 50).ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.06, curve: Curves.easeOutCubic);
      },
    );
  }
}

class _QrActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _QrActionButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label.toUpperCase()),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.black,
        side: const BorderSide(color: AppColors.black, width: 1.2),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: AppTypography.label(size: 12, tracking: 2),
      ),
    );
  }
}
