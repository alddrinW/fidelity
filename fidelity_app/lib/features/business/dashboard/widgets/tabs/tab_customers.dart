import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../../../core/widgets/app_chip.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/person_avatar.dart';
import '../../providers/dashboard_provider.dart';
import '../client_detail_screen.dart';
import '../pending_reward_notice.dart';
import '../../../../../core/l10n/tr_text.dart';

/// Directorio de clientes del negocio, con búsqueda y suma manual de puntos.
class TabCustomers extends ConsumerStatefulWidget {
  const TabCustomers({super.key});

  @override
  ConsumerState<TabCustomers> createState() => _TabCustomersState();
}

class _TabCustomersState extends ConsumerState<TabCustomers> {
  String _searchQuery = '';

  Future<void> _addPoints(Map<String, dynamic> card) async {
    final points = await showDialog<int>(
      context: context,
      builder: (_) => _AddPointsDialog(
        customerName: (card['profiles']?['full_name'] ?? 'Cliente').toString(),
      ),
    );
    if (points != null) {
      ref.read(dashboardProvider.notifier).addManualPoints(card['user_id'], points);
    }
  }

  /// La ficha del cliente: sus puntos y sus premios.
  void _openClient(
    BuildContext context,
    Map<String, dynamic> card,
    Map<String, dynamic> business,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(card: card, business: business),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final customers = state.customers;
    final pendingRewards = state.pendingRewards;
    final business = state.business;

    if (business == null) return const SizedBox();

    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? customers
        : customers.where((card) {
            final name = card['profiles']?['full_name']?.toString().toLowerCase() ?? '';
            return name.contains(query);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: TextField(
            style: AppTypography.body(size: 17, weight: FontWeight.w300),
            decoration: const InputDecoration(
              hintText: 'Buscar cliente',
              prefixIcon: Icon(Icons.search_rounded, size: 24),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? AppEmptyState(
                  title: _searchQuery.isEmpty ? 'Aún sin clientes' : 'Sin resultados',
                  message: _searchQuery.isEmpty
                      ? 'Cuando alguien escanee tu QR y lo apruebes, aparecerá aquí.'
                      : 'Prueba con otro nombre.',
                )
              : ListView.separated(
                  // Abajo hay espacio para el botón "+" de la esquina.
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final card = filtered[index];
                    final profile = card['profiles'];
                    final name = (profile?['full_name'] ?? 'Usuario').toString();
                    final hasPendingReward = pendingRewards.any(
                      (r) =>
                          r['user_id'] == card['user_id'] &&
                          r['business_id'] == business['id'] &&
                          r['status'] == 'pending',
                    );

                    return AppCard(
                      padding: const EdgeInsets.all(16),
                      onTap: () => _openClient(context, card, business),
                      child: Row(
                        children: [
                          PersonAvatar(
                            name: name,
                            avatarUrl: profile?['avatar_url']?.toString(),
                            size: 56,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.display(size: 20),
                                      ),
                                    ),
                                    if (profile?['is_demo'] == true) ...[
                                      const SizedBox(width: 8),
                                      const AppChip(label: 'Demo', style: AppChipStyle.outline),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${card['current_points'] ?? 0}/${business['points_required'] ?? '?'} PUNTOS',
                                  style: AppTypography.label(size: 13, tracking: 1),
                                ),
                                Text(
                                  '${card['total_points_lifetime'] ?? 0} en total · '
                                  '${card['rewards_claimed'] ?? 0} premios',
                                  style: AppTypography.body(
                                    size: 13,
                                    weight: FontWeight.w300,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          hasPendingReward
                              ? IconButton(
                                  tooltip: 'Premio pendiente',
                                  icon: const Icon(Icons.lock_outline_rounded),
                                  style: IconButton.styleFrom(
                                    side: const BorderSide(color: AppColors.black, width: 1.2),
                                  ),
                                  onPressed: () => showPendingRewardNotice(context),
                                )
                              : IconButton(
                                  tooltip: 'Sumar puntos',
                                  icon: const Icon(Icons.add_rounded, color: AppColors.white),
                                  style: IconButton.styleFrom(backgroundColor: AppColors.black),
                                  onPressed: () => _addPoints(card),
                                ),
                        ],
                      ),
                    )
                        .animate(delay: (index.clamp(0, 6) * 50).ms)
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.06, curve: Curves.easeOutCubic);
                  },
                ),
        ),
      ],
    );
  }
}

/// Pide cuántos puntos sumar a un cliente. Cierra devolviendo la cantidad o
/// `null` si se cancela; libera su controlador al cerrarse.
class _AddPointsDialog extends StatefulWidget {
  final String customerName;

  const _AddPointsDialog({required this.customerName});

  @override
  State<_AddPointsDialog> createState() => _AddPointsDialogState();
}

class _AddPointsDialogState extends State<_AddPointsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController(text: '1');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final points = int.tryParse(value?.trim() ?? '');
    if (points == null || points < 1) return 'Ingresa al menos 1 punto';
    if (points > 100) return 'Máximo 100 puntos a la vez';
    return null;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(int.parse(_controller.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(
        'SUMAR PUNTOS',
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 28),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.customerName,
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 16, weight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _controller,
              hint: 'Puntos a sumar',
              icon: Icons.stars_outlined,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              onSubmitted: (_) => _submit(),
              validator: _validate,
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppPrimaryButton(label: 'Agregar', onPressed: _submit),
            const SizedBox(height: 4),
            AppTextAction(label: 'Cancelar', onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ],
    );
  }
}
