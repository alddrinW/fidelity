import 'package:flutter/material.dart';

/// Limita el ancho del contenido y lo centra, para que las pantallas pensadas
/// en formato móvil se vean bien también en Flutter Web o en pantallas anchas.
class AppResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AppResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
