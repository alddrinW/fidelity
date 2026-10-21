import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Una lista de tarjetas "montadas" como en un portafolio: cada una se solapa
/// con la de arriba y le deja caer su sombra, así que se ven apiladas.
///
/// Solo pone la animación y el relieve; el diseño de cada tarjeta lo da
/// [itemBuilder].
class StackedCardList extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Cuánto tapa cada tarjeta a la de arriba.
  final double overlap;

  /// El radio de las esquinas de las tarjetas (la sombra lo sigue).
  final double radius;

  /// El espacio alrededor de la lista (deja sitio al botón de escanear).
  final EdgeInsets padding;

  const StackedCardList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.overlap = 14,
    this.radius = 28,
    this.padding = const EdgeInsets.fromLTRB(0, 8, 0, 110),
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) => _Overlapped(
        // Cada tarjeta mide menos que su contenido: la siguiente empieza antes
        // de que acabe y la tapa. Así el toque cae en la tarjeta que se ve.
        overlap: index == itemCount - 1 ? 0 : overlap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            // La sombra sube: cae sobre la tarjeta de arriba y la deja "montada".
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: itemBuilder(context, index),
        ),
      ),
    );
  }
}

/// Reduce el alto que ocupa su hijo en [overlap] (el hijo se sigue dibujando
/// entero y sobresale por abajo), que es lo que deja a la siguiente montarse.
class _Overlapped extends SingleChildRenderObjectWidget {
  final double overlap;

  const _Overlapped({required this.overlap, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderOverlapped(overlap);

  @override
  void updateRenderObject(BuildContext context, _RenderOverlapped renderObject) {
    renderObject.overlap = overlap;
  }
}

class _RenderOverlapped extends RenderShiftedBox {
  _RenderOverlapped(this._overlap) : super(null);

  double _overlap;

  set overlap(double value) {
    if (_overlap == value) return;
    _overlap = value;
    markNeedsLayout();
  }

  Size _sizeFor(Size child, BoxConstraints constraints) =>
      constraints.constrain(Size(child.width, math.max(0, child.height - _overlap)));

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return _sizeFor(child.getDryLayout(constraints), constraints);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = _sizeFor(child.size, constraints);
  }
}
