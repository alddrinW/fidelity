import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/realtime_sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/fido_mascot.dart';
import '../../core/widgets/global_celebration_dialog.dart';
import '../auth/data/auth_repository.dart';
import '../scanner/scanner_screen.dart';
import 'card_history_screen.dart';
import 'providers/my_cards_provider.dart';
import 'widgets/registered_scans_list.dart';
import '../games/data/games_repository.dart';
import '../card_sales/data/card_sales_repository.dart';
import '../games/data/weekly_game_repository.dart';
import '../referrals/data/referrals_repository.dart';
import 'widgets/fido_banner_carousel.dart';
import '../../core/l10n/tr_text.dart';

/// Inicio del cliente: los juegos que le mandaron y sus escaneos registrados
/// (los locales donde ya escaneó, con su avance).
///
/// Es la primera pestaña del panel de usuario ([CustomerShellScreen]); el
/// "escanear" vive ahora en la acción central de la barra inferior.
class CustomerHomeView extends ConsumerStatefulWidget {
  const CustomerHomeView({super.key, this.onExplore});

  /// Lleva a la pestaña de explorar locales (desde el inicio vacío).
  final VoidCallback? onExplore;

  /// Resetea los flags de sesión (bienvenida / recordatorio de premio) al cerrar
  /// sesión, para que el próximo usuario en el mismo proceso los vea bien.
  static void resetSessionFlags() {
    _CustomerHomeViewState._welcomeShown = false;
    _CustomerHomeViewState._pendingRewardShown = false;
  }

  @override
  ConsumerState<CustomerHomeView> createState() => _CustomerHomeViewState();
}

class _CustomerHomeViewState extends ConsumerState<CustomerHomeView> {
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
    final repository = ref.read(authRepositoryProvider);
    final user = repository.currentUser;
    // Solo la primera vez que la persona entra a su cuenta: el servidor
    // recuerda que ya la vio, aunque cierre sesión, vuelva a entrar o use otro
    // dispositivo.
    if (user != null && !user.hasSeenWelcome) {
      _welcomeShown = true;
      if (mounted) _showWelcomeDialog();
      await repository.markWelcomeSeen();
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
                initialTabIndex: CardHistoryScreen.rewardsTab,
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

  void _openCardRewards(Map<String, dynamic> card) {
    final business = card['businesses'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardHistoryScreen(
          loyaltyCardId: card['id'],
          businessId: business['id'],
          businessName: business['name'],
          initialTabIndex: CardHistoryScreen.rewardsTab,
        ),
      ),
    );
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

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: AppResponsiveBody(
            adaptive: true,
            child: state.isLoading && state.cards.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.cards.isEmpty
                    ? _buildEmptyState()
                    : _buildCardList(state),
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

  Widget _buildCardList(MyCardsState state) {
    return RefreshIndicator(
      color: AppColors.black,
      onRefresh: () {
        ref.invalidate(myGameInvitesProvider);
        ref.invalidate(referralInfoProvider);
        ref.invalidate(cardOffersProvider);
        ref.invalidate(weeklyGameProvider);
        return ref.read(myCardsProvider.notifier).refreshCards();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Abajo hay espacio para el botón flotante de escanear.
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 110),
        children: [
          // Fido le dice al cliente qué puede hacer: reclamar un premio, comprar una
          // tarjeta, jugar, invitar a un amigo...
          FidoBannerCarousel(
            cards: state.cards,
            onOpenReward: _openCardRewards,
            onOpenOffers: widget.onExplore,
            onScan: _openScanner,
          ),
          // Los locales donde el cliente ya escaneó, con su avance.
          RegisteredScansList(cards: state.cards, onOpen: _openCard),
        ],
      ),
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
                  // Fido con los brazos arriba: ¡a ganar!
                  const FidoMascot(mood: FidoMood.celebrate, height: 220)
                      .animate()
                      .scale(
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
                  const SizedBox(height: 20),
                  // Cómo funciona, en tres pasos.
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Step(icon: Icons.qr_code_scanner_rounded, label: 'Escanea'),
                      _StepArrow(),
                      _Step(icon: Icons.add_circle_outline_rounded, label: 'Suma puntos'),
                      _StepArrow(),
                      _Step(icon: Icons.card_giftcard_rounded, label: 'Gana premios'),
                    ],
                  ),
                ],
              ).animate().fadeIn(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 8, 48, 24),
          child: Column(
            children: [
              AppPrimaryButton(label: 'Escanear', onPressed: _openScanner),
              if (widget.onExplore != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: widget.onExplore,
                  child: Text(
                    'Explorar locales',
                    style: AppTypography.label(size: 14, tracking: 1),
                  ),
                ),
              ],
            ],
          ).animate(delay: 300.ms).fadeIn().moveY(begin: 16, curve: Curves.easeOut),
        ),
      ],
    );
  }
}

/// Un paso de "cómo funciona" en el inicio vacío.
class _Step extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Step({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.black),
        ),
        const SizedBox(height: 6),
        Text(label, style: AppTypography.label(size: 11, tracking: 1)),
      ],
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 20),
      child: Icon(Icons.arrow_forward_rounded, size: 18),
    );
  }
}
