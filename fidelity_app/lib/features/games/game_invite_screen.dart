import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/widgets/fido_mascot.dart';
import '../campaigns/data/campaigns_repository.dart';
import '../campaigns/my_gifts_screen.dart';
import '../campaigns/widgets/schedule_row.dart';
import 'data/games_repository.dart';
import 'widgets/flappy_game.dart';
import 'widgets/game_result_view.dart';
import 'widgets/hangman_game.dart';
import 'widgets/tic_tac_toe_game.dart';

/// Un reto que le mandó un negocio al cliente: se abre desde la notificación.
/// Muestra la presentación (juego y premio), la partida y el resultado. Solo se
/// juega dentro del horario que puso el local y hay hasta 3 intentos para
/// ganar; el servidor decide si ganó.
class GameInviteScreen extends ConsumerStatefulWidget {
  final String inviteId;

  const GameInviteScreen({super.key, required this.inviteId});

  @override
  ConsumerState<GameInviteScreen> createState() => _GameInviteScreenState();
}

class _GameInviteScreenState extends ConsumerState<GameInviteScreen> {
  GamePlay? _play;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;

  GamesRepository get _repo => ref.read(gamesRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final play = await _repo.invite(widget.inviteId);
      if (mounted) setState(() => _play = play);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
    );
  }

  /// Aplica una jugada en el servidor y muestra el estado que devuelve.
  Future<void> _act(Future<GamePlay> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final play = await action();
      if (!mounted) return;
      setState(() => _play = play);
      if (play.isFinished) {
        ref.invalidate(myGameInvitesProvider);
        ref.invalidate(myClaimsProvider);
      }
    } catch (e) {
      if (mounted) {
        _showError(e);
        // Si el reto cambió por otro lado (ya se jugó, venció), se vuelve a leer.
        await _load();
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _close() => Navigator.of(context).pop();

  void _openGifts() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MyGiftsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final play = _play;

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          adaptive: true,
          maxWidth: 560,
          child: Column(
            children: [
              AppPageHeader(title: play?.gameName.isNotEmpty == true ? play!.gameName : 'Juego'),
              Expanded(child: _body(play)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(GamePlay? play) {
    if (_isLoading && play == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.black));
    }
    if (play == null) {
      return Column(
        children: [
          Expanded(
            child: AppEmptyState.error(message: _error ?? 'No pudimos abrir este juego.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 8, 48, 32),
            child: AppPrimaryButton(label: 'Reintentar', onPressed: _load),
          ),
        ],
      );
    }
    if (play.isFinished) {
      return GameResultView(
        play: play,
        onClose: _close,
        onOpenGifts: play.claimCode != null ? _openGifts : null,
      );
    }
    if (play.isExpired) {
      return const AppEmptyState(
        title: 'Reto vencido',
        message: 'Este juego ya no está disponible. ¡Atento al próximo que te mande el local!',
        mood: FidoMood.sad,
      );
    }
    if (play.isUpcoming) {
      return AppEmptyState(
        title: 'Todavía no empieza',
        message: play.startsAt == null
            ? 'Este juego empieza pronto. ¡Te avisamos!'
            : 'Este juego empieza el ${formatCampaignDateTime(play.startsAt!)}. ¡Te avisamos!',
      );
    }
    if (play.status == 'sent') {
      return _Intro(play: play, isLoading: _isBusy, onStart: () => _act(() => _repo.start(play.id)));
    }
    return _Game(
      play: play,
      busy: _isBusy,
      onGuess: (letter) => _act(() => _repo.guess(play.id, letter)),
      onMove: (cell) => _act(() => _repo.move(play.id, cell)),
      onFlappyFinished: (score) => _act(() => _repo.finish(play.id, score)),
    );
  }
}

/// Presentación del reto: quién lo manda, qué juego es y cuál es el premio.
class _Intro extends StatelessWidget {
  final GamePlay play;
  final bool isLoading;
  final VoidCallback onStart;

  const _Intro({required this.play, required this.isLoading, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Column(
        children: [
          FidoMascot(
            mood: play.lostLastAttempt ? FidoMood.sad : FidoMood.celebrate,
            height: 160,
          ),
          const SizedBox(height: 12),
          Text(
            play.lostLastAttempt
                ? 'ESTA VEZ NO'
                : play.weekly
                    ? 'TU JUEGO DE LA SEMANA'
                    : '${play.businessName ?? 'Un local'} te reta a jugar'.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTypography.display(size: 34),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.pink,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.black, width: 1.2),
            ),
            child: Column(
              children: [
                Text('PREMIO SI GANAS', style: AppTypography.label(size: 11, tracking: 3)),
                const SizedBox(height: 2),
                Text(
                  (play.prizeLabel ?? 'Una gift card').toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTypography.display(size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            play.lostLastAttempt
                ? 'Perdiste ese intento, pero no te rindas. ¡Aún puedes ganar!'
                : 'Tienes ${play.maxAttempts} intentos para ganar.',
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 15, weight: FontWeight.w300),
          ),
          const SizedBox(height: 8),
          Text(
            play.attemptsLeft == 1 ? 'Te queda 1 intento' : 'Te quedan ${play.attemptsLeft} intentos',
            textAlign: TextAlign.center,
            style: AppTypography.label(size: 13, tracking: 2),
          ),
          if (play.weekly) ...[
            const SizedBox(height: 6),
            Text(
              'Juegas una vez por semana. Si ganas, sumas el punto en ${play.businessName ?? 'el negocio que elegiste'}.',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
            ),
          ] else if (play.expiresAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Disponible hasta el ${formatCampaignDateTime(play.expiresAt!)}',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 24),
          AppPrimaryButton(
            label: play.lostLastAttempt ? 'Intentar de nuevo' : 'Jugar',
            isLoading: isLoading,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

/// La partida en curso, según el juego.
class _Game extends StatelessWidget {
  final GamePlay play;
  final bool busy;
  final ValueChanged<String> onGuess;
  final ValueChanged<int> onMove;
  final ValueChanged<int> onFlappyFinished;

  const _Game({
    required this.play,
    required this.busy,
    required this.onGuess,
    required this.onMove,
    required this.onFlappyFinished,
  });

  @override
  Widget build(BuildContext context) {
    final child = switch (play.game) {
      GameKey.hangman => HangmanGame(play: play.play, enabled: !busy, onGuess: onGuess),
      GameKey.tictactoe => TicTacToeGame(play: play.play, enabled: !busy, onMove: onMove),
      GameKey.flappy => FlappyGame(
          target: (play.play['target'] as num?)?.toInt() ?? 10,
          onFinished: onFlappyFinished,
        ),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        children: [
          Text(
            'INTENTO ${play.attempts} DE ${play.maxAttempts}',
            textAlign: TextAlign.center,
            style: AppTypography.label(size: 12, tracking: 3),
          ),
          const SizedBox(height: 4),
          Text(
            'PREMIO: ${(play.prizeLabel ?? 'gift card').toUpperCase()}',
            textAlign: TextAlign.center,
            style: AppTypography.label(size: 12, tracking: 3, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
