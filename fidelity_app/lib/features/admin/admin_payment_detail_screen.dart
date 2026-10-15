import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/l10n/translator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/image_source.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/person_avatar.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../payments/data/payments_repository.dart';
import 'widgets/admin_widgets.dart';
import 'widgets/payment_review.dart';

/// Detalle de un pago para el administrador: la foto del comprobante, los
/// datos del pago, toda la información del negocio y de su dueño, y los
/// botones para validar o rechazar.
///
/// Cierra con `true` si el pago cambió (se validó o se rechazó).
class AdminPaymentDetailScreen extends StatefulWidget {
  final String paymentId;

  /// Lo que ya se conoce del pago (se muestra mientras carga el detalle).
  final PaymentOrder? preview;

  /// Acceso a los datos (se puede reemplazar en las pruebas).
  final PaymentsRepository? repository;

  const AdminPaymentDetailScreen({
    super.key,
    required this.paymentId,
    this.preview,
    this.repository,
  });

  @override
  State<AdminPaymentDetailScreen> createState() => _AdminPaymentDetailScreenState();
}

class _AdminPaymentDetailScreenState extends State<AdminPaymentDetailScreen> {
  late final PaymentsRepository _repository = widget.repository ?? PaymentsRepository();

  PaymentOrder? _payment;
  bool _isLoading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _payment = widget.preview;
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final payment = await _repository.getOne(widget.paymentId);
      if (mounted) {
        setState(() {
          _payment = payment;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        DashboardAnimatedToast.show(context, 'No se pudo cargar el pago', isError: true);
      }
    }
  }

  Future<void> _validate() async {
    if (await reviewValidate(context, _payment!, _repository)) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _reject() async {
    if (await reviewReject(context, _payment!, _repository)) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: AdminPageFrame(
        title: 'Pago',
        body: payment == null
            ? const AdminLoading()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final sections = _sections(payment);
                  final wide = constraints.maxWidth >= 860;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [
                      if (_isLoading) const LinearProgressIndicator(color: AppColors.black),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Column(children: sections.$1)),
                            const SizedBox(width: 24),
                            Expanded(child: Column(children: sections.$2)),
                          ],
                        )
                      else
                        Column(children: [...sections.$1, ...sections.$2]),
                      if (payment.status.isOpenForReview) ...[
                        const SizedBox(height: 8),
                        AppPrimaryButton(label: 'Validar pago', onPressed: _validate),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppTextAction(label: 'Rechazar', onPressed: _reject),
                        ),
                      ],
                    ].animate(interval: 40.ms).fadeIn().slideY(begin: 0.04),
                  );
                },
              ),
      ),
    );
  }

  /// (pago y comprobante, negocio y dueño): dos columnas en pantallas anchas.
  (List<Widget>, List<Widget>) _sections(PaymentOrder payment) {
    return (
      [
        _PaymentSection(payment: payment),
        const SizedBox(height: 16),
        _ProofSection(payment: payment),
        const SizedBox(height: 16),
      ],
      [
        if (payment.businessInfo != null) ...[
          _BusinessSection(business: payment.businessInfo!),
          const SizedBox(height: 16),
        ],
        if (payment.ownerInfo != null) ...[
          _OwnerSection(owner: payment.ownerInfo!),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

extension on PaymentStatus {
  /// Un pago por revisar: aún sin pagar ni rechazar.
  bool get isOpenForReview => this == PaymentStatus.pending || this == PaymentStatus.reported;
}

String _formatDate(DateTime? date) =>
    date == null ? '—' : EcuadorDateUtils.formatEcuadorTime(date.toUtc().toIso8601String());

Future<void> _copy(BuildContext context, String text, String message) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PaymentSection extends StatelessWidget {
  final PaymentOrder payment;

  const _PaymentSection({required this.payment});

  @override
  Widget build(BuildContext context) {
    final (String label, AppChipStyle style) = switch (payment.status) {
      PaymentStatus.paid => ('Pagado', AppChipStyle.dark),
      PaymentStatus.reported => ('Reportado', AppChipStyle.pink),
      PaymentStatus.rejected => ('Rechazado', AppChipStyle.outline),
      PaymentStatus.pending => ('Sin reportar', AppChipStyle.outline),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'PAGO',
                  style: AppTypography.label(size: 12, tracking: 4),
                ),
              ),
              AppChip(label: label, style: style),
            ],
          ),
          const SizedBox(height: 4),
          Text(payment.amountLabel, style: AppTypography.display(size: 44)),
          Text(
            payment.conceptLabel,
            style: AppTypography.body(size: 15, weight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          _CopyLine(
            icon: Icons.tag_rounded,
            label: 'Referencia',
            value: payment.reference,
          ),
          if (payment.method != null)
            AdminInfoLine(icon: payment.method!.icon, text: payment.method!.label),
          if (payment.note?.isNotEmpty == true)
            AdminInfoLine(icon: Icons.notes_rounded, text: 'N.º ${payment.note}', strong: true),
          AdminInfoLine(icon: Icons.add_circle_outline_rounded, text: 'Creado ${_formatDate(payment.createdAt)}'),
          if (payment.reportedAt != null)
            AdminInfoLine(
              icon: Icons.schedule_rounded,
              text: 'Reportado ${_formatDate(payment.reportedAt)}',
            ),
          if (payment.paidAt != null)
            AdminInfoLine(
              icon: Icons.verified_outlined,
              text: 'Validado ${_formatDate(payment.paidAt)}',
            ),
          if (payment.receiptNumber != null)
            AdminInfoLine(
              icon: Icons.receipt_long_outlined,
              text: 'Comprobante ${payment.receiptNumber}',
            ),
          if (payment.status == PaymentStatus.rejected && payment.adminNote != null)
            AdminInfoLine(icon: Icons.info_outline_rounded, text: payment.adminNote!),
        ],
      ),
    );
  }
}

/// Foto del comprobante a tamaño completo; al tocarla se abre ampliada.
class _ProofSection extends StatelessWidget {
  final PaymentOrder payment;

  const _ProofSection({required this.payment});

  void _zoom(BuildContext context, ImageProvider image) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.white,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image(image: image, fit: BoxFit.contain),
            ),
            IconButton.filled(
              tooltip: context.tr('Cerrar'),
              style: IconButton.styleFrom(backgroundColor: AppColors.black),
              icon: const Icon(Icons.close_rounded, color: AppColors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = imageProviderFromUrl(payment.proofUrl);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COMPROBANTE DE PAGO', style: AppTypography.label(size: 12, tracking: 4)),
          const SizedBox(height: 12),
          if (image != null)
            MouseRegion(
              cursor: SystemMouseCursors.zoomIn,
              child: GestureDetector(
                onTap: () => _zoom(context, image),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image(
                    image: image,
                    width: double.infinity,
                    height: 360,
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Icon(Icons.image_not_supported_outlined, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    payment.method == PaymentMethod.card
                        ? 'Pago con tarjeta: no lleva foto de comprobante.'
                        : payment.status == PaymentStatus.pending
                            ? 'El dueño todavía no reportó su pago.'
                            : 'Este pago no tiene foto de comprobante.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(size: 14, weight: FontWeight.w300),
                  ),
                ],
              ),
            ),
          if (image != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Toca la foto para verla ampliada.',
                style: AppTypography.body(
                  size: 13,
                  weight: FontWeight.w300,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BusinessSection extends StatelessWidget {
  final PaymentBusiness business;

  const _BusinessSection({required this.business});

  Future<void> _openMap() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${business.latitude},${business.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final logo = imageProviderFromUrl(business.logoUrl);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEGOCIO', style: AppTypography.label(size: 12, tracking: 4)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: logo == null ? AppColors.black : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                  image: logo == null ? null : DecorationImage(image: logo, fit: BoxFit.cover),
                ),
                child: logo == null
                    ? const Icon(Icons.storefront_outlined, color: AppColors.white, size: 30)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name.toUpperCase(),
                      style: AppTypography.display(size: 28),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (business.category != null)
                          AppChip(label: business.category!, style: AppChipStyle.outline),
                        business.isActive
                            ? const AppChip(label: 'Activo', style: AppChipStyle.dark)
                            : const AppChip(label: 'Por activar'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (business.description != null) ...[
            const SizedBox(height: 12),
            Text(
              business.description!,
              style: AppTypography.body(size: 14, weight: FontWeight.w300),
            ),
          ],
          const SizedBox(height: 8),
          if (business.phone != null)
            _CopyLine(icon: Icons.phone_outlined, label: 'Teléfono', value: business.phone!),
          if (business.taxId != null)
            _CopyLine(icon: Icons.badge_outlined, label: 'Cédula o RUC', value: business.taxId!),
          if (business.address != null)
            AdminInfoLine(icon: Icons.place_outlined, text: business.address!),
          if (business.hasLocation)
            Align(
              alignment: Alignment.centerLeft,
              child: AppTextAction(label: 'Ver en el mapa', onPressed: _openMap),
            ),
          if (business.rewardDescription != null)
            AdminInfoLine(
              icon: Icons.card_giftcard_rounded,
              text: business.pointsRequired == null
                  ? business.rewardDescription!
                  : '${business.rewardDescription!} · ${business.pointsRequired} pts',
              strong: true,
            ),
          AdminInfoLine(
            icon: Icons.calendar_today_rounded,
            text: 'Registrado ${_formatDate(business.createdAt)}',
          ),
        ],
      ),
    );
  }
}

class _OwnerSection extends StatelessWidget {
  final PaymentOwner owner;

  const _OwnerSection({required this.owner});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DUEÑO', style: AppTypography.label(size: 12, tracking: 4)),
          const SizedBox(height: 12),
          Row(
            children: [
              PersonAvatar(name: owner.displayName, avatarUrl: owner.avatarUrl, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  owner.displayName,
                  style: AppTypography.body(size: 18, weight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CopyLine(icon: Icons.mail_outline_rounded, label: 'Correo', value: owner.email),
          if (owner.phone != null && owner.phone!.isNotEmpty)
            _CopyLine(icon: Icons.phone_outlined, label: 'Teléfono', value: owner.phone!),
        ],
      ),
    );
  }
}

/// Línea de información con el valor y un botón para copiarlo.
class _CopyLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CopyLine({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: AppTypography.body(size: 14, weight: FontWeight.w500),
            ),
          ),
          IconButton(
            tooltip: context.tr('Copiar'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => _copy(context, value, '$label copiado'),
          ),
        ],
      ),
    );
  }
}
