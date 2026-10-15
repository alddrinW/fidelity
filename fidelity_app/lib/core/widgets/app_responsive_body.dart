import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';

/// Limita el ancho del contenido y lo centra, para que las pantallas pensadas
/// en formato móvil se vean bien también en Flutter Web o en pantallas anchas.
///
/// Con [adaptive] el ancho máximo crece en pantallas anchas (hasta 1,5 veces
/// [maxWidth]): úsalo en listas y paneles. Los formularios se quedan angostos.
class AppResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool adaptive;

  const AppResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.adaptive = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = adaptive ? adaptiveMaxWidth(maxWidth, context.screenWidth) : maxWidth;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }
}

/// Reparte [children] en columnas según el ancho disponible (cada columna con
/// al menos [minTileWidth]): una sola columna en el móvil, varias en el PC.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final double spacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 320,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + spacing) / (minTileWidth + spacing)).floor().clamp(1, 4);
        if (columns == 1) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: tileWidth, child: child)],
        );
      },
    );
  }
}
