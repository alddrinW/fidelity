import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/theme/app_typography.dart';
import '../admin/widgets/admin_widgets.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'data/feedback_repository.dart';
import 'widgets/feedback_card.dart';
import '../../core/l10n/tr_text.dart';

enum _InboxFilter {
  open('Abiertas'),
  resolved('Resueltas'),
  all('Todas');

  final String label;

  const _InboxFilter(this.label);

  bool accepts(FeedbackItem item) => switch (this) {
        open => !item.isResolved,
        resolved => item.isResolved,
        all => true,
      };
}

/// Bandeja de sugerencias y reclamos en pantalla completa. La usan el
/// administrador (todas), el dueño (las de su negocio) y el cliente (las
/// suyas, solo lectura).
class FeedbackInboxScreen extends StatelessWidget {
  final String title;
  final Future<List<FeedbackItem>> Function() load;
  final Future<void> Function(String id, {String? reply})? onResolve;
  final bool showUser;
  final bool showBusiness;

  const FeedbackInboxScreen({
    super.key,
    required this.title,
    required this.load,
    this.onResolve,
    this.showUser = false,
    this.showBusiness = true,
  });

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: title,
      body: FeedbackInboxBody(
        load: load,
        onResolve: onResolve,
        showUser: showUser,
        showBusiness: showBusiness,
      ),
    );
  }
}

/// Contenido de la bandeja (filtros y lista), sin marco de página: se usa
/// dentro de una pestaña o dentro de [FeedbackInboxScreen].
class FeedbackInboxBody extends StatefulWidget {
  final Future<List<FeedbackItem>> Function() load;

  /// Quien puede responder y resolver (administrador y dueño).
  final Future<void> Function(String id, {String? reply})? onResolve;

  final bool showUser;
  final bool showBusiness;

  const FeedbackInboxBody({
    super.key,
    required this.load,
    this.onResolve,
    this.showUser = false,
    this.showBusiness = true,
  });

  @override
  State<FeedbackInboxBody> createState() => _FeedbackInboxBodyState();
}

class _FeedbackInboxBodyState extends State<FeedbackInboxBody> {
  bool _isLoading = true;
  List<FeedbackItem> _items = [];
  late _InboxFilter _filter =
      widget.onResolve == null ? _InboxFilter.all : _InboxFilter.open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final items = await widget.load();
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        DashboardAnimatedToast.show(
            context, 'No se pudieron cargar las opiniones',
            isError: true);
      }
    }
  }

  Future<void> _resolve(FeedbackItem item) async {
    final reply = await showDialog<String>(
      context: context,
      builder: (_) => const _ReplyDialog(),
    );
    if (reply == null) return;
    try {
      await widget.onResolve!(item.id, reply: reply);
      if (!mounted) return;
      DashboardAnimatedToast.show(context, 'Opinión resuelta');
      await _load();
    } catch (e) {
      if (mounted) {
        DashboardAnimatedToast.show(context, e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items.where(_filter.accepts).toList();
    final openCount = _items.where((i) => !i.isResolved).length;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.black,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _InboxFilter.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _InboxFilter.values[index];
                      final suffix =
                          filter == _InboxFilter.open && openCount > 0
                              ? ' ($openCount)'
                              : '';
                      return AdminFilterPill(
                        label: '${filter.label}$suffix',
                        selected: _filter == filter,
                        onTap: () => setState(() => _filter = filter),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
                hasScrollBody: false, child: AdminLoading())
          else if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                title: 'Sin opiniones',
                message: _filter == _InboxFilter.open
                    ? 'No hay sugerencias ni reclamos abiertos.'
                    : 'No hay opiniones en esta categoría.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final item = visible[index];
                  return FeedbackCard(
                    item: item,
                    showUser: widget.showUser,
                    showBusiness: widget.showBusiness,
                    onResolve:
                        widget.onResolve == null ? null : () => _resolve(item),
                  )
                      .animate(delay: (40 * (index % 8)).ms)
                      .fadeIn()
                      .slideY(begin: 0.06);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog();

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
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
        'RESPONDER',
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 26),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'El cliente recibirá tu respuesta. Puedes dejarla en blanco y solo '
            'marcar el caso como resuelto.',
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 15, weight: FontWeight.w300),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _controller,
            hint: 'Tu respuesta (opcional)',
            icon: Icons.reply_rounded,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('RESOLVER'),
        ),
      ],
    );
  }
}
