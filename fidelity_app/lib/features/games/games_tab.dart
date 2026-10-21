import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/fido_says.dart';
import '../admin/widgets/admin_widgets.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../campaigns/data/campaigns_repository.dart';
import '../campaigns/widgets/customer_picker_sheet.dart';
import '../campaigns/widgets/schedule_row.dart';
import 'data/games_repository.dart';

/// Pestaña "Juegos" del dueño. El administrador es quien asigna los minijuegos
/// y fija el premio: aquí el dueño los solicita y, una vez asignados, se los
/// manda a sus clientes (les llega una notificación que abre el juego).
class GamesTab extends ConsumerWidget {
  final String businessId;

  const GamesTab({super.key, required this.businessId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(gameAccessProvider(businessId));

    return RefreshIndicator(
      color: AppColors.black,
      onRefresh: () async {
        ref.invalidate(gameAccessProvider(businessId));
        ref.invalidate(sentGamesProvider(businessId));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          access.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(color: AppColors.black)),
            ),
            error: (e, _) => const FidoSays(
              sad: true,
              message: 'No pudimos cargar tus minijuegos. Desliza para reintentar.',
            ),
            data: (a) => switch (a.status) {
              GameAccessStatus.approved => _ApprovedView(access: a, businessId: businessId),
              GameAccessStatus.pending => const _PendingCard(),
              _ => _RequestCard(businessId: businessId, rejectedReason: a.adminNote),
            },
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final String businessId;
  final String? rejectedReason;

  const _RequestCard({required this.businessId, this.rejectedReason});

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    // null = canceló; un texto (puede ser vacío) = quiere enviar la solicitud.
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const _RequestNoteDialog(),
    );
    if (note == null || !context.mounted) return;

    try {
      await ref.read(gamesRepositoryProvider).request(businessId, note: note);
      ref.invalidate(gameAccessProvider(businessId));
      if (context.mounted) DashboardAnimatedToast.show(context, 'Solicitud enviada');
    } catch (e) {
      if (context.mounted) DashboardAnimatedToast.show(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rejected = rejectedReason?.trim().isNotEmpty ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FidoSays(
          celebrating: !rejected,
          sad: rejected,
          message: rejected
              ? 'No pudimos activar tus minijuegos: $rejectedReason'
              : 'Los minijuegos hacen que tus clientes vuelvan: tres en raya, ahorcado y Flappy Bird. '
                  '¡Pídelos al administrador!',
        ),
        const SizedBox(height: 20),
        AppPrimaryButton(
          label: rejected ? 'Volver a solicitar' : 'Solicitar minijuegos',
          onPressed: () => _request(context, ref),
        ),
      ],
    );
  }
}

/// Diálogo para pedir los minijuegos, con un mensaje opcional. Es un widget
/// propio para que el campo viva y se libere junto con el diálogo.
class _RequestNoteDialog extends StatefulWidget {
  const _RequestNoteDialog();

  @override
  State<_RequestNoteDialog> createState() => _RequestNoteDialogState();
}

class _RequestNoteDialogState extends State<_RequestNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text('SOLICITAR MINIJUEGOS', textAlign: TextAlign.center, style: AppTypography.display(size: 24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'El administrador revisará tu solicitud y te asignará los juegos.',
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 14, weight: FontWeight.w300),
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _controller,
            hint: 'Mensaje (opcional)',
            icon: Icons.notes_rounded,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('SOLICITAR'),
        ),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard();

  @override
  Widget build(BuildContext context) {
    return const FidoSays(
      message: 'Tu solicitud está en revisión. Cuando el administrador te asigne los juegos, te avisamos.',
    );
  }
}

class _ApprovedView extends ConsumerWidget {
  final GameAccess access;
  final String businessId;

  const _ApprovedView({required this.access, required this.businessId});

  Future<void> _send(BuildContext context, WidgetRef ref, GameKey game) async {
    final result = await showModalBottomSheet<SendResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => SendGameSheet(game: game, businessId: businessId, prize: access.prize),
    );
    if (result == null || !context.mounted) return;
    ref.invalidate(sentGamesProvider(businessId));
    final clients = result.sent == 1 ? 'cliente' : 'clientes';
    final later = result.startsAt != null && result.startsAt!.isAfter(DateTime.now());
    DashboardAnimatedToast.show(
      context,
      result.sent == 0
          ? 'Nadie nuevo para este juego: ya lo tenían o ya ganaron'
          : later
              ? 'Se enviará a ${result.sent} $clients el ${formatCampaignDateTime(result.startsAt!)}'
              : 'Enviado a ${result.sent} $clients',
      isError: result.sent == 0,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sent = ref.watch(sentGamesProvider(businessId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (access.prize != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.pink,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.black, width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PREMIO QUE GANAN', style: AppTypography.label(size: 11, tracking: 3)),
                      Text(
                        access.prize!.label.toUpperCase(),
                        style: AppTypography.display(size: 24),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Text(
            'Lo fija el administrador. Quien gana recibe una gift card.',
            style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        const AdminSectionLabel('Tus juegos'),
        for (final game in access.games) ...[
          AppCard(
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
                  child: Icon(game.icon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game.label, style: AppTypography.body(size: 17, weight: FontWeight.w500)),
                      Text(game.description, style: AppTypography.body(size: 13, weight: FontWeight.w300)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _send(context, ref, game),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('ENVIAR'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        const AdminSectionLabel('Lo que enviaste'),
        sent.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.black)),
          error: (_, __) => Text(
            'No pudimos cargar tus envíos.',
            style: AppTypography.body(size: 15, weight: FontWeight.w300),
          ),
          data: (s) => _SentSummary(sent: s),
        ),
      ],
    );
  }
}

class _SentSummary extends StatelessWidget {
  final SentGames sent;

  const _SentSummary({required this.sent});

  @override
  Widget build(BuildContext context) {
    if (sent.sent == 0) {
      return Text(
        'Todavía no has mandado ningún juego. Elige uno y toca ENVIAR.',
        style: AppTypography.body(size: 15, weight: FontWeight.w300),
      );
    }
    return Column(
      children: [
        AppCard(
          radius: 28,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _Stat(label: 'Enviados', value: sent.sent),
              _Stat(label: 'Jugaron', value: sent.played),
              _Stat(label: 'Ganaron', value: sent.won),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final item in sent.items.take(15)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.userName ?? 'Cliente'} · ${item.gameName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(size: 14, weight: FontWeight.w400),
                  ),
                ),
                const SizedBox(width: 8),
                AppChip(
                  label: switch ((item.status, item.result)) {
                    ('finished', 'won') => 'Ganó',
                    ('finished', _) => 'Perdió',
                    ('expired', _) => 'Venció',
                    ('upcoming', _) => 'Programado',
                    ('playing', _) => 'Jugando',
                    ('sent', _) when item.attempts > 0 => 'Intento ${item.attempts} de ${item.maxAttempts}',
                    _ => 'Enviado',
                  },
                  style: item.result == 'won' ? AppChipStyle.dark : AppChipStyle.outline,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: AppTypography.display(size: 26)),
          Text(
            label.toUpperCase(),
            style: AppTypography.label(size: 10, tracking: 2, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Hoja para mandar un juego: a todos los clientes o solo a los elegidos.
class SendGameSheet extends ConsumerStatefulWidget {
  final GameKey game;
  final String businessId;
  final GamePrize? prize;

  const SendGameSheet({super.key, required this.game, required this.businessId, this.prize});

  @override
  ConsumerState<SendGameSheet> createState() => _SendGameSheetState();
}

class _SendGameSheetState extends ConsumerState<SendGameSheet> {
  bool _selected = false;
  final Set<String> _recipients = {};
  bool _isSending = false;
  String? _error;

  // El horario: sin tocar nada empieza ya y dura 7 días.
  bool _scheduleStart = false;
  DateTime? _startsAt;
  bool _customEnd = false;
  DateTime? _endsAt;

  Future<void> _pick() async {
    final picked = await showCustomerPicker(
      context,
      repository: ref.read(campaignsRepositoryProvider),
      businessIds: [widget.businessId],
      initial: _recipients,
    );
    if (picked != null && mounted) {
      setState(() => _recipients
        ..clear()
        ..addAll(picked));
    }
  }

  Future<void> _send() async {
    if (_selected && _recipients.isEmpty) {
      setState(() => _error = 'Elige al menos un cliente.');
      return;
    }
    final problem = _scheduleProblem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      final result = await ref.read(gamesRepositoryProvider).send(
            widget.businessId,
            widget.game,
            selected: _selected,
            recipientIds: _recipients.toList(),
            startsAt: _scheduleStart ? _startsAt : null,
            endsAt: _customEnd ? _endsAt : null,
          );
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Lo que está mal en el horario elegido (o null si está bien).
  String? _scheduleProblem() {
    if (_scheduleStart && _startsAt == null) return 'Elige cuándo empieza el juego.';
    if (_customEnd && _endsAt == null) return 'Elige cuándo termina el juego.';
    final now = DateTime.now();
    final start = _scheduleStart ? _startsAt! : now;
    if (_scheduleStart && start.isBefore(now.subtract(const Duration(minutes: 1)))) {
      return 'La hora de inicio ya pasó.';
    }
    if (_customEnd && !_endsAt!.isAfter(start)) {
      return 'El juego debe terminar después de que empiece.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ENVIAR ${widget.game.label.toUpperCase()}',
                textAlign: TextAlign.center,
                style: AppTypography.display(size: 28),
              ),
              const SizedBox(height: 4),
              Text(
                widget.prize == null
                    ? 'A cada cliente le llega una notificación para jugar. Tiene 3 intentos para ganar.'
                    : 'Quien gane recibe: ${widget.prize!.label}. A cada cliente le llega una notificación para jugar. Tiene 3 intentos para ganar.',
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 14, weight: FontWeight.w300),
              ),
              const SizedBox(height: 18),
              const AdminSectionLabel('¿A quién se lo mandas?'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AdminFilterPill(
                    label: 'Todos mis clientes',
                    selected: !_selected,
                    onTap: () => setState(() => _selected = false),
                  ),
                  AdminFilterPill(
                    label: 'Clientes elegidos',
                    selected: _selected,
                    onTap: () => setState(() => _selected = true),
                  ),
                ],
              ),
              if (_selected) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.people_alt_outlined),
                  label: Text(
                    _recipients.isEmpty
                        ? 'ELEGIR CLIENTES'
                        : '${_recipients.length} ${_recipients.length == 1 ? 'CLIENTE ELEGIDO' : 'CLIENTES ELEGIDOS'}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.black,
                    side: const BorderSide(color: AppColors.black, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                    textStyle: AppTypography.label(size: 13, tracking: 1.5),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const AdminSectionLabel('¿Cuándo se puede jugar?'),
              ScheduleRow(
                title: 'Empieza',
                offLabel: 'Ahora',
                onLabel: 'Programar',
                isOn: _scheduleStart,
                value: _startsAt == null ? null : formatCampaignDateTime(_startsAt!),
                onToggle: (on) => setState(() {
                  _scheduleStart = on;
                  if (!on) _startsAt = null;
                }),
                onPick: () async {
                  final picked = await pickCampaignDateTime(context, _startsAt);
                  if (picked != null) setState(() => _startsAt = picked);
                },
              ),
              const SizedBox(height: 12),
              ScheduleRow(
                title: 'Termina',
                offLabel: 'En 7 días',
                onLabel: 'Elegir fecha',
                isOn: _customEnd,
                value: _endsAt == null ? null : formatCampaignDateTime(_endsAt!),
                onToggle: (on) => setState(() {
                  _customEnd = on;
                  if (!on) _endsAt = null;
                }),
                onPick: () async {
                  final picked = await pickCampaignDateTime(context, _endsAt ?? _startsAt);
                  if (picked != null) setState(() => _endsAt = picked);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(size: 14, color: AppColors.error),
                ),
              ],
              const SizedBox(height: 18),
              AppPrimaryButton(label: 'Enviar juego', isLoading: _isSending, onPressed: _send),
            ],
          ),
        ),
      ),
    );
  }
}
