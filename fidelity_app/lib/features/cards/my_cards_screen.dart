import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/api_client.dart';
import '../../core/services/realtime_sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/global_celebration_dialog.dart';
import '../../core/widgets/user_avatar_circle.dart';
import '../auth/data/auth_repository.dart';
import '../profile/user_profile_screen.dart';
import '../scanner/scanner_screen.dart';
import 'card_history_screen.dart';
import '../campaigns/data/campaigns_repository.dart';
import '../campaigns/widgets/campaigns_carousel.dart';
import 'providers/my_cards_provider.dart';
import 'widgets/missions_route.dart';
import '../../core/l10n/tr_text.dart';

class MyCardsScreen extends ConsumerStatefulWidget {
  const MyCardsScreen({super.key});

  /// Resetea los flags de sesión (bienvenida / recordatorio de premio) al cerrar
  /// sesión, para que el próximo usuario en el mismo proceso los vea bien.
  static void resetSessionFlags() {
    _MyCardsScreenState._welcomeShown = false;
    _MyCardsScreenState._pendingRewardShown = false;
  }

  @override
  ConsumerState<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends ConsumerState<MyCardsScreen> {
  late ConfettiController _confettiController;
  static bool _welcomeShown = false;
  static bool _pendingRewardShown = false;

  StreamSubscription<void>? _rewardsSub;
  StreamSubscription<void>? _scansSub;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));

    // Bind real-time event handlers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(myCardsProvider.notifier);
      notifier.onCardCompleted = _showCelebrationDialog;
      notifier.onPointEarned = _showPointEarnedAnimation;

      // Evitar que el diálogo salte si la pantalla está oculta detrás de otra
      if (ModalRoute.of(context)?.isCurrent == true) {
        _checkWelcomeMessage();
      }
    });

    // Nota: los cambios de loyalty_cards ya los maneja el canal filtrado del
    // provider (que además dispara la celebración). Acá solo escuchamos rewards
    // y scans (que el provider no cubre) y todo pasa por el debounce del notifier.
    _rewardsSub = RealtimeSyncService().onRewardsChanged.listen((_) {
      if (mounted) {
        ref.read(myCardsProvider.notifier).scheduleRefresh();
      }
    });
    // Un escaneo pendiente (recién hecho) debe reordenar la tarjeta al tope en vivo,
    // aunque no cambie la fila de loyalty_cards.
    _scansSub = RealtimeSyncService().onScansChanged.listen((_) {
      if (mounted) {
        ref.read(myCardsProvider.notifier).scheduleRefresh();
      }
    });
  }

  @override
  void dispose() {
    _rewardsSub?.cancel();
    _scansSub?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  void _showPointEarnedAnimation() {
    if (!mounted) return;
    _confettiController.play();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'El local aprobó tu escaneo. ¡Sumaste 1 punto!',
          style: AppTypography.body(
            size: 15,
            weight: FontWeight.w600,
            color: AppColors.white,
          ),
        ),
        backgroundColor: AppColors.black,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _checkWelcomeMessage() async {
    if (_welcomeShown) return;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      final hasSeen = user.raw['has_seen_welcome'] == true ||
          user.userMetadata?['has_seen_welcome'] == true;
      if (!hasSeen) {
        _welcomeShown = true;
        if (mounted) {
          _showWelcomeDialog();
        }
        try {
          final current = Map<String, dynamic>.from(user.raw);
          current['has_seen_welcome'] = true;
          await ApiClient().updateUser(current);
        } catch (_) {}
      }
    }
  }

  void _showWelcomeDialog() {
    final displayName = _getDisplayName(ref.read(myCardsProvider).userName);
    final greeting = displayName.isEmpty ? '¡Hola!' : '¡Hola $displayName!';

    showDialog(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.waving_hand_rounded,
        title: '¡Bienvenido a Fidelity!',
        message: '$greeting Tu cuenta ha sido creada. Aquí verás tus tarjetas y '
            'acumularás puntos escaneando los códigos QR de tus negocios favoritos.',
        primaryLabel: '¡Empezar!',
      ),
    );
  }

  void _showCelebrationDialog() {
    if (!mounted) return;
    GlobalCelebrationDialog.show(
      context,
      title: '¡FELICIDADES!',
      message: '¡Ganaste un premio! Acércate al local para reclamarlo.',
      iconType: 'reward',
    );
  }

  /// Si el usuario tiene un premio sin reclamar (por si borró la notificación
  /// por accidente), le mostramos un modal al reingresar a la app con un botón
  /// que lo lleva directo al premio. Solo una vez por arranque de la app.
  void _checkPendingRewards() {
    if (_pendingRewardShown || !mounted) return;
    // Si hay otro diálogo o pantalla por encima (ej. bienvenida), no lo apilamos.
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final state = ref.read(myCardsProvider);
    Map<String, dynamic>? cardWithReward;
    for (final card in state.cards) {
      final rewards = (card['rewards'] as List?) ?? const [];
      // Solo 'pending': si el premio ya está entregado ('approved') no molestamos
      // al cliente con el recordatorio en cada inicio de sesión.
      final hasUnclaimed =
          rewards.any((r) => (r as Map)['status'] == 'pending');
      if (hasUnclaimed) {
        cardWithReward = card;
        break;
      }
    }

    if (cardWithReward == null) return;
    _pendingRewardShown = true;
    _showPendingRewardDialog(cardWithReward);
  }

  void _showPendingRewardDialog(Map<String, dynamic> card) {
    final business = card['businesses'];
    showDialog(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.card_giftcard_rounded,
        title: '¡Tienes un premio!',
        message:
            'Tienes un premio pendiente en ${business['name']}. ¡No te olvides de reclamarlo!',
        primaryLabel: 'Ver premio',
        onPrimary: () {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CardHistoryScreen(
                loyaltyCardId: card['id'],
                businessId: business['id'],
                businessName: business['name'],
                initialTabIndex: 1, // pestaña PREMIOS
              ),
            ),
          );
        },
        secondaryLabel: 'Después',
      ),
    );
  }

  /// Extracts first name + last name from full_name string.
  String _getDisplayName(String fullName) {
    if (fullName.isEmpty) return '';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0]} ${parts[1]}';
    return parts[0];
  }

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
  }

  Future<void> _openProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserProfileScreen()),
    );
    if (result == true) {
      // Esperamos a que termine la animación de vuelta (Hero) ANTES de
      // refrescar, para no reconstruir el avatar a mitad del vuelo (eso
      // causaba el salto de tamaño "se agranda y se achica"). Luego
      // actualiza foto/nombre en su lugar, sin parpadear.
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) {
          ref.read(myCardsProvider.notifier).refreshCards(silent: true);
        }
      });
    }
  }

  void _openCard(Map<String, dynamic> card) {
    final business = card['businesses'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardHistoryScreen(
          loyaltyCardId: card['id'],
          businessId: business['id'],
          businessName: business['name'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(myCardsProvider);

    // Listen to error state
    ref.listen<MyCardsState>(myCardsProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }

      // Apenas terminan de cargar las tarjetas, revisamos si hay un premio
      // pendiente para avisarle al usuario con un modal (una vez por sesión).
      final justLoaded = !next.isLoading &&
          next.cards.isNotEmpty &&
          (previous == null || previous.isLoading || previous.cards.isEmpty);
      if (justLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingRewards());
      }
    });

    final displayName = _getDisplayName(state.userName);

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: AppResponsiveBody(
              adaptive: true,
              child: Column(
                children: [
                  _buildHeader(state, displayName),
                  Expanded(
                    child: state.isLoading && state.cards.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : state.cards.isEmpty
                            ? _buildEmptyState()
                            : _buildCardList(state),
                  ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: 3.14 / 2, // Hacia abajo
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.2,
            colors: const [AppColors.pink, AppColors.black],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(MyCardsState state, String displayName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Mi perfil',
            child: GestureDetector(
              onTap: _openProfile,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Hero: anima la transición del avatar al entrar al perfil.
                  // El mismo widget vuela como UNA sola pieza (child +
                  // flightShuttleBuilder), sin rearmarse.
                  Hero(
                    tag: 'user_avatar',
                    flightShuttleBuilder: (_, __, ___, ____, _____) =>
                        UserAvatarCircle(avatarUrl: state.avatarUrl),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: UserAvatarCircle(avatarUrl: state.avatarUrl),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.black, width: 1),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 11,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          if (displayName.isNotEmpty)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Hola, $displayName',
                  style: AppTypography.display(size: 34),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardList(MyCardsState state) {
    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.black,
          onRefresh: () {
            ref.invalidate(campaignFeedProvider);
            return ref.read(myCardsProvider.notifier).refreshCards();
          },
          child: ListView(
            // Espacio inferior para que el último nodo no quede bajo el botón.
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 140),
            children: [
              // Novedades de los locales (eventos, tarjetas de regalo, rutas).
              const CampaignsCarousel(),
              MissionsRoute(
                missions: [for (final card in state.cards) Mission.fromCard(card)],
                onOpen: (mission) => _openCard(mission.card),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(48, 32, 48, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00FFFFFF), AppColors.white],
                stops: [0, 0.45],
              ),
            ),
            child: AppPrimaryButton(label: 'Escanear', onPressed: _openScanner),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo_transparente.png',
                    height: 280,
                    fit: BoxFit.contain,
                    semanticLabel: 'Fido',
                  ).animate().scale(
                        begin: const Offset(0.8, 0.8),
                        duration: 700.ms,
                        curve: const Cubic(0.34, 1.56, 0.64, 1),
                      ),
                  const SizedBox(height: 8),
                  Text(
                    'EMPIEZA A GANAR',
                    textAlign: TextAlign.center,
                    style: AppTypography.display(size: 44),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ESCANEA TU PRIMER CÓDIGO QR\nEN CUALQUIER NEGOCIO AFILIADO\nPARA RECIBIR PREMIOS',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(size: 16, weight: FontWeight.w300),
                  ),
                ],
              ).animate().fadeIn(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 8, 48, 56),
          child: AppPrimaryButton(label: 'Escanear', onPressed: _openScanner)
              .animate(delay: 300.ms)
              .fadeIn()
              .moveY(begin: 16, curve: Curves.easeOut),
        ),
      ],
    );
  }
}
