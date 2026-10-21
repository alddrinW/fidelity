import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';
import '../../../main.dart';
import '../../features/business/dashboard/business_dashboard_screen.dart';
import '../../features/cards/card_history_screen.dart';
import '../../features/admin/admin_users_screen.dart';
import '../../features/admin/admin_businesses_screen.dart';
import '../../features/admin/admin_activity_screen.dart';
import '../../features/admin/admin_rewards_screen.dart';
import '../widgets/global_celebration_dialog.dart';
import '../../features/campaigns/my_gifts_screen.dart';
import 'inbox_events.dart';
import '../../features/games/game_invite_screen.dart';
import '../../features/admin/admin_games_screen.dart';

class PushNotificationService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _listenersRegistered = false;

  static const _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Notificaciones de Fidelity',
    description: 'Este canal se usa para notificaciones importantes.',
    importance: Importance.max,
    playSound: true,
  );

  static Future<void> initialize() async {
    // Si no es móvil (e.g. Linux, Windows, macOS Desktop), salimos de forma segura
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      debugPrint('Push notifications omitidas en plataforma de escritorio.');
      return;
    }

    try {
      final firebaseMessaging = FirebaseMessaging.instance;
      NotificationSettings settings = await firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Permiso de notificaciones concedido.');

        final fcmToken = await firebaseMessaging.getToken();
        if (fcmToken != null) {
          await _saveTokenToDatabase(fcmToken);
        }

        if (_listenersRegistered) return;
        _listenersRegistered = true;

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);

        const initializationSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        );

        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (details) {
            final payload = details.payload;
            if (payload == null || payload.isEmpty) return;
            try {
              final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
              _handleRoutingData(data);
            } catch (_) {
              _handleRoutingData({'route': payload});
            }
          },
        );

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          // Con la app abierta, la campana de la bandeja se actualiza al instante.
          notifyInboxChanged();
          RemoteNotification? notification = message.notification;
          AndroidNotification? android = message.notification?.android;

          if (notification != null && android != null) {
            _localNotifications.show(
              notification.hashCode,
              notification.title,
              notification.body,
              payload: jsonEncode(message.data),
              NotificationDetails(
                android: AndroidNotificationDetails(
                  _channel.id,
                  _channel.name,
                  channelDescription: _channel.description,
                  importance: _channel.importance,
                  priority: Priority.high,
                  icon: android.smallIcon,
                  playSound: true,
                  autoCancel: true,
                ),
                iOS: const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
            );
          }
        });

        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('App abierta desde notificacion (background)');
          _handleRoutingData(message.data);
        });

        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('App abierta desde notificacion (terminada)');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleRoutingData(initialMessage.data);
          });
        }

        firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);
      }
    } catch (e) {
      debugPrint('Error inicializando notificaciones: $e');
    }
  }

  /// Abre lo que corresponde a los datos de una notificación (los mismos que
  /// trae el push). Lo usa también la bandeja de notificaciones.
  static void openFromData(Map<String, dynamic> data) => _handleRoutingData(data);

  static void _handleRoutingData(Map<String, dynamic> data) {
    _localNotifications.cancelAll();

    final route = data['route'] as String?;
    if (route == null) return;

    final context = globalNavigatorKey.currentContext;
    if (context == null) return;

    Navigator.of(context).popUntil((r) => r.isFirst);

    if (route == '/admin_users') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminUsersScreen()));
    } else if (route == '/admin_businesses') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminBusinessesScreen()));
    } else if (route == '/admin_activity') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminActivityScreen()));
    } else if (route == '/admin_rewards') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminRewardsScreen()));
    } else if (route == '/play_game') {
      final inviteId = data['invite_id'] as String?;
      if (inviteId != null && inviteId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GameInviteScreen(inviteId: inviteId)),
        );
      }
    } else if (route == '/admin_games') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminGamesScreen()));
    } else if (route == '/business_dashboard/games') {
      // Los juegos del dueño viven en "Crear y gestionar": se vuelve al panel.
    } else if (route == '/my_gifts') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyGiftsScreen()));
    } else if (route == '/business_dashboard/pending') {
      BusinessDashboardScreen.goToTab(1);
    } else if (route == '/business_dashboard/rewards') {
      BusinessDashboardScreen.goToTab(2);
    } else if (route == '/points_approved') {
      final loyaltyCardId = data['loyalty_card_id'] as String?;
      final businessId = data['business_id'] as String?;
      final businessName = data['business_name'] as String? ?? 'Tus puntos';

      if (loyaltyCardId != null && loyaltyCardId.isNotEmpty &&
          businessId != null && businessId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CardHistoryScreen(
              loyaltyCardId: loyaltyCardId,
              businessId: businessId,
              businessName: businessName,
              initialTabIndex: CardHistoryScreen.rewardsTab,
            ),
          ),
        );
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (globalNavigatorKey.currentContext != null) {
          GlobalCelebrationDialog.show(
            globalNavigatorKey.currentContext!,
            title: '¡SUMASTE UN PUNTO!',
            message: '¡Felicidades! Ya puedes ver tu listado de puntos.',
            iconType: 'reward',
          );
        }
      });
    } else if (route == '/reward') {
      final loyaltyCardId = data['loyalty_card_id'] as String?;
      final businessId = data['business_id'] as String?;
      final businessName = data['business_name'] as String? ?? 'Premios';

      if (loyaltyCardId != null && loyaltyCardId.isNotEmpty &&
          businessId != null && businessId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CardHistoryScreen(
              loyaltyCardId: loyaltyCardId,
              businessId: businessId,
              businessName: businessName,
              initialTabIndex: CardHistoryScreen.rewardsTab,
            ),
          ),
        );
      }
    } else if (route == '/transfer_received') {
      final loyaltyCardId = data['loyalty_card_id'] as String?;
      final businessId = data['business_id'] as String?;
      final businessName = data['business_name'] as String? ?? 'Premio recibido';

      if (loyaltyCardId != null && loyaltyCardId.isNotEmpty &&
          businessId != null && businessId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CardHistoryScreen(
              loyaltyCardId: loyaltyCardId,
              businessId: businessId,
              businessName: businessName,
              initialTabIndex: CardHistoryScreen.rewardsTab,
            ),
          ),
        );
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (globalNavigatorKey.currentContext != null) {
            GlobalCelebrationDialog.show(
              globalNavigatorKey.currentContext!,
              title: '¡TE HAN TRANSFERIDO!',
              message: '¡Acabas de recibir un premio! Revisa tus tarjetas.',
              iconType: 'transfer',
            );
          }
        });
      }
    }
  }

  static Future<void> _saveTokenToDatabase(String token) async {
    final api = ApiClient();
    if (api.isAuthenticated) {
      try {
        await api.patch('users/fcm-token', body: {'fcmToken': token});
        debugPrint('Token FCM guardado en backend exitosamente.');
      } catch (e) {
        debugPrint('Error guardando token en backend: $e');
      }
    }
  }

  static Future<void> removeTokenFromDatabase() async {
    final api = ApiClient();
    if (api.isAuthenticated) {
      try {
        await api.patch('users/fcm-token', body: {'fcmToken': null});
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          await FirebaseMessaging.instance.deleteToken();
        }
        debugPrint('Token FCM eliminado exitosamente al cerrar sesion.');
      } catch (e) {
        debugPrint('Error eliminando token FCM: $e');
      }
    }
  }
}
