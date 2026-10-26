import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/tr_text.dart';
import '../../core/l10n/translator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import 'choose_local_screen.dart';
import 'data/referrals_repository.dart';
import 'points_text.dart';
import 'redeem_referral_dialog.dart';

/// El texto que el cliente comparte con su amigo: se invita a la app (no a un
/// local) y lleva el enlace, si el servidor tiene dirección pública, y el código.
String inviteMessage({required String code, required int friendPoints, String? link}) {
  final gift = friendPoints > 0 ? ' y con mi código ganas ${pointsText(friendPoints)} de regalo' : '';
  final url = link == null || link.isEmpty ? '' : '\nEnlace: $link';
  return '¡Únete a Fidelity! Descarga la app, regístrate con mi código y junta puntos en tus locales favoritos para ganar premios$gift.\n'
      'Mi código de amigo: $code$url';
}

/// Invitar amigos a la app. Se invita a Fidelity (no a un local): cuando se
/// unen los amigos que se piden (3 por defecto), quien invita gana puntos de
/// invitación y elige en qué local usarlos.
class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key});

  Future<void> _chooseLocal(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChooseLocalScreen()));
    ref.invalidate(referralInfoProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInfo = ref.watch(referralInfoProvider);
    final info = asyncInfo.valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          maxWidth: 640,
          adaptive: true,
          child: Column(
            children: [
              const AppPageHeader(title: 'Invitar amigos'),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.black,
                  onRefresh: () async => ref.invalidate(referralInfoProvider),
                  child: info == null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: 360,
                              child: asyncInfo.isLoading
                                  ? const Center(child: CircularProgressIndicator(color: AppColors.black))
                                  : const AppEmptyState.error(
                                      message: 'No pudimos cargar tus invitaciones. Desliza para reintentar.',
                                    ),
                            ),
                          ],
                        )
                      : _content(context, ref, info),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, ReferralInfo info) {
    if (!info.visible) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 420,
            child: AppEmptyState(
              title: 'Invitaciones apagadas',
              message: 'Por ahora no hay invitaciones de amigos activas. Vuelve pronto.',
            ),
          ),
        ],
      );
    }

    final by = info.referredBy;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        if (by != null && by.isPending && info.friendPoints > 0) ...[
          _CameInvitedBanner(by: by, points: info.friendPoints),
          const SizedBox(height: 16),
        ],
        _BalanceCard(info: info, onChoose: () => _chooseLocal(context, ref)),
        const SizedBox(height: 16),
        if (info.enabled && info.code != null) _InviteCard(info: info),
        if (info.enabled && info.code != null && info.referrerPoints > 0) ...[
          const SizedBox(height: 16),
          FriendsProgressCard(info: info),
        ],
        if (by == null) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () async {
                await showRedeemReferralDialog(context, ref.read(referralsRepositoryProvider));
                ref.invalidate(referralInfoProvider);
              },
              child: const Text('Tengo un código de un amigo'),
            ),
          ),
        ],
      ].animate(interval: 60.ms).fadeIn().slideY(begin: 0.05),
    );
  }
}

/// "Te invitó Ana: con tu primer escaneo en cualquier local ganas 1 punto".
class _CameInvitedBanner extends StatelessWidget {
  final ReferredBy by;
  final int points;

  const _CameInvitedBanner({required this.by, required this.points});

  @override
  Widget build(BuildContext context) {
    final who = by.name == null || by.name!.isEmpty ? 'un amigo' : by.name!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.pink,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.black, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Te invitó $who: con tu primer escaneo en cualquier local ganas ${pointsText(points)} de invitación',
              style: AppTypography.body(size: 15, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Los puntos de invitación sin usar y el botón para elegir el local.
class _BalanceCard extends StatelessWidget {
  final ReferralInfo info;
  final VoidCallback onChoose;

  const _BalanceCard({required this.info, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      // Con puntos por usar, la tarjeta se pinta de rosa.
      color: info.balance > 0 ? AppColors.pink : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('${info.balance}', style: AppTypography.display(size: 56)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PUNTOS DE INVITACIÓN', style: AppTypography.label(size: 13, tracking: 3)),
                    const SizedBox(height: 4),
                    Text(
                      info.balance > 0
                          ? 'Elige en qué local usarlos.'
                          : 'Aquí aparecen los puntos que ganes al invitar amigos.',
                      style: AppTypography.body(size: 14, weight: FontWeight.w300),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (info.balance > 0) ...[
            const SizedBox(height: 14),
            // Una monedita por punto (hasta 10).
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < info.balance.clamp(0, 10); i++)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.black, width: 1.2),
                    ),
                    child: const Icon(Icons.favorite_rounded, size: 11, color: AppColors.black),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(label: 'Elegir local', onPressed: onChoose),
          ],
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final ReferralInfo info;

  const _InviteCard({required this.info});

  Future<void> _copy(BuildContext context, String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(message))));
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: inviteMessage(code: info.code!, friendPoints: info.friendPoints, link: info.link)),
    );
  }

  /// Lo que se gana: "Invita a 3 amigos: cuando se registren con tu código, ganas 1 punto".
  String get _reward {
    final n = info.friendsRequired;
    final who = n == 1 ? 'Invita a un amigo' : 'Invita a $n amigos';
    final when = info.countsOnFirstScan ? 'cuando se registren y hagan su primer escaneo' : 'cuando se registren con tu código';
    return '$who: $when, ganas ${pointsText(info.referrerPoints)}. Elige en qué local usarlo.';
  }

  @override
  Widget build(BuildContext context) {
    final hasLink = info.link != null && info.link!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.black, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.pink,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.black, width: 1.2),
                ),
                child: const Icon(Icons.group_add_rounded, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text('INVITA A UN AMIGO A FIDELITY', style: AppTypography.display(size: 22)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            info.referrerPoints > 0 ? _reward : 'Comparte tu código con tus amigos.',
            style: AppTypography.body(size: 14, weight: FontWeight.w300),
          ),
          if (info.friendPoints > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Tu amigo también gana ${pointsText(info.friendPoints)} con su primer escaneo.',
                style: AppTypography.body(size: 14, weight: FontWeight.w300),
              ),
            ),
          const SizedBox(height: 14),
          // El código, para copiarlo con un toque.
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _copy(context, info.code!, 'Código copiado'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(child: Text(info.code!, style: AppTypography.display(size: 28))),
                  const Icon(Icons.copy_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(hasLink ? 'COMPARTIR ENLACE' : 'COMPARTIR MI CÓDIGO'),
            ),
          ),
          if (hasLink)
            TextButton(
              onPressed: () => _copy(context, info.link!, 'Enlace copiado'),
              child: const Text('Copiar enlace'),
            ),
        ],
      ),
    );
  }
}

/// "TUS AMIGOS": un círculo por cada amigo que se necesita; los que ya cuentan van
/// rosas con un visto. Al completar el grupo, se gana el punto y arranca otro.
class FriendsProgressCard extends StatelessWidget {
  final ReferralInfo info;

  const FriendsProgressCard({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final total = info.friendsRequired;
    final done = info.inGroup;
    final missing = info.missing;
    final waiting = info.invited - info.counted;

    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('TUS AMIGOS', style: AppTypography.label(size: 12, tracking: 3))),
              Text('$done / $total', style: AppTypography.display(size: 24)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < total; i++)
                Container(
                  key: ValueKey(i < done ? 'amigo-$i-cuenta' : 'amigo-$i-falta'),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: i < done ? AppColors.pink : AppColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.black, width: 1.2),
                  ),
                  child: Icon(i < done ? Icons.check_rounded : Icons.person_outline_rounded, size: 22),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            missing == 1 ? 'Falta 1 amigo para ganar tu punto' : 'Faltan $missing amigos para ganar tu punto',
            style: AppTypography.body(size: 14, weight: FontWeight.w600),
          ),
          if (info.groupsPaid > 0)
            Text(
              'Ya ganaste ${pointsText(info.groupsPaid * info.referrerPoints)} con tus amigos.',
              style: AppTypography.body(size: 13, weight: FontWeight.w300),
            ),
          if (info.countsOnFirstScan && waiting > 0)
            Text(
              waiting == 1
                  ? '1 amigo aún no hace su primer escaneo'
                  : '$waiting amigos aún no hacen su primer escaneo',
              style: AppTypography.body(size: 13, weight: FontWeight.w300, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
