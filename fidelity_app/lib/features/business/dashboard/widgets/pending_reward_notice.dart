import 'package:flutter/material.dart';

import '../../../../core/widgets/app_message_dialog.dart';

/// Explica por qué no se pueden sumar más puntos a un cliente que tiene un
/// premio pendiente: primero hay que entregarlo.
void showPendingRewardNotice(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => const AppMessageDialog(
      icon: Icons.card_giftcard_rounded,
      title: 'Premio pendiente',
      message: 'Este cliente ya ganó un premio. No puedes sumarle más puntos '
          'hasta que se lo entregues y lo marques como entregado.',
      primaryLabel: 'Entendido',
    ),
  );
}
