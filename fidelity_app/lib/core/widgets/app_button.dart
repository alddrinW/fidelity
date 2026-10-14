import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Botón principal de marca: píldora negra con etiqueta extendida y espaciada.
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 66,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.black,
          disabledForegroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.white,
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label.toUpperCase(),
                  style: AppTypography.label(
                    size: 16,
                    tracking: 6,
                    color: AppColors.white,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Texto de acción secundaria (p. ej. "REGISTRARME"): sin caja, solo etiqueta.
class AppTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AppTextAction({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.label(size: 14, tracking: 6),
      ),
    );
  }
}

/// Botón circular con flecha para avanzar de paso. Rosa por defecto; con
/// [dark] es negro con flecha blanca (cierre de un flujo, p. ej. escaneo).
class AppCircleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool dark;
  final String tooltip;

  const AppCircleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.dark = false,
    this.tooltip = 'Continuar',
  });

  static const double size = 68;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final background = dark ? AppColors.black : AppColors.pink;
    final foreground = dark ? AppColors.white : AppColors.black;
    return Tooltip(
      message: tooltip,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: onPressed == null ? 0.45 : 1,
        child: Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: foreground,
                        ),
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        size: 40,
                        color: foreground,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
