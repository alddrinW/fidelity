import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/validators/app_validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_message_dialog.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_responsive_body.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/fido_says.dart';
import '../../../core/widgets/person_avatar.dart';
import '../dashboard/widgets/dashboard_animated_toast.dart';
import 'team_repository.dart';
import '../../../core/l10n/tr_text.dart';

/// "Mi equipo": el dueño asigna el rol **Aprobador** a supervisores del local.
/// Un aprobador aprueba escaneos, valida premios y atiende las opiniones de
/// los clientes, pero no edita el negocio ni ve pagos o estadísticas.
class TeamScreen extends ConsumerStatefulWidget {
  final String businessId;
  final String businessName;

  const TeamScreen({super.key, required this.businessId, required this.businessName});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  bool _isLoading = true;
  List<TeamMember> _members = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final members = await ref.read(teamRepositoryProvider).list(widget.businessId);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        DashboardAnimatedToast.show(context, 'No se pudo cargar el equipo', isError: true);
      }
    }
  }

  Future<void> _add() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => const _AddApproverDialog(),
    );
    if (email == null) return;
    try {
      final member = await ref.read(teamRepositoryProvider).add(widget.businessId, email);
      if (!mounted) return;
      DashboardAnimatedToast.show(context, '${member.displayName} ahora es aprobador');
      await _load();
    } catch (e) {
      if (mounted) DashboardAnimatedToast.show(context, e.toString(), isError: true);
    }
  }

  void _confirmRemove(TeamMember member) {
    showDialog(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.person_remove_outlined,
        title: '¿Quitar aprobador?',
        message: '${member.displayName} dejará de aprobar escaneos y premios de '
            '${widget.businessName}.',
        primaryLabel: 'Quitar',
        onPrimary: () async {
          try {
            await ref.read(teamRepositoryProvider).remove(widget.businessId, member.userId);
            if (!mounted) return;
            DashboardAnimatedToast.show(context, 'Aprobador quitado');
            await _load();
          } catch (e) {
            if (mounted) DashboardAnimatedToast.show(context, e.toString(), isError: true);
          }
        },
        secondaryLabel: 'Cancelar',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          adaptive: true,
          child: Column(
            children: [
              const AppPageHeader(title: 'Mi equipo'),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.black))
                    : RefreshIndicator(
                        color: AppColors.black,
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          children: [
                            const FidoSays(
                              message: 'Un aprobador revisa los escaneos, entrega los premios y '
                                  'atiende las opiniones de tu local.',
                            ),
                            const SizedBox(height: 24),
                            if (_members.isEmpty)
                              const SizedBox(
                                height: 280,
                                child: AppEmptyState(
                                  title: 'Sin aprobadores',
                                  message: 'Agrega a alguien de confianza para repartir el trabajo.',
                                  imageHeight: 120,
                                ),
                              )
                            else
                              for (var i = 0; i < _members.length; i++) ...[
                                _MemberCard(
                                  member: _members[i],
                                  onRemove: () => _confirmRemove(_members[i]),
                                ).animate(delay: (40 * i).ms).fadeIn().slideY(begin: 0.06),
                                const SizedBox(height: 12),
                              ],
                          ],
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: AppPrimaryButton(label: 'Agregar aprobador', onPressed: _add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final TeamMember member;
  final VoidCallback onRemove;

  const _MemberCard({required this.member, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          PersonAvatar(name: member.displayName, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(size: 16, weight: FontWeight.w500),
                ),
                Text(
                  member.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 13,
                    weight: FontWeight.w300,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar aprobador',
            icon: const Icon(Icons.person_remove_outlined),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _AddApproverDialog extends StatefulWidget {
  const _AddApproverDialog();

  @override
  State<_AddApproverDialog> createState() => _AddApproverDialogState();
}

class _AddApproverDialogState extends State<_AddApproverDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(
        'NUEVO APROBADOR',
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 26),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Escribe el correo con el que esa persona se registró en Fidelity. '
              'Pasará a usar la app como aprobador de tu local.',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 15, weight: FontWeight.w300),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _controller,
              hint: 'Correo del aprobador',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: AppValidators.validateEmail,
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('AGREGAR')),
      ],
    );
  }
}
