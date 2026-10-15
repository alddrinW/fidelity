import 'package:flutter/material.dart' hide Text;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_choice_option.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import 'register_screen.dart';
import '../../core/l10n/tr_text.dart';

/// Primer paso del registro: elegir entre cuenta de usuario o de negocio.
class RegisterChoiceScreen extends StatefulWidget {
  const RegisterChoiceScreen({super.key});

  @override
  State<RegisterChoiceScreen> createState() => _RegisterChoiceScreenState();
}

class _RegisterChoiceScreenState extends State<RegisterChoiceScreen> {
  /// Valores que entiende el backend (`UserRole`): 'client' o 'business'.
  String? _role;

  void _continue() {
    final role = _role;
    if (role == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegisterScreen(role: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          child: Column(
            children: [
              const AppPageHeader(title: 'Registro'),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppChoiceOption(
                          icon: Icons.account_circle_outlined,
                          label: 'Usuario',
                          selected: _role == 'client',
                          onTap: () => setState(() => _role = 'client'),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Ó',
                            style: AppTypography.label(size: 18, tracking: 0),
                          ),
                        ),
                        AppChoiceOption(
                          icon: Icons.storefront_outlined,
                          label: 'Negocio',
                          selected: _role == 'business',
                          onTap: () => setState(() => _role = 'business'),
                        ),
                      ]
                          .animate(interval: 100.ms)
                          .fadeIn()
                          .slideY(begin: 0.1),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 32, 32),
                  child: AppCircleButton(
                    onPressed: _role == null ? null : _continue,
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
