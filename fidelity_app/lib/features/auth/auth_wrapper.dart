import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'login_screen.dart';
import '../business/dashboard/business_dashboard_screen.dart';
import '../business/create_business_screen.dart';
import '../payments/account_activation_screen.dart';
import '../cards/customer_home_view.dart';
import '../cards/customer_shell_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../../core/l10n/app_language.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/realtime_sync_service.dart';
import '../../core/widgets/global_celebration_dialog.dart';
import 'dart:async';
import 'providers/auth_provider.dart';
import 'data/auth_repository.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  StreamSubscription<void>? _transferSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Re-verificamos la autenticación por si acaso, aunque el Provider se inicializa solo
      ref.read(authStateProvider.notifier).checkAuth();
    });

    _transferSub = RealtimeSyncService().onRewardTransfersChanged.listen((payload) {
      if (!mounted || payload == null) return;
      final currentUserId = ref.read(authRepositoryProvider).currentUser?.id;
      if (payload['to_user_id'] == currentUserId && currentUserId != null) {
        GlobalCelebrationDialog.show(
          context,
          title: '¡TE HAN TRANSFERIDO!',
          message: '¡Acabas de recibir un premio de un amigo! Revisa tus tarjetas.',
          iconType: 'transfer',
        );
      }
    });
  }

  @override
  void dispose() {
    _transferSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // Escuchar cambios de estado para mostrar dialogos (side-effects)
    ref.listen<AuthStateStatus>(authStateProvider, (previous, next) {
      // Manejar inicialización de push notification cuando hay usuario validado
      if (next is AuthAdmin ||
          next is AuthBusinessActive ||
          next is AuthApprover ||
          next is AuthClient) {
        PushNotificationService.initialize();
        // El servidor manda sus avisos en el idioma de la app.
        syncLanguageToServer(ref.read(languageProvider));
        // Recién acá (ya autenticado) suscribimos el realtime, para que el canal
        // lleve el JWT del usuario y RLS le entregue sus cambios en vivo.
        RealtimeSyncService().initialize();
      } else if (next is AuthUnauthenticated) {
        // Al cerrar sesión, soltamos el canal para que el próximo login abra uno limpio,
        // y reseteamos los flags de sesión (bienvenida / recordatorio de premio) para
        // que el próximo usuario los vea correctamente.
        RealtimeSyncService().reset();
        CustomerHomeView.resetSessionFlags();
      }
    });

    if (authState is AuthInitial) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authState is AuthUnauthenticated) {
      return const LoginScreen();
    }

    if (authState is AuthAdmin) {
      return const AdminDashboardScreen();
    }

    if (authState is AuthBusinessPendingCreate) {
      return const CreateBusinessScreen();
    }

    // Negocio creado pero sin activar: se activa al validar el pago (PAGA YA).
    if (authState is AuthBusinessInactive) {
      return const AccountActivationScreen();
    }

    if (authState is AuthBusinessActive) {
      return const BusinessDashboardScreen();
    }

    // Aprobador: ve solo lo que puede operar (escaneos, premios y opiniones).
    if (authState is AuthApprover) {
      return const BusinessDashboardScreen(approverMode: true);
    }

    if (authState is AuthClient) {
      return const CustomerShellScreen();
    }

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
