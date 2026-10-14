import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/business_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/validators/app_validators.dart';
import '../../../core/widgets/app_text_field.dart';

/// Campos de "Mi negocio": nombre, teléfono de atención, cédula o RUC,
/// dirección (se elige en el mapa) y categoría. Los usan la creación del
/// negocio y su edición, para que se vean y validen igual.
///
/// Los controladores y el estado (ubicación, categoría) son del padre.
class BusinessFormFields extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController taxIdController;
  final TextEditingController addressController;

  /// Si ya hay coordenadas elegidas. Sin ellas la dirección no es válida.
  final bool hasLocation;
  final VoidCallback onPickLocation;

  final BusinessCategory? category;
  final List<BusinessCategory> categories;
  final ValueChanged<BusinessCategory> onCategoryChanged;

  /// Se llama al tocar el selector cuando la lista está vacía (p. ej. falló
  /// la carga), para que el padre vuelva a pedirla.
  final VoidCallback? onRetryCategories;

  /// En la creación la cédula/RUC es obligatoria; al editar un negocio que
  /// aún no la tiene se deja opcional para no bloquear otros cambios.
  final bool taxIdRequired;

  const BusinessFormFields({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.taxIdController,
    required this.addressController,
    required this.hasLocation,
    required this.onPickLocation,
    required this.category,
    required this.categories,
    required this.onCategoryChanged,
    this.onRetryCategories,
    this.taxIdRequired = true,
  });

  @override
  State<BusinessFormFields> createState() => _BusinessFormFieldsState();
}

class _BusinessFormFieldsState extends State<BusinessFormFields> {
  late final TextEditingController _categoryController =
      TextEditingController(text: widget.category?.name ?? '');

  @override
  void didUpdateWidget(covariant BusinessFormFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    final name = widget.category?.name ?? '';
    if (_categoryController.text != name) _categoryController.text = name;
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    if (widget.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay categorías disponibles. Reintentando...'),
        ),
      );
      widget.onRetryCategories?.call();
      return;
    }
    final selected = await showModalBottomSheet<BusinessCategory>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => _CategorySheet(
        categories: widget.categories,
        selected: widget.category,
      ),
    );
    if (selected != null) widget.onCategoryChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: widget.nameController,
          hint: 'Nombre del negocio',
          icon: Icons.apartment_rounded,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: AppValidators.validateBusinessName,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: widget.phoneController,
          hint: 'Teléfono de atención',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: AppValidators.validateBusinessPhone,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: widget.taxIdController,
          hint: 'Cédula propietario ó RUC',
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(13),
          ],
          validator: (v) =>
              AppValidators.validateTaxId(v, required: widget.taxIdRequired),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: widget.addressController,
          hint: 'Dirección',
          icon: Icons.location_on_outlined,
          readOnly: true,
          onTap: widget.onPickLocation,
          trailing: const Icon(Icons.map_outlined, size: 22),
          validator: (_) =>
              widget.hasLocation ? null : 'Selecciona la ubicación en el mapa',
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _categoryController,
          hint: 'Categoría',
          icon: Icons.category_outlined,
          readOnly: true,
          onTap: _pickCategory,
          trailing: const Icon(Icons.expand_more_rounded, size: 26),
          validator: (_) =>
              widget.category == null ? 'Selecciona una categoría' : null,
        ),
      ],
    );
  }
}

class _CategorySheet extends StatelessWidget {
  final List<BusinessCategory> categories;
  final BusinessCategory? selected;

  const _CategorySheet({required this.categories, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'CATEGORÍA',
                style: AppTypography.display(size: 28),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = category == selected;
                  return ListTile(
                    title: Text(
                      category.name,
                      style: AppTypography.body(
                        size: 17,
                        weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: AppColors.black)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    tileColor: isSelected ? AppColors.pink : null,
                    onTap: () => Navigator.of(context).pop(category),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
