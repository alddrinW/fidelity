import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../l10n/translator.dart';
import '../theme/app_typography.dart';

/// Campo de texto de marca: píldora con contorno negro, icono a la izquierda
/// y, si [isPassword] es true, botón para mostrar u ocultar el contenido.
class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final String? helperText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  /// Campo de solo lectura (p. ej. correo registrado). Si se pasa [onTap]
  /// el campo sirve de selector: al tocarlo abre otra pantalla o una hoja.
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;
  final TextCapitalization textCapitalization;

  /// Widget al final del campo (p. ej. un candado o una flecha). En campos de
  /// contraseña lo reemplaza el botón de mostrar/ocultar.
  final Widget? trailing;

  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.trailing,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      textCapitalization: widget.textCapitalization,
      obscureText: widget.isPassword && _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      // Estilo completo de AppTypography: `copyWith(fontWeight:)` sobre un
      // estilo de google_fonts no cambia el archivo de fuente y caería a Roboto.
      style: AppTypography.body(size: 17, weight: FontWeight.w300),
      cursorColor: AppColors.black,
      decoration: InputDecoration(
        hintText: context.tr(widget.hint),
        helperText: widget.helperText == null ? null : context.tr(widget.helperText!),
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(start: 20, end: 12),
          child: Icon(widget.icon, size: 24),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: context.tr(_obscured ? 'Mostrar contraseña' : 'Ocultar contraseña'),
                icon: Icon(
                  _obscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : widget.trailing == null
                ? null
                : Padding(
                    padding: const EdgeInsetsDirectional.only(end: 16),
                    child: widget.trailing,
                  ),
      ),
    );
  }
}
