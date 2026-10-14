import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/validators/app_validators.dart';
import '../../../core/widgets/app_text_field.dart';

/// Campos de "Mi campaña": qué premio se entrega y cuántos puntos hacen falta.
/// Los usan la creación del negocio y la pantalla de ajustes de campaña.
class CampaignFormFields extends StatelessWidget {
  final TextEditingController rewardController;
  final TextEditingController rewardLongController;
  final TextEditingController pointsController;

  const CampaignFormFields({
    super.key,
    required this.rewardController,
    required this.rewardLongController,
    required this.pointsController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: rewardController,
          hint: '¿Qué premio entregas?',
          icon: Icons.card_giftcard_rounded,
          helperText: 'Por ejemplo: café gratis o 10% de descuento',
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          validator: AppValidators.validateRewardName,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: rewardLongController,
          hint: 'Detalles del premio (opcional)',
          icon: Icons.description_outlined,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: pointsController,
          hint: 'Puntos necesarios',
          icon: Icons.stars_outlined,
          helperText: 'Recomendamos entre 5 y 10 puntos',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          validator: AppValidators.validatePointsRequired,
        ),
      ],
    );
  }
}
