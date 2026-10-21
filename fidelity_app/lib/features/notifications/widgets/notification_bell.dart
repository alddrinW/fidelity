import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/translator.dart';
import '../../../core/theme/app_colors.dart';
import '../data/notifications_repository.dart';
import '../notifications_screen.dart';

/// Campana de la bandeja con el número de notificaciones sin leer. Abre la
/// pantalla de notificaciones y, al volver, actualiza el contador.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(unreadCountProvider.notifier).refresh();
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (mounted) ref.read(unreadCountProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadCountProvider);

    return IconButton(
      tooltip: context.tr('Notificaciones'),
      onPressed: _open,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        backgroundColor: AppColors.black,
        textColor: AppColors.white,
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}
