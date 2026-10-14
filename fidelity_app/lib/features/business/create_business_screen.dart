import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/business_category.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_picking.dart';
import '../../core/utils/whatsapp_launcher.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_message_dialog.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_photo_picker.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../auth/providers/auth_provider.dart';
import 'data/business_repository.dart';
import 'providers/create_business_provider.dart';
import 'widgets/business_form_fields.dart';
import 'widgets/campaign_form_fields.dart';
import 'widgets/location_picker_page.dart';

/// Alta de un negocio en dos pasos: "Mi negocio" (logo, datos y ubicación) y
/// "Mi campaña" (premio y puntos).
class CreateBusinessScreen extends ConsumerStatefulWidget {
  const CreateBusinessScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
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
          _selectedCategory ??= categories.isNotEmpty ? categories.first : null;
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
        );
  }

  void _showSuccessDialog() {
    final waMessage =
        'Hola, acabo de crear mi negocio ${_nameController.text.trim()} y quiero '
        'información para activar la cuenta.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BusinessCreatedDialog(
        onEmail: () => launchUrl(
          Uri.parse('mailto:fidelitysistemadefidelizacion@gmail.com'),
        ),
        onWhatsApp: () => openSupportWhatsApp(waMessage),
        onDone: () {
          Navigator.pop(ctx);
          ref.read(authStateProvider.notifier).logout();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createBusinessProvider);

    ref.listen<CreateBusinessState>(createBusinessProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        _showError('No se pudo crear el negocio: ${next.error}');
      } else if (next.isSuccess && previous?.isSuccess != next.isSuccess) {
        _showSuccessDialog();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          child: Column(
            children: [
              AppPageHeader(
                title: _step == 0 ? 'Mi negocio' : 'Mi campaña',
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

/// Aviso tras crear el negocio: hay que contactar a Fidelity para activarlo.
class _BusinessCreatedDialog extends StatelessWidget {
  final VoidCallback onEmail;
  final VoidCallback onWhatsApp;
  final VoidCallback onDone;

  const _BusinessCreatedDialog({
    required this.onEmail,
    required this.onWhatsApp,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.pink,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_outlined, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              '¡TODO LISTO!',
              textAlign: TextAlign.center,
              style: AppTypography.display(size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              'Tu negocio fue creado. Para activarlo en la plataforma, '
              'comunícate con nosotros por WhatsApp o correo.',
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 16),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onWhatsApp,
                icon: const Icon(Icons.chat_bubble_outline, color: AppColors.white),
                label: const Text('WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: AppColors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEmail,
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Enviar correo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.black,
                  side: const BorderSide(color: AppColors.black, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                  textStyle: AppTypography.label(size: 14, tracking: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        AppPrimaryButton(label: 'Entendido', onPressed: onDone),
      ],
    );
  }
}
