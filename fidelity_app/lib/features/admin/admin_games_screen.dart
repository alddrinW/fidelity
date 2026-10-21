import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_text_field.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import '../games/data/games_repository.dart';
import 'widgets/admin_widgets.dart';

enum _GamesFilter {
  pending('Por revisar'),
  approved('Activos'),
  rejected('Rechazados'),
  all('Todos');

  final String label;

  const _GamesFilter(this.label);

  bool accepts(GameAccess a) => switch (this) {
        pending => a.status == GameAccessStatus.pending,
        approved => a.status == GameAccessStatus.approved,
        rejected => a.status == GameAccessStatus.rejected,
        all => true,
      };
}

/// Minijuegos: el administrador revisa las solicitudes de los negocios, les
/// asigna los juegos y fija el premio que ganan los clientes (una gift card).
class AdminGamesScreen extends ConsumerStatefulWidget {
  const AdminGamesScreen({super.key});

  @override
  ConsumerState<AdminGamesScreen> createState() => _AdminGamesScreenState();
}

class _AdminGamesScreenState extends ConsumerState<AdminGamesScreen> {
  _GamesFilter _filter = _GamesFilter.pending;

  Future<void> _open(GameAccess access) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => GamesApprovalDialog(access: access),
    );
    if (changed == true) ref.invalidate(gameRequestsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(gameRequestsProvider);
    final all = requests.valueOrNull ?? const <GameAccess>[];
    final visible = all.where(_filter.accepts).toList();
    final toReview = all.where(_GamesFilter.pending.accepts).length;

    return AdminPageFrame(
      title: 'Minijuegos',
      body: RefreshIndicator(
        color: AppColors.black,
        onRefresh: () async => ref.invalidate(gameRequestsProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  itemCount: _GamesFilter.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final f = _GamesFilter.values[i];
                    final suffix = f == _GamesFilter.pending && toReview > 0 ? ' ($toReview)' : '';
                    return AdminFilterPill(
                      label: '${f.label}$suffix',
                      selected: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    );
                  },
                ),
              ),
            ),
            if (requests.isLoading && all.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: AdminLoading())
            else if (requests.hasError && all.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState.error(message: 'No pudimos cargar las solicitudes. Desliza para reintentar.',
                ),
              )
            else if (visible.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  title: 'Sin solicitudes',
                  message: 'No hay solicitudes en esta categoría.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _RequestCard(
                    access: visible[i],
                    onTap: () => _open(visible[i]),
                  ).animate(delay: (40 * (i % 8)).ms).fadeIn().slideY(begin: 0.06),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final GameAccess access;
  final VoidCallback onTap;

  const _RequestCard({required this.access, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, style) = switch (access.status) {
      GameAccessStatus.approved => ('Activo', AppChipStyle.dark),
      GameAccessStatus.pending => ('Por revisar', AppChipStyle.pink),
      _ => ('Rechazado', AppChipStyle.outline),
    };
    final date = access.requestedAt == null
        ? ''
        : EcuadorDateUtils.formatEcuadorTime(access.requestedAt!.toUtc().toIso8601String());

    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (access.businessName ?? 'Negocio').toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.display(size: 24),
                ),
              ),
              const SizedBox(width: 8),
              AppChip(label: label, style: style),
            ],
          ),
          if (access.ownerName != null || access.ownerEmail != null)
            AdminInfoLine(
              icon: Icons.person_outline_rounded,
              text: [access.ownerName, access.ownerEmail]
                  .whereType<String>()
                  .where((s) => s.trim().isNotEmpty)
                  .join(' · '),
            ),
          if (date.isNotEmpty) AdminInfoLine(icon: Icons.schedule_rounded, text: date),
          if (access.note?.trim().isNotEmpty ?? false)
            AdminInfoLine(icon: Icons.format_quote_rounded, text: access.note!),
          if (access.isApproved) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in access.games) AppChip(label: g.label, icon: g.icon),
                if (access.prize != null)
                  AppChip(
                    label: access.prize!.label,
                    icon: Icons.card_giftcard_rounded,
                    style: AppChipStyle.pink,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Revisar una solicitud: elegir los juegos y el premio y aprobarla, o
/// rechazarla con un motivo. En un negocio ya activo sirve para cambiar los
/// juegos o el premio, o retirárselos.
class GamesApprovalDialog extends ConsumerStatefulWidget {
  final GameAccess access;

  const GamesApprovalDialog({super.key, required this.access});

  @override
  ConsumerState<GamesApprovalDialog> createState() => _GamesApprovalDialogState();
}

class _GamesApprovalDialogState extends ConsumerState<GamesApprovalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Set<GameKey> _games = widget.access.games.isEmpty
      ? {...GameKey.values}
      : {...widget.access.games};
  late bool _discount = widget.access.prize?.isDiscount ?? true;
  late final _value = TextEditingController(text: '${widget.access.prize?.value ?? 20}');
  late final _label = TextEditingController(
    text: (widget.access.prize != null && !widget.access.prize!.isDiscount)
        ? widget.access.prize!.label
        : '',
  );
  bool _isSaving = false;
  String? _error;

  bool get _isActive => widget.access.isApproved;

  @override
  void dispose() {
    _value.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    if (_games.isEmpty) {
      setState(() => _error = 'Asigna al menos un juego.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(gamesRepositoryProvider).approve(
            widget.access.id!,
            games: GameKey.values.where(_games.contains).toList(),
            discount: _discount,
            value: _discount ? int.tryParse(_value.text.trim()) : null,
            label: _discount ? null : _label.text,
          );
      if (!mounted) return;
      DashboardAnimatedToast.show(context, _isActive ? 'Cambios guardados' : 'Minijuegos asignados');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(isActive: _isActive),
    );
    if (reason == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(gamesRepositoryProvider).reject(widget.access.id!, reason);
      if (!mounted) return;
      DashboardAnimatedToast.show(context, _isActive ? 'Minijuegos retirados' : 'Solicitud rechazada');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.access;

    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(
        (a.businessName ?? 'Negocio').toUpperCase(),
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 26),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (a.note?.trim().isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '“${a.note}”',
                      textAlign: TextAlign.center,
                      style: AppTypography.body(size: 14, weight: FontWeight.w300),
                    ),
                  ),
                const AdminSectionLabel('Juegos que le asignas'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in GameKey.values)
                      AdminFilterPill(
                        label: g.label,
                        icon: _games.contains(g) ? Icons.check_rounded : null,
                        selected: _games.contains(g),
                        onTap: () => setState(() {
                          if (!_games.remove(g)) _games.add(g);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const AdminSectionLabel('Premio que ganan los clientes'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AdminFilterPill(
                      label: 'Descuento',
                      selected: _discount,
                      onTap: () => setState(() => _discount = true),
                    ),
                    AdminFilterPill(
                      label: 'Mini premio',
                      selected: !_discount,
                      onTap: () => setState(() => _discount = false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_discount)
                  AppTextField(
                    controller: _value,
                    hint: 'Porcentaje de descuento',
                    icon: Icons.percent_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      return (n == null || n < 1 || n > 100) ? 'Ingresa un valor entre 1 y 100' : null;
                    },
                  )
                else
                  AppTextField(
                    controller: _label,
                    hint: 'Mini premio (ej. Café pequeño gratis)',
                    icon: Icons.redeem_rounded,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Describe el mini premio' : null,
                  ),
                const SizedBox(height: 8),
                Text(
                  'Quien gane recibe una gift card con este premio.',
                  style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(size: 14, color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _reject,
          child: Text(_isActive ? 'Retirar' : 'Rechazar'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cerrar'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isSaving ? null : _approve,
              child: Text(_isActive ? 'GUARDAR' : 'APROBAR'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Pide el motivo del rechazo (o del retiro). El campo es del diálogo para que
/// se libere con él.
class _ReasonDialog extends StatefulWidget {
  final bool isActive;

  const _ReasonDialog({required this.isActive});

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
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
      title: Text(
        widget.isActive ? 'RETIRAR MINIJUEGOS' : 'RECHAZAR SOLICITUD',
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 24),
      ),
      content: AppTextField(
        controller: _controller,
        hint: 'Motivo (lo verá el dueño)',
        icon: Icons.edit_note_rounded,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) Navigator.of(context).pop(text);
          },
          child: Text(widget.isActive ? 'RETIRAR' : 'RECHAZAR'),
        ),
      ],
    );
  }
}
