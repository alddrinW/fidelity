import 'package:flutter/material.dart' hide Text;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/l10n/tr_text.dart';

/// Aviso breve que baja desde arriba y se oculta solo: píldora negra para
/// confirmaciones y roja para errores.
class DashboardAnimatedToast extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDone;

  const DashboardAnimatedToast({
    super.key,
    required this.message,
    required this.isError,
    required this.onDone,
  });

  static void show(BuildContext context, String message, {bool isError = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => DashboardAnimatedToast(
        message: message,
        isError: isError,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<DashboardAnimatedToast> createState() => _DashboardAnimatedToastState();
}

class _DashboardAnimatedToastState extends State<DashboardAnimatedToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _slide = Tween<double>(begin: -1.0, end: 0.0).animate(
    CurvedAnimation(parent: _controller, curve: const Cubic(0.34, 1.56, 0.64, 1)),
  );
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _controller.forward();

    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.isError ? AppColors.error : AppColors.black;

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 16,
      left: 24,
      right: 24,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, _slide.value * 80),
              child: Opacity(opacity: _fade.value, child: child),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                      color: AppColors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: AppTypography.body(
                          size: 15,
                          weight: FontWeight.w500,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
