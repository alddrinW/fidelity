import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/image_source.dart';

/// Avatar circular del usuario que se renderiza IGUAL a cualquier tamaño
/// (rellena el contenedor que lo contiene). Al usarse como hijo del Hero y
/// como `flightShuttleBuilder`, la transición vuela como UNA sola pieza —
/// la foto o la silueta escalan suave, sin "rearmarse".
///
/// Sin foto se muestra la silueta blanca sobre círculo negro del mockup.
class UserAvatarCircle extends StatelessWidget {
  final String? avatarUrl;
  /// Foto recién elegida (aún sin guardar); tiene prioridad sobre [avatarUrl].
  final Uint8List? newAvatarBytes;

  const UserAvatarCircle({
    super.key,
    this.avatarUrl,
    this.newAvatarBytes,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = newAvatarBytes;
    final ImageProvider? image =
        bytes != null ? MemoryImage(bytes) : imageProviderFromUrl(avatarUrl);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.black,
        image: image != null
            ? DecorationImage(image: image, fit: BoxFit.cover)
            : null,
      ),
      child: image == null
          ? LayoutBuilder(
              builder: (context, constraints) {
                // Ícono proporcional al tamaño del círculo (44px o 120px o el
                // tamaño intermedio durante el vuelo del Hero) → escala parejo.
                final side = constraints.biggest.shortestSide;
                final iconSize = side.isFinite && side > 0 ? side * 0.62 : 28.0;
                return Center(
                  child: Icon(
                    Icons.person_rounded,
                    size: iconSize,
                    color: AppColors.white,
                  ),
                );
              },
            )
          : null,
    );
  }
}
