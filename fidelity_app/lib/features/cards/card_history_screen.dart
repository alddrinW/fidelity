import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/validators/app_validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_pill_tab_bar.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/app_text_field.dart';
import '../feedback/widgets/feedback_sheet.dart';
import 'providers/card_history_provider.dart';
import '../../core/l10n/tr_text.dart';

/// Historial de una tarjeta: escaneos (con su estado de aprobación) y premios
/// (por reclamar, entregados o rechazados), con transferencia de premios.
class CardHistoryScreen extends ConsumerStatefulWidget {
  final String loyaltyCardId;
  final String businessId;
  final String businessName;
  final int initialTabIndex;

  const CardHistoryScreen({
    super.key,
    required this.loyaltyCardId,
    required this.businessId,
    required this.businessName,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<CardHistoryScreen> createState() => _CardHistoryScreenState();
}

class _CardHistoryScreenState extends ConsumerState<CardHistoryScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(cardHistoryProvider.notifier).init(widget.loyaltyCardId, widget.businessId);
  }

  Future<void> _selectDateRange(DateTimeRange? currentRange) async {
    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: currentRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.black,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      ref.read(cardHistoryProvider.notifier).updateDateRange(pickedRange);
    }
  }

  /// Solo se transfiere un premio que aún no se reclamó (HU-04): uno
  /// entregado o rechazado ya no tiene sentido transferirlo.
  bool _canTransfer(Map<String, dynamic> reward) =>
      (reward['status'] ?? 'pending') == 'pending';

  void _openTransferSheet(Map<String, dynamic> reward) {
    ref.read(cardHistoryProvider.notifier).clearTransferState();
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => _TransferSheet(
        rewardId: reward['id'] as String,
        onTransferred: (message) => messenger.showSnackBar(SnackBar(content: Text(message))),
      ),
    );
  }

  String _formatDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardHistoryProvider);
    final range = state.dateRange;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        body: SafeArea(
          child: AppResponsiveBody(
            adaptive: true,
            child: Column(
              children: [
                AppPageHeader(
                  title: widget.businessName,
                  trailing: IconButton(
                    tooltip: 'Filtrar por fechas',
                    icon: Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.black,
                      size: range == null ? 26 : 22,
                    ),
                    style: range == null
                        ? null
                        : IconButton.styleFrom(backgroundColor: AppColors.pink),
                    onPressed: () => _selectDateRange(range),
                  ),
                ),
                if (range != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppChip(
                          label: '${_formatDay(range.start)} - ${_formatDay(range.end)}',
                          icon: Icons.filter_alt_outlined,
                        ),
                        IconButton(
                          tooltip: 'Quitar filtro',
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () =>
                              ref.read(cardHistoryProvider.notifier).updateDateRange(null),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.center,
                  child: AppTextAction(
                    label: 'Sugerencia o reclamo',
                    onPressed: () => showFeedbackSheet(
                      context,
                      businessId: widget.businessId,
                      businessName: widget.businessName,
                    ),
                  ),
                ),
                const AppPillTabBar(labels: ['Escaneos', 'Premios']),
                const SizedBox(height: 16),
                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          children: [
                            _buildList(
                              state,
                              state.scans,
                              emptyTitle: 'Sin actividad',
                              emptyMessage: 'Tus escaneos aparecerán aquí.',
                              tileBuilder: (item) => _ScanTile(item: item),
                            ),
                            _buildList(
                              state,
                              state.rewards,
                              emptyTitle: 'Sin premios',
                              emptyMessage: 'Cuando completes la tarjeta, tu premio aparecerá aquí.',
                              tileBuilder: (item) => _RewardTile(
                                item: item,
                                onTransfer: _canTransfer(item) ? () => _openTransferSheet(item) : null,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    CardHistoryState state,
    List<Map<String, dynamic>> items, {
    required String emptyTitle,
    required String emptyMessage,
    required Widget Function(Map<String, dynamic>) tileBuilder,
  }) {
    if (items.isEmpty) {
      if (state.error != null) {
        return const AppEmptyState(
          title: 'Algo salió mal',
          message: 'No pudimos cargar tu historial. Desliza hacia abajo o vuelve a intentarlo.',
        );
      }
      return AppEmptyState(title: emptyTitle, message: emptyMessage);
    }

    return RefreshIndicator(
      color: AppColors.black,
      onRefresh: () => ref.read(cardHistoryProvider.notifier).loadHistory(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => tileBuilder(items[index])
            .animate(delay: (index.clamp(0, 6) * 60).ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.06, curve: Curves.easeOutCubic),
      ),
    );
  }
}

/// Círculo gris con el icono del movimiento.
class _TileIcon extends StatelessWidget {
  final IconData icon;

  const _TileIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(color: AppColors.surfaceMuted, shape: BoxShape.circle),
      child: Icon(icon, size: 24, color: AppColors.black),
    );
  }
}

class _ScanTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ScanTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] ?? 'approved').toString();
    // Sin QR el punto lo otorgó el negocio a mano.
    final isGifted = item['qr_code_id'] == null;

    final IconData icon;
    final String title;
    final String subtitle;
    final AppChip? chip;

    switch (status) {
      case 'pending':
        icon = Icons.hourglass_top_rounded;
        title = 'Escaneo en revisión';
        subtitle = 'El local aún debe aprobarlo';
        chip = const AppChip(label: 'Pendiente');
      case 'rejected':
        icon = Icons.block_rounded;
        title = 'Escaneo rechazado';
        subtitle = 'No se sumó ningún punto';
        chip = const AppChip(label: 'Rechazado', style: AppChipStyle.outline);
      default:
        icon = isGifted ? Icons.redeem_rounded : Icons.qr_code_scanner_rounded;
        title = '+1 punto';
        subtitle = isGifted ? 'Regalo del negocio' : 'Por escaneo de QR';
        chip = null;
    }

    return AppCard(
      child: Row(
        children: [
          _TileIcon(icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: AppTypography.label(size: 14, tracking: 1)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.body(size: 14, weight: FontWeight.w300)),
                const SizedBox(height: 4),
                Text(
                  EcuadorDateUtils.formatEcuadorTime(item['scanned_at']).toUpperCase(),
                  style: AppTypography.body(
                    size: 11,
                    weight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (chip != null) ...[const SizedBox(width: 8), chip],
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTransfer;

  const _RewardTile({required this.item, this.onTransfer});

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] ?? 'pending').toString();
    final title = (item['businesses']?['reward_description'] ?? item['reward_description'] ?? 'Premio')
        .toString();
    final description = item['description']?.toString();

    final AppChip chip;
    String? note;
    switch (status) {
      case 'approved':
      case 'claimed':
        chip = const AppChip(label: 'Entregado', style: AppChipStyle.dark);
      case 'rejected':
        chip = const AppChip(label: 'Rechazado', style: AppChipStyle.outline);
      default:
        chip = const AppChip(label: 'Por reclamar');
        note = 'Muéstralo en el local para reclamarlo.';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TileIcon(Icons.card_giftcard_rounded),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(), style: AppTypography.display(size: 22)),
                    if (description != null &&
                        description.isNotEmpty &&
                        description.toLowerCase() != title.toLowerCase())
                      Text(
                        description,
                        style: AppTypography.body(size: 14, weight: FontWeight.w300),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'GANADO: ${EcuadorDateUtils.formatEcuadorTime(item['earned_at']).toUpperCase()}',
                      style: AppTypography.body(
                        size: 11,
                        weight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              chip,
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 12),
            Text(note, style: AppTypography.body(size: 14, weight: FontWeight.w300)),
          ],
          if (onTransfer != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onTransfer,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('TRANSFERIR A UN AMIGO'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.black,
                side: const BorderSide(color: AppColors.black, width: 1.2),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                textStyle: AppTypography.label(size: 11, tracking: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hoja inferior para transferir un premio por correo. Es un widget propio
/// para que el controlador y la clave del formulario se liberen con ella.
class _TransferSheet extends ConsumerStatefulWidget {
  final String rewardId;
  final void Function(String message) onTransferred;

  const _TransferSheet({required this.rewardId, required this.onTransferred});

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _shareAppLink() async {
    const message =
        '¡Descarga Fidelity! Tu amigo te transferirá un premio. Descarga aquí: https://fidelity.app/download';
    // ignore: deprecated_member_use
    await Share.share(message);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(cardHistoryProvider.notifier)
        .transferReward(widget.rewardId, _emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardHistoryProvider);

    ref.listen<CardHistoryState>(cardHistoryProvider, (prev, next) {
      if (prev?.transferSuccessMessage == null && next.transferSuccessMessage != null) {
        Navigator.of(context).pop();
        widget.onTransferred(next.transferSuccessMessage!);
      }
    });

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'TRANSFERIR PREMIO',
                  textAlign: TextAlign.center,
                  style: AppTypography.display(size: 30),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa el correo de tu amigo para transferirle este premio.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(size: 15, weight: FontWeight.w300),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _emailController,
                  hint: 'Correo del destinatario',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: AppValidators.validateEmail,
                ),
                if (state.transferErrorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.pink.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.transferErrorMessage!,
                          style: AppTypography.body(size: 14, weight: FontWeight.w500),
                        ),
                        if (state.showInviteButton) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _shareAppLink,
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: const Text('INVITAR A UN AMIGO'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.black,
                              side: const BorderSide(color: AppColors.black, width: 1.2),
                              shape: const StadiumBorder(),
                              textStyle: AppTypography.label(size: 11, tracking: 1.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: 'Transferir',
                  isLoading: state.isTransferLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 4),
                Center(
                  child: AppTextAction(
                    label: 'Cancelar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
