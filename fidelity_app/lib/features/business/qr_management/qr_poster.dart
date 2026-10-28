import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/l10n/tr_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_source.dart';

/// "10 puntos = café gratis": lo que gana el cliente en este local. Sin esos datos,
/// `null` (el cartel dice solo que cada visita suma puntos).
String? qrPointsLine(Map<String, dynamic>? business) {
  if (business == null) return null;
  final points = (business['pointsRequired'] ?? business['points_required']) as num?;
  final reward = (business['rewardDescription'] ?? business['reward_description'])?.toString().trim() ?? '';
  if (points == null || points <= 0 || reward.isEmpty) return null;
  return '${points.toInt()} puntos = $reward';
}

/// El cartel del código QR del local, como se ve en pantalla (y como se guarda o se
/// comparte como imagen): fondo blanco, el logo, el nombre, el código en una caja blanca
/// y lo que se gana al escanear.
class QrPosterCard extends StatelessWidget {
  final String code;
  final String name;
  final String? logoUrl;

  /// "10 puntos = café gratis" (ver [qrPointsLine]).
  final String? pointsLine;

  const QrPosterCard({super.key, required this.code, required this.name, this.logoUrl, this.pointsLine});

  @override
  Widget build(BuildContext context) {
    final logo = imageProviderFromUrl(logoUrl);

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.black, width: 1.2),
              image: logo == null ? null : DecorationImage(image: logo, fit: BoxFit.cover),
            ),
            child: logo == null ? const Icon(Icons.storefront_outlined, size: 38) : null,
          ),
          const SizedBox(height: 14),
          Text(
            name.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.display(size: 34),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.black, width: 1.2),
            ),
            child: Semantics(
              label: 'Código QR de $name',
              image: true,
              child: QrImageView(
                data: code,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: AppColors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Dos renglones, como en el diseño (cada uno se traduce por separado).
          Text('ESCANEA Y', textAlign: TextAlign.center, style: AppTypography.display(size: 34).copyWith(height: 1.05)),
          Text('SUMA PUNTOS', textAlign: TextAlign.center, style: AppTypography.display(size: 34).copyWith(height: 1.05)),
          const SizedBox(height: 6),
          Text(
            pointsLine ?? 'Cada visita suma puntos',
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 15, weight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

/// El logo del local como imagen del PDF (`null` si no tiene o no se pudo leer).
Future<pw.ImageProvider?> _pdfLogo(String? url) async {
  if (url == null || url.isEmpty) return null;
  try {
    final provider = imageProviderFromUrl(url);
    if (provider is MemoryImage) return pw.MemoryImage(provider.bytes);
    if (url.startsWith('http')) return await networkImage(url);
  } catch (_) {
    // Sin logo, el cartel sale igual.
  }
  return null;
}

/// El cartel para imprimir (A4): el mismo diseño que en pantalla, con el código bien grande.
Future<Uint8List> buildQrPosterPdf({
  required String code,
  required String name,
  String? logoUrl,
  String? pointsLine,
}) async {
  final logo = await _pdfLogo(logoUrl);
  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) => pw.Container(
        width: double.infinity,
        height: double.infinity,
        color: PdfColors.white,
        padding: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 56),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Container(
              width: 120,
              height: 120,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                shape: pw.BoxShape.circle,
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              child: logo == null
                  ? pw.Center(
                      child: pw.Text(
                        name.isEmpty ? '' : name.characters.first.toUpperCase(),
                        style: pw.TextStyle(fontSize: 56, fontWeight: pw.FontWeight.bold),
                      ),
                    )
                  : pw.ClipOval(child: pw.Image(logo, fit: pw.BoxFit.cover)),
            ),
            pw.SizedBox(height: 22),
            pw.Text(
              name.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 44, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 26),
            pw.Container(
              padding: const pw.EdgeInsets.all(26),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(40),
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high),
                data: code,
                width: 330,
                height: 330,
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'ESCANEA Y\nSUMA PUNTOS',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 46, fontWeight: pw.FontWeight.bold, lineSpacing: 2),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              pointsLine ?? 'Cada visita suma puntos',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 22),
            ),
            pw.SizedBox(height: 34),
            pw.Text('FIDELITY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 6)),
          ],
        ),
      ),
    ),
  );

  return doc.save();
}
