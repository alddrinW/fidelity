import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_responsive_body.dart';
import '../data/business_repository.dart';
import '../widgets/campaign_form_fields.dart';

/// "Mi campaña": premio que entrega el negocio y puntos necesarios.
/// Cierra devolviendo `true` si se guardaron cambios.
class CampaignSettingsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> business;

  const CampaignSettingsScreen({super.key, required this.business});

  @override
  ConsumerState<CampaignSettingsScreen> createState() => _CampaignSettingsScreenState();
}

class _CampaignSettingsScreenState extends ConsumerState<CampaignSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _rewardController;
  late final TextEditingController _rewardLongController;
  late final TextEditingController _pointsController;
  bool _isSaving = false;

  static String _text(Object? value) => value?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    final b = widget.business;
    _rewardController = TextEditingController(
      text: _text(b['reward_description'] ?? b['rewardDescription']),
    );
    _rewardLongController = TextEditingController(
      text: _text(b['reward_long_description'] ?? b['rewardLongDescription']),
    );
    _pointsController = TextEditingController(
      text: _text(b['points_required'] ?? b['pointsRequired'] ?? 10),
    );
  }

  @override
  void dispose() {
    _rewardController.dispose();
    _rewardLongController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(businessRepositoryProvider).updateCampaign(
            businessId: widget.business['id'].toString(),
            rewardDescription: _rewardController.text,
            rewardLongDescription: _rewardLongController.text,
            pointsRequired: int.parse(_pointsController.text.trim()),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Campaña actualizada')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          child: Column(
            children: [
              AppPageHeader(
                title: 'Mi campaña',
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
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 8),
                          child: Text(
                            'CAMPAÑA DE PUNTOS',
                            style: AppTypography.label(size: 13, tracking: 5),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 20),
                          child: Text(
                            'Los cambios se aplican desde el próximo escaneo de tus clientes.',
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
