import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/business_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/image_picking.dart';
import '../../../core/utils/image_source.dart';
import '../../../core/widgets/app_nav_row.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_photo_picker.dart';
import '../../../core/widgets/app_responsive_body.dart';
import '../../profile/user_profile_screen.dart';
import '../data/business_repository.dart';
import '../widgets/business_form_fields.dart';
import '../widgets/location_picker_page.dart';
import 'campaign_settings_screen.dart';

/// "Mi negocio": edición de los datos del negocio, con accesos a los ajustes
/// de campaña y a los datos personales del dueño.
///
/// Al cerrarse devuelve `true` si algo cambió, para que el panel se actualice.
class BusinessProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> business;

  const BusinessProfileScreen({super.key, required this.business});

  @override
  ConsumerState<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _taxIdController;
  late final TextEditingController _addressController;

  String? _logoUrl;
  PickedImage? _newLogo;

  BusinessCategory? _selectedCategory;
  List<BusinessCategory> _categories = [];

  double? _latitude;
  double? _longitude;

  bool _isSaving = false;

  /// `true` si se guardó algo aquí o en la pantalla de campaña.
  bool _changed = false;

  /// Los campos `decimal` de Postgres llegan como texto desde el backend.
  static double? _toDouble(Object? value) =>
      value == null ? null : double.tryParse(value.toString());

  static String _text(Object? value) => value?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    final b = widget.business;
    _logoUrl = (b['logo_url'] ?? b['logoUrl'])?.toString();
    _nameController = TextEditingController(text: _text(b['name']));
    _phoneController = TextEditingController(text: _text(b['phone']));
    _taxIdController = TextEditingController(text: _text(b['tax_id'] ?? b['taxId']));
    _addressController = TextEditingController(text: _text(b['address']));
    _latitude = _toDouble(b['latitude']);
    _longitude = _toDouble(b['longitude']);
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _taxIdController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ref.read(businessRepositoryProvider).getCategories();
      if (!mounted) return;
      final categoryId = widget.business['category_id'] ?? widget.business['categoryId'];
      setState(() {
        _categories = categories;
        for (final c in categories) {
          if (c.id.toString() == categoryId?.toString()) _selectedCategory = c;
        }
      });
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
      if (picked != null && mounted) setState(() => _newLogo = picked);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(businessRepositoryProvider).updateBusinessData(
            businessId: widget.business['id'].toString(),
            name: _nameController.text,
            phone: _phoneController.text,
            taxId: _taxIdController.text,
            address: _addressController.text,
            latitude: _latitude!,
            longitude: _longitude!,
            categoryId: _selectedCategory?.id,
            logoDataUri: _newLogo?.dataUri,
          );
      _changed = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Negocio actualizado')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openCampaign() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignSettingsScreen(business: widget.business),
      ),
    );
    if (saved == true) _changed = true;
  }

  void _openOwnerData() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logo = _newLogo != null
        ? MemoryImage(_newLogo!.bytes)
        : imageProviderFromUrl(_logoUrl);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        body: SafeArea(
          child: AppResponsiveBody(
            child: Column(
              children: [
                AppPageHeader(
                  title: 'Mi negocio',
                  onBack: () => Navigator.pop(context, _changed),
                  trailing: _isSaving
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : IconButton(
                          tooltip: 'Guardar',
                          icon: const Icon(
                            Icons.check_rounded,
                            size: 36,
                            color: AppColors.black,
                          ),
                          onPressed: _save,
                        ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: AppPhotoPicker(
                              caption: 'Logo de negocio',
                              image: logo,
                              heroTag: 'business_logo',
                              onTap: _pickLogo,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 12),
                            child: Text(
                              'DATOS DE MI NEGOCIO',
                              style: AppTypography.label(size: 13, tracking: 5),
                            ),
                          ),
                          BusinessFormFields(
                            nameController: _nameController,
                            phoneController: _phoneController,
                            taxIdController: _taxIdController,
                            addressController: _addressController,
                            hasLocation: _latitude != null && _longitude != null,
                            onPickLocation: _pickLocation,
                            category: _selectedCategory,
                            categories: _categories,
                            onCategoryChanged: (c) =>
                                setState(() => _selectedCategory = c),
                            onRetryCategories: _loadCategories,
                            taxIdRequired: false,
                          ),
                          const SizedBox(height: 16),
                          AppNavRow(
                            icon: Icons.savings_outlined,
                            label: 'Ajustar mi campaña',
                            onTap: _openCampaign,
                          ),
                          const SizedBox(height: 16),
                          AppNavRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Ajustar mis datos',
                            onTap: _openOwnerData,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
