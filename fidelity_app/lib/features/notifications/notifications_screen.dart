import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/l10n/translator.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import 'data/notifications_repository.dart';

/// Etiqueta del día de un grupo: "Hoy", "Ayer" o la fecha.
String notificationDayLabel(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  final dd = day.day.toString().padLeft(2, '0');
  final mm = day.month.toString().padLeft(2, '0');
  return '$dd/$mm/${day.year}';
}

/// Bandeja de notificaciones: cada movimiento del usuario (escaneos, premios,
/// gift cards, pagos...) del más nuevo al más viejo, agrupado por día. Tocar
/// uno lo marca como leído y abre lo que corresponde.
class NotificationsScreen extends ConsumerStatefulWidget {
  /// Qué hacer al tocar una notificación (por defecto, abrir su destino).
  final void Function(AppNotification notification)? onOpen;

  const NotificationsScreen({super.key, this.onOpen});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const _pageSize = 30;

  final _scroll = ScrollController();
  List<AppNotification> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final items = await ref.read(notificationsRepositoryProvider).list(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items = items;
        _hasMore = items.length >= _pageSize;
        _isLoading = false;
      });
      ref.read(unreadCountProvider.notifier).refresh();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _items.isEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      final more = await ref
          .read(notificationsRepositoryProvider)
          .list(before: _items.last.createdAt, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...more];
        _hasMore = more.length >= _pageSize;
      });
    } catch (_) {
      // Se reintenta al volver a llegar al final.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  int get _unread => _items.where((n) => !n.read).length;

  Future<void> _open(AppNotification notification) async {
    if (!notification.read) {
      setState(() {
        _items = [for (final n in _items) n.id == notification.id ? n.asRead() : n];
      });
      ref.read(unreadCountProvider.notifier).set(ref.read(unreadCountProvider) - 1);
      try {
        await ref.read(notificationsRepositoryProvider).markRead(notification.id);
      } catch (_) {
        // El contador se corrige solo en la próxima consulta.
      }
    }
    if (!mounted) return;
    (widget.onOpen ?? _defaultOpen)(notification);
  }

  /// Abre lo mismo que abriría el push de esa notificación.
  void _defaultOpen(AppNotification notification) {
    if (notification.route == null) return;
    PushNotificationService.openFromData(notification.data);
  }

  Future<void> _markAll() async {
    setState(() => _items = [for (final n in _items) n.asRead()]);
    ref.read(unreadCountProvider.notifier).set(0);
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
    } catch (_) {
      ref.read(unreadCountProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          adaptive: true,
          child: Column(
            children: [
              AppPageHeader(
                title: 'Notificaciones',
                trailing: _unread > 0
                    ? IconButton(
                        tooltip: context.tr('Marcar todas como leídas'),
                        icon: const Icon(Icons.done_all_rounded),
                        onPressed: _markAll,
                      )
                    : null,
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.black));
    }
    if (_failed) {
      return Column(
        children: [
          const Expanded(
            child: AppEmptyState.error(message: 'No pudimos cargar tus notificaciones. Revisa tu conexión e inténtalo de nuevo.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 8, 48, 32),
            child: AppPrimaryButton(label: 'Reintentar', onPressed: _load),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return const AppEmptyState(
        title: 'Todo al día',
        message: 'Aquí verás cada movimiento: escaneos, premios, gift cards y más.',
      );
    }

    final now = DateTime.now();
    final children = <Widget>[];
    String? currentDay;
    for (var i = 0; i < _items.length; i++) {
      final n = _items[i];
      final day = notificationDayLabel(n.createdAt, now);
      if (day != currentDay) {
        currentDay = day;
        children.add(
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 4 : 20, bottom: 8, left: 4),
            child: Semantics(
              header: true,
              child: Text(day.toUpperCase(), style: AppTypography.label(size: 12, tracking: 3)),
            ),
          ),
        );
      }
      children.add(
        NotificationTile(notification: n, onTap: () => _open(n))
            .animate(delay: (30 * (i % 8)).ms)
            .fadeIn(duration: 250.ms),
      );
      children.add(const SizedBox(height: 10));
    }
    if (_isLoadingMore) {
      children.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AppColors.black, strokeWidth: 2)),
      ));
    }

    return RefreshIndicator(
      color: AppColors.black,
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: children,
      ),
    );
  }
}

/// Una notificación: icono, título, texto y hora; las no leídas en negrita y
/// con un punto rosa.
class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const NotificationTile({super.key, required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final time = '${n.createdAt.hour.toString().padLeft(2, '0')}:'
        '${n.createdAt.minute.toString().padLeft(2, '0')}';

    return Semantics(
      button: true,
      label: '${n.read ? '' : '${context.tr('No leída.')} '}${n.title}. ${n.body}',
      excludeSemantics: true,
      child: Material(
        color: n.read ? AppColors.white : AppColors.pink.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.black, width: 1.2),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: n.read ? AppColors.surfaceMuted : AppColors.pink,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(n.icon, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                size: 15,
                                weight: n.read ? FontWeight.w400 : FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: AppTypography.body(
                              size: 12,
                              weight: FontWeight.w300,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n.body,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(size: 14, weight: FontWeight.w300),
                      ),
                    ],
                  ),
                ),
                if (!n.read) ...[
                  const SizedBox(width: 8),
                  Container(
                    key: const ValueKey('unread-dot'),
                    margin: const EdgeInsets.only(top: 6),
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
