import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/tr_text.dart';
import '../../../core/l10n/translator.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/realtime_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/file_download.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_message_dialog.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_responsive_body.dart';
import '../dashboard/widgets/dashboard_animated_toast.dart';
import 'qr_poster.dart';

/// "Mi código": el cartel del código QR del local (logo, nombre, código y lo que se gana)
/// sobre fondo rosa, con tres acciones: imprimir el cartel, compartirlo y descargarlo.
/// Si el código quedó dañado, se puede regenerar.
class QRManagementScreen extends StatefulWidget {
  final String businessId;

  /// Los datos del negocio (nombre, logo, puntos y premio), tal como los devuelve el backend.
  final Map<String, dynamic>? business;

  /// De dónde salen los códigos (en las pruebas se cambia por unos de mentira).
  final Future<List<Map<String, dynamic>>> Function()? codesLoader;

  const QRManagementScreen({super.key, required this.businessId, this.business, this.codesLoader});

  @override
  State<QRManagementScreen> createState() => _QRManagementScreenState();
}

class _QRManagementScreenState extends State<QRManagementScreen> {
  List<Map<String, dynamic>> _qrCodes = [];
  bool _isLoading = true;
  bool _working = false;

  /// El código que se está viendo cuando el local tiene más de uno.
  int _selected = 0;

  /// Para sacar la imagen del cartel tal como se ve.
  final _posterKey = GlobalKey();

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

  Map<String, dynamic>? get _business => widget.business;
  String get _name => (_business?['name'] ?? 'Mi local').toString();
  String? get _logoUrl => (_business?['logoUrl'] ?? _business?['logo_url'])?.toString();

  Future<List<Map<String, dynamic>>> _fetchCodes() async {
    final loader = widget.codesLoader;
    if (loader != null) return loader();
    final response = await ApiClient().get('qr-codes/business/${widget.businessId}');
    if (response is! List) return [];
    return response
        .map((q) => <String, dynamic>{
              'id': q['id'],
              'business_id': q['businessId'] ?? q['business_id'],
              'qr_code': q['qrCode'] ?? q['qr_code'],
              'label': q['label'] ?? 'Código QR',
              'is_active': q['isActive'] ?? q['is_active'] ?? true,
              'created_at': q['createdAt'] ?? q['created_at'],
            })
        .toList();
  }

  Future<void> _loadQRCodes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final codes = await _fetchCodes();
      if (mounted) {
        setState(() {
          _qrCodes = codes;
          if (_selected >= _qrCodes.length) _selected = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading QR codes: $e');
      if (mounted) setState(() => _isLoading = false);
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
      if (mounted) DashboardAnimatedToast.show(context, 'Código QR generado');
    } catch (e) {
      if (mounted) {
        DashboardAnimatedToast.show(context, 'Error al generar QR: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fileName(String ext) {
    final clean = _name.replaceAll(RegExp(r'[^\w\s]+'), '').trim().replaceAll(RegExp(r'\s+'), '_');
    return 'qr_${clean.isEmpty ? 'fidelity' : clean}.$ext';
  }

  /// La imagen del cartel tal como se ve en pantalla (en alta resolución).
  Future<Uint8List> _posterPng() async {
    final boundary = _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('El cartel todavía no está listo');
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  void _error(String what, Object e) {
    if (mounted) DashboardAnimatedToast.show(context, '$what: $e', isError: true);
  }

  /// Imprime el cartel (abre el diálogo de impresión; también sirve para guardarlo como PDF).
  Future<void> _print() async {
    if (_working) return;
    final qr = _current;
    if (qr == null) return;
    setState(() => _working = true);
    try {
      final bytes = await buildQrPosterPdf(
        code: qr,
        name: _name,
        logoUrl: _logoUrl,
        pointsLine: qrPointsLine(_business),
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: _fileName('pdf'));
    } catch (e) {
      _error('Error al preparar el cartel', e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Comparte la imagen del cartel (WhatsApp, correo...). En el navegador la descarga.
  Future<void> _share() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final bytes = await _posterPng();
      if (kIsWeb) {
        downloadBytesInBrowser(bytes, _fileName('png'), 'image/png');
        if (mounted) {
          DashboardAnimatedToast.show(context, 'Imagen descargada. Búscala en tu carpeta de descargas.');
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/${_fileName('png')}').writeAsBytes(bytes);
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: 'Mi código de $_name en Fidelity');
    } catch (e) {
      _error('Error al compartir', e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Guarda la imagen del cartel: en la galería (teléfono) o en descargas (navegador).
  Future<void> _download() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final bytes = await _posterPng();
      if (kIsWeb) {
        downloadBytesInBrowser(bytes, _fileName('png'), 'image/png');
        if (mounted) {
          DashboardAnimatedToast.show(context, 'Imagen descargada. Búscala en tu carpeta de descargas.');
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/${_fileName('png')}').writeAsBytes(bytes);
      if (!await Gal.hasAccess(toAlbum: true)) await Gal.requestAccess(toAlbum: true);
      await Gal.putImage(file.path, album: 'Fidelity');
      if (mounted) {
        await showDialog<void>(
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
      _error('Error al descargar', e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _confirmRegenerateQR(int index) {
    showDialog<void>(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.refresh_rounded,
        title: 'Regenerar QR',
        message: 'El código actual dejará de funcionar. ¿Estás seguro?',
        hint: 'Tendrás que volver a imprimir tu cartel con el código nuevo.',
        primaryLabel: 'Regenerar',
        onPrimary: () => _regenerateQR(index),
        secondaryLabel: 'Cancelar',
      ),
    );
  }

  Future<void> _regenerateQR(int index) async {
    try {
      final newCode = const Uuid().v4();
      final qrId = _qrCodes[index]['id'];
      if (qrId == null) throw Exception('ID de QR no encontrado');

      await ApiClient().patch('qr-codes/$qrId', body: {'qrCode': newCode});
      setState(() => _qrCodes[index]['qr_code'] = newCode);
      if (mounted) DashboardAnimatedToast.show(context, 'QR regenerado correctamente');
    } catch (e) {
      _error('Error al regenerar', e);
    }
  }

  /// El código que se está viendo (`null` si está dañado o no hay).
  String? get _current {
    if (_qrCodes.isEmpty) return null;
    final code = (_qrCodes[_selected]['qr_code'] ?? '').toString();
    return code.isEmpty ? null : code;
  }

  @override
  Widget build(BuildContext context) {
    final showPoster = !_isLoading && _current != null;

    return Scaffold(
      // Con el cartel, toda la pantalla es rosa (como en el diseño).
      backgroundColor: showPoster ? AppColors.pink : null,
      body: SafeArea(
        child: AppResponsiveBody(
          maxWidth: 640,
          adaptive: true,
          child: Column(
            children: [
              showPoster ? const _PosterHeader() : const AppPageHeader(title: 'Mi código QR'),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.black));

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

    final code = _current;
    if (code == null) {
      // El código quedó dañado: se ofrece regenerarlo.
      return Column(
        children: [
          const Expanded(
            child: AppEmptyState(
              title: 'Código dañado',
              message: 'Este código no se puede mostrar. Regéneralo para volver a recibir clientes.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 8, 48, 32),
            child: AppPrimaryButton(label: 'Regenerar QR', onPressed: () => _confirmRegenerateQR(_selected)),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        children: [
          // Solo con más de un código: cuál se muestra.
          if (_qrCodes.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < _qrCodes.length; i++)
                    ChoiceChip(
                      label: Text((_qrCodes[i]['label'] ?? 'QR').toString()),
                      selected: i == _selected,
                      onSelected: (_) => setState(() => _selected = i),
                    ),
                ],
              ),
            ),
          RepaintBoundary(
            key: _posterKey,
            child: QrPosterCard(
              code: code,
              name: _name,
              logoUrl: _logoUrl,
              pointsLine: qrPointsLine(_business),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _PosterAction(icon: Icons.print_outlined, label: 'Imprimir cartel', filled: true, onTap: _working ? null : _print),
              _PosterAction(icon: Icons.share_outlined, label: 'Compartir', onTap: _working ? null : _share),
              _PosterAction(icon: Icons.download_rounded, label: 'Descargar', onTap: _working ? null : _download),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _confirmRegenerateQR(_selected),
            child: Text(
              'Regenerar código',
              style: AppTypography.body(size: 14, weight: FontWeight.w400, color: AppColors.black),
            ),
          ),
        ],
      ),
    );
  }
}

/// La flecha de volver y "MI CÓDIGO", sobre el fondo rosa.
class _PosterHeader extends StatelessWidget {
  const _PosterHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: context.tr('Atrás'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              'MI CÓDIGO',
              textAlign: TextAlign.center,
              style: AppTypography.label(size: 14, tracking: 5),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Un botón del cartel: el primero relleno de negro, los demás con borde.
class _PosterAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _PosterAction({required this.icon, required this.label, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? AppColors.white : AppColors.black;
    return Material(
      color: filled ? AppColors.black : AppColors.white,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.black, width: 1.2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Text(label, style: AppTypography.body(size: 14, weight: FontWeight.w500, color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}
