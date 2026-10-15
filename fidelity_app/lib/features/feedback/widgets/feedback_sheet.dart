import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/fido_says.dart';
import '../data/feedback_repository.dart';
import '../../../core/l10n/tr_text.dart';

/// Abre el buzón de sugerencias de Fido para un local. Devuelve `true` si el
/// cliente envió su opinión.
Future<bool?> showFeedbackSheet(
  BuildContext context, {
  required String businessId,
  required String businessName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => FeedbackSheet(businessId: businessId, businessName: businessName),
  );
}

/// Calificación rápida en tres opciones, etiquetas de motivo y, si el cliente
/// quiere, una sugerencia o un reclamo. Al enviar, Fido agradece.
class FeedbackSheet extends ConsumerStatefulWidget {
  final String businessId;
  final String businessName;

  const FeedbackSheet({super.key, required this.businessId, required this.businessName});

  @override
  ConsumerState<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<FeedbackSheet> {
  final _messageController = TextEditingController();

  FeedbackRating? _rating;
  FeedbackKind _kind = FeedbackKind.suggestion;
  final Set<String> _tags = {};
  bool _isSending = false;
  bool _sent = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _selectRating(FeedbackRating rating) {
    setState(() {
      _rating = rating;
      // Las etiquetas dependen de la calificación: se reinician al cambiarla.
      _tags.clear();
      _kind = rating == FeedbackRating.bad ? FeedbackKind.complaint : FeedbackKind.suggestion;
    });
  }

  /// Con calificación baja el comentario es obligatorio (es un reclamo).
  bool get _messageRequired => _rating == FeedbackRating.bad;

  String? _validate() {
    if (_rating == null && _messageController.text.trim().isEmpty) {
      return 'Elige cómo te atendieron o escribe un comentario.';
    }
    final length = _messageController.text.trim().length;
    if ((_messageRequired || (_rating == null && length > 0)) && length < 5) {
      return 'Cuéntanos un poco más sobre lo que pasó.';
    }
    if (length > 0 && length < 5) return 'El comentario es muy corto.';
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final hasMessage = _messageController.text.trim().isNotEmpty;
      await ref.read(feedbackRepositoryProvider).send(
            businessId: widget.businessId,
            rating: _rating,
            // Sin texto es una felicitación o una calificación: el backend lo deduce.
            kind: hasMessage ? _kind : null,
            tags: _tags.toList(),
            message: _messageController.text,
          );
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _sent ? _ThankYou(rating: _rating) : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final rating = _rating;
    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FidoSays(message: '¿Cómo te atendieron en ${widget.businessName}?'),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final option in FeedbackRating.values)
              _RatingOption(
                rating: option,
                selected: rating == option,
                onTap: () => _selectRating(option),
              ),
          ],
        ),
        if (rating != null) ...[
          const SizedBox(height: 20),
          Text('¿POR QUÉ?', style: AppTypography.label(size: 12, tracking: 4)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in rating.tags)
                FilterChip(
                  label: Text(tag),
                  selected: _tags.contains(tag),
                  showCheckmark: false,
                  onSelected: (on) => setState(() => on ? _tags.add(tag) : _tags.remove(tag)),
                  backgroundColor: AppColors.white,
                  selectedColor: AppColors.pink,
                  side: const BorderSide(color: AppColors.black, width: 1.2),
                  shape: const StadiumBorder(),
                  labelStyle: AppTypography.body(size: 14, weight: FontWeight.w400),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        if (rating != FeedbackRating.bad && rating != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                for (final kind in const [FeedbackKind.suggestion, FeedbackKind.complaint]) ...[
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: _kind == kind,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _kind = kind),
                    backgroundColor: AppColors.white,
                    selectedColor: AppColors.black,
                    side: const BorderSide(color: AppColors.black, width: 1.2),
                    shape: const StadiumBorder(),
                    labelStyle: AppTypography.body(
                      size: 14,
                      weight: FontWeight.w500,
                      color: _kind == kind ? AppColors.white : AppColors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        AppTextField(
          controller: _messageController,
          hint: _messageRequired
              ? 'Cuéntanos qué pasó'
              : 'Agrega un comentario (opcional)',
          icon: Icons.chat_bubble_outline_rounded,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 20),
        AppPrimaryButton(label: 'Enviar', isLoading: _isSending, onPressed: _submit),
      ],
    );
  }
}

class _RatingOption extends StatelessWidget {
  final FeedbackRating rating;
  final bool selected;
  final VoidCallback onTap;

  const _RatingOption({required this.rating, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: rating.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? AppColors.pink : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.black, width: selected ? 1.6 : 1.2),
                ),
                child: Icon(rating.icon, size: 44),
              ),
              const SizedBox(height: 6),
              Text(rating.label.toUpperCase(), style: AppTypography.label(size: 12, tracking: 3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Agradecimiento de Fido: celebra con las buenas calificaciones y se muestra
/// empático con las malas.
class _ThankYou extends StatelessWidget {
  final FeedbackRating? rating;

  const _ThankYou({required this.rating});

  @override
  Widget build(BuildContext context) {
    final sad = rating == FeedbackRating.bad;
    return Column(
      key: const ValueKey('thanks'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FidoSays(
          celebrating: !sad,
          message: sad
              ? 'Lamento lo que pasó. Ya avisé al local y a Fidelity para que lo revisen.'
              : '¡Gracias por contarme! Tu opinión ayuda a mejorar este local.',
        ),
        const SizedBox(height: 20),
        AppPrimaryButton(
          label: 'Listo',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
