import 'package:flutter/material.dart' hide Text;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/whatsapp_launcher.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_responsive_body.dart';
import '../../core/l10n/tr_text.dart';

class FaqItem {
  final IconData icon;
  final String question;
  final String answer;

  /// Acción opcional debajo de la respuesta (p. ej. "Eliminar mi cuenta").
  final Widget Function(BuildContext context)? action;

  const FaqItem({
    required this.icon,
    required this.question,
    required this.answer,
    this.action,
  });
}

/// Pantalla de preguntas frecuentes con el estilo de marca. La comparten la
/// versión de clientes y la de negocios: solo cambian el banner y las preguntas.
class FaqListScreen extends StatelessWidget {
  final String bannerTitle;
  final String bannerSubtitle;
  final List<FaqItem> items;

  /// Mensaje que se precarga en WhatsApp al pedir ayuda.
  final String supportMessage;

  const FaqListScreen({
    super.key,
    required this.bannerTitle,
    required this.bannerSubtitle,
    required this.items,
    this.supportMessage = 'Hola, tengo una pregunta sobre Fidelity.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppResponsiveBody(
          child: Column(
            children: [
              const AppPageHeader(title: 'Preguntas frecuentes'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  children: [
                    AppCard(
                      color: AppColors.pink,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bannerTitle.toUpperCase(), style: AppTypography.display(size: 26)),
                          const SizedBox(height: 4),
                          Text(
                            bannerSubtitle,
                            style: AppTypography.body(size: 15, weight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final item in items) ...[
                      _FaqCard(item: item),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                    AppCard(
                      onTap: () => openSupportWhatsApp(supportMessage),
                      child: Row(
                        children: [
                          const Icon(Icons.support_agent_rounded, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '¿Tienes otra pregunta? Escríbenos por WhatsApp y te ayudamos en el momento.',
                              style: AppTypography.body(size: 15, weight: FontWeight.w300),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 28),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  final FaqItem item;

  const _FaqCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      radius: 28,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: AppColors.black,
          collapsedIconColor: AppColors.black,
          leading: Icon(item.icon, color: AppColors.black, size: 26),
          title: Text(
            item.question,
            style: AppTypography.body(size: 16, weight: FontWeight.w500),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.answer,
                style: AppTypography.body(size: 15, weight: FontWeight.w300),
              ),
            ),
            if (item.action != null) ...[
              const SizedBox(height: 16),
              item.action!(context),
            ],
          ],
        ),
      ),
    );
  }
}
