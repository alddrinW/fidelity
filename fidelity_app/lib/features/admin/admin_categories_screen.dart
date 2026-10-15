import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/app_text_field.dart';
import '../business/dashboard/widgets/dashboard_animated_toast.dart';
import 'widgets/admin_widgets.dart';
import '../../core/l10n/tr_text.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().get('businesses/categories');
      if (mounted) {
        setState(() {
          if (response is List) _categories = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        DashboardAnimatedToast.show(context, 'Error al cargar categorías', isError: true);
      }
    }
  }

  Future<void> _addCategory(String name) async {
    try {
      await ApiClient().post('businesses/categories', body: {'name': name});
      await _loadCategories();
    } catch (e) {
      if (mounted) {
        DashboardAnimatedToast.show(context, 'Error al guardar la categoría', isError: true);
      }
    }
  }

  Future<void> _deleteCategory(dynamic id) async {
    try {
      await ApiClient().delete('businesses/categories/$id');
      await _loadCategories();
    } catch (e) {
      if (mounted) {
        DashboardAnimatedToast.show(
          context,
          'No se pudo eliminar (probablemente está en uso)',
          isError: true,
        );
      }
    }
  }

  void _confirmDelete(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.delete_outline_rounded,
        title: 'Eliminar categoría',
        message: '¿Seguro que quieres eliminar "${category['name']}"?',
        hint: 'Podría afectar a los negocios que la tengan asignada.',
        primaryLabel: 'Eliminar',
        onPrimary: () => _deleteCategory(category['id']),
        secondaryLabel: 'Cancelar',
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewCategoryDialog(),
    );
    if (name != null) await _addCategory(name);
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: 'Categorías',
      bottom: AppPrimaryButton(label: 'Nueva categoría', onPressed: _showAddDialog),
      body: _isLoading
          ? const AdminLoading()
          : _categories.isEmpty
              ? const AppEmptyState(
                  title: 'Sin categorías',
                  message: 'Crea la primera para que los negocios puedan elegirla.',
                )
              : RefreshIndicator(
                  onRefresh: _loadCategories,
                  color: AppColors.black,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return AppCard(
                        radius: 28,
                        padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: AppColors.pink,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.category_rounded, color: AppColors.black),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                '${category['name']}'.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.display(size: 22),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Eliminar categoría',
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () => _confirmDelete(category),
                            ),
                          ],
                        ),
                      ).animate(delay: Duration(milliseconds: 30 * (index % 8))).fadeIn();
                    },
                  ),
                ),
    );
  }
}

/// Diálogo para el nombre de la nueva categoría. Es un widget propio para que
/// el controlador viva y se libere junto con el diálogo.
class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Text(
        'NUEVA CATEGORÍA',
        textAlign: TextAlign.center,
        style: AppTypography.display(size: 26),
      ),
      content: Form(
        key: _formKey,
        child: AppTextField(
          controller: _controller,
          hint: 'Nombre de la categoría',
          icon: Icons.category_outlined,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('GUARDAR')),
      ],
    );
  }
}
