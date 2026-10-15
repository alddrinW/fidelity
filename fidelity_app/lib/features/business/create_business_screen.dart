import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/business_category.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_picking.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_photo_picker.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../auth/providers/auth_provider.dart';
import '../payments/paga_ya_screen.dart';
import 'data/business_repository.dart';
import 'providers/create_business_provider.dart';
import 'widgets/business_form_fields.dart';
import 'widgets/campaign_form_fields.dart';
import 'widgets/location_picker_page.dart';
import '../../core/l10n/tr_text.dart';

/// Alta de un negocio en dos pasos: "Mi negocio" (logo, datos y ubicación) y
/// "Mi campaña" (premio y puntos).
class CreateBusinessScreen extends ConsumerStatefulWidget {
  /// Si se indica, se crea una **sucursal** de este negocio (sus datos sirven
  /// de punto de partida) y el flujo termina en PAGA YA.
  final Map<String, dynamic>? parent;

  const CreateBusinessScreen({super.key, this.parent});

  @override
  ConsumerState<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends ConsumerState<CreateBusinessScreen> {
  int _step = 0;

  final _businessFormKey = GlobalKey<FormState>();
  final _campaignFormKey = GlobalKey<FormState>();

  PickedImage? _logo;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _addressController = TextEditingController();
  BusinessCategory? _selectedCategory;
  List<BusinessCategory> _categories = [];
  double? _latitude;
  double? _longitude;

  final _rewardController = TextEditingController();
  final _rewardLongController = TextEditingController();
  final _pointsController = TextEditingController(text: '10');

  bool get _isBranch => widget.parent != null;

  @override
  void initState() {
    super.initState();
    _prefillFromParent();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  /// Una sucursal hereda los datos del negocio principal (se pueden editar).
  void _prefillFromParent() {
    final p = widget.parent;
    if (p == null) return;
    String text(Object? v) => v?.toString() ?? '';
    _nameController.text = '${text(p['name'])} - ';
    _phoneController.text = text(p['phone']);
    _taxIdController.text = text(p['taxId'] ?? p['tax_id']);
    _rewardController.text = text(p['rewardDescription'] ?? p['reward_description']);
    _rewardLongController.text =
        text(p['rewardLongDescription'] ?? p['reward_long_description']);
    final points = p['pointsRequired'] ?? p['points_required'];
    if (points != null) _pointsController.text = text(points);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _taxIdController.dispose();
    _addressController.dispose();
    _rewardController.dispose();
    _rewardLongController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ref.read(businessRepositoryProvider).getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          final parentCategoryId = widget.parent?['categoryId'] ?? widget.parent?['category_id'];
          _selectedCategory ??= categories
                  .where((c) => c.id.toString() == parentCategoryId?.toString())
                  .firstOrNull ??
              (categories.isNotEmpty ? categories.first : null);
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await pickImageFromGallery();
      if (picked != null && mounted) setState(() => _logo = picked);
    } on FormatException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('No se pudo seleccionar la imagen.');
    }
  }

  Future<void> _pickLocation() async {
    final selection = await pickBusinessLocation(
      context,
      latitude: _latitude,
      longitude: _longitude,
      address: _addressController.text,
    );
    if (selection == null || !mounted) return;
    setState(() {
      _latitude = selection.latitude;
      _longitude = selection.longitude;
      _addressController.text = selection.address;
    });
  }

  void _next() {
    if (_step == 0) {
      if (_businessFormKey.currentState!.validate()) setState(() => _step = 1);
    } else if (_campaignFormKey.currentState!.validate()) {
      _submit();
    }
  }

  void _back() {
    if (_step == 1) {
      setState(() => _step = 0);
    } else if (_isBranch) {
      Navigator.of(context).pop();
    } else {
      _confirmExit();
    }
  }

  /// El alta es obligatoria para usar la cuenta de negocio: salir implica
  /// cerrar sesión. Podrá terminarla al volver a entrar.
  void _confirmExit() {
    showDialog(
      context: context,
      builder: (_) => AppMessageDialog(
        icon: Icons.logout_rounded,
        title: '¿Salir por ahora?',
        message: 'Cerraremos tu sesión. Podrás terminar de configurar tu '
            'negocio cuando vuelvas a entrar.',
        primaryLabel: 'Cerrar sesión',
        onPrimary: () => ref.read(authStateProvider.notifier).logout(),
        secondaryLabel: 'Seguir aquí',
      ),
    );
  }

  void _submit() {
    ref.read(createBusinessProvider.notifier).submitBusiness(
          logoDataUri: _logo?.dataUri,
          businessName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          taxId: _taxIdController.text.trim(),
          address: _addressController.text,
          latitude: _latitude,
          longitude: _longitude,
          categoryId: _selectedCategory?.id.toString(),
          rewardDescription: _rewardController.text,
          rewardLongDescription: _rewardLongController.text,
          pointsRequired: int.tryParse(_pointsController.text.trim()) ?? 10,
          parentId: widget.parent?['id']?.toString(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createBusinessProvider);

    ref.listen<CreateBusinessState>(createBusinessProvider, (previous, next) {
      // Al crearse el primer negocio la sesión pasa sola a la pantalla de
      // activación (PAGA YA). Una sucursal abre PAGA YA desde aquí.
      if (next.error != null && previous?.error != next.error) {
        _showError('No se pudo crear el negocio: ${next.error}');
      } else if (next.isSuccess && previous?.isSuccess != true && _isBranch) {
        final order = next.createdPayment;
        ref.invalidate(createBusinessProvider);
        if (order == null) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => PagaYaScreen(order: order)),
          );
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          child: Column(
            children: [
              AppPageHeader(
                title: _isBranch
                    ? (_step == 0 ? 'Nueva sucursal' : 'Su campaña')
                    : (_step == 0 ? 'Mi negocio' : 'Mi campaña'),
                onBack: createState.isLoading ? () {} : _back,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _step == 0 ? _buildBusinessStep() : _buildCampaignStep(),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 32, 32),
                  child: AppCircleButton(
                    tooltip: _step == 0 ? 'Continuar con la campaña' : 'Crear mi negocio',
                    isLoading: createState.isLoading,
                    onPressed: _next,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessStep() {
    return Form(
      key: _businessFormKey,
      child: Column(
        key: const ValueKey('step-business'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AppPhotoPicker(
              caption: 'Logo de negocio',
              image: _logo == null ? null : MemoryImage(_logo!.bytes),
              onTap: _pickLogo,
            ),
          ),
          const SizedBox(height: 32),
          const _SectionLabel('DATOS DE MI NEGOCIO'),
          BusinessFormFields(
            nameController: _nameController,
            phoneController: _phoneController,
            taxIdController: _taxIdController,
            addressController: _addressController,
            hasLocation: _latitude != null && _longitude != null,
            onPickLocation: _pickLocation,
            category: _selectedCategory,
            categories: _categories,
            onCategoryChanged: (c) => setState(() => _selectedCategory = c),
            onRetryCategories: _loadCategories,
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignStep() {
    return Form(
      key: _campaignFormKey,
      child: Column(
        key: const ValueKey('step-campaign'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel('TU PRIMER SISTEMA DE PUNTOS'),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 20),
            child: Text(
              '¿Qué ganan tus clientes y cuántos puntos necesitan?',
              style: AppTypography.body(size: 15, weight: FontWeight.w300),
            ),
          ),
          CampaignFormFields(
            rewardController: _rewardController,
            rewardLongController: _rewardLongController,
            pointsController: _pointsController,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(text, style: AppTypography.label(size: 13, tracking: 5)),
    );
  }
}
