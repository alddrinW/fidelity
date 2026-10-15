import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tarjeta de marca: fondo blanco, contorno negro fino y esquinas muy
/// redondeadas (la misma forma de las tarjetas de Inicio). Si recibe [onTap]
/// responde al toque.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.radius = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: AppColors.border, width: 1.2),
    );

    return Material(
      color: color ?? AppColors.white,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
