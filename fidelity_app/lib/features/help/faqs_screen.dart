import 'package:flutter/material.dart';

import 'faq_list_screen.dart';

/// Preguntas frecuentes para clientes.
class FaqsScreen extends StatelessWidget {
  const FaqsScreen({super.key});

  static const List<FaqItem> _faqs = [
    FaqItem(
      icon: Icons.card_membership_rounded,
      question: '¿Qué es una tarjeta de fidelidad?',
      answer:
          'Cada tarjeta representa un negocio afiliado a Fidelity. Acumulas puntos en ese negocio escaneando su código QR y, cuando completas la tarjeta, ganas el premio que ese local te ofrece.',
    ),
    FaqItem(
      icon: Icons.qr_code_scanner_rounded,
      question: '¿Cómo gano puntos?',
      answer:
          'Toca ESCANEAR en tu pantalla principal y apunta la cámara al código QR del negocio. Tu escaneo queda pendiente hasta que el local lo apruebe; en ese momento se suma 1 punto a tu tarjeta y te avisamos.',
    ),
    FaqItem(
      icon: Icons.show_chart_rounded,
      question: '¿Cómo veo mi progreso?',
      answer:
          'En Inicio, cada tarjeta muestra tus puntos y la meta, por ejemplo 6/10. Si ves la etiqueta PENDIENTE, el local aún no aprueba tu último escaneo.',
    ),
    FaqItem(
      icon: Icons.card_giftcard_rounded,
      question: '¿Cómo reclamo mi premio?',
      answer:
          'Cuando completas la tarjeta ganas un premio: aparece en la pestaña PREMIOS de esa tarjeta como "Por reclamar". Acércate al local y muéstralo; el negocio lo marcará como entregado. Mientras tengas un premio por reclamar no puedes seguir sumando puntos en ese negocio.',
    ),
    FaqItem(
      icon: Icons.swap_horiz_rounded,
      question: '¿Puedo transferir un premio a otra persona?',
      answer:
          'Sí, mientras no lo hayas reclamado. En la pestaña PREMIOS toca "Transferir a un amigo" e ingresa el correo de alguien registrado en Fidelity. El premio pasará a su cuenta.',
    ),
    FaqItem(
      icon: Icons.access_time_rounded,
      question: '¿Por qué no puedo escanear el mismo QR dos veces seguidas?',
      answer:
          'Cada negocio define un tiempo de espera entre escaneos (por defecto 4 horas) y solo puedes tener un escaneo pendiente a la vez en cada local. Esto evita acumulaciones sin una compra real. Mientras tanto puedes escanear en otros locales.',
    ),
    FaqItem(
      icon: Icons.lock_reset_rounded,
      question: '¿Cómo cambio mi contraseña?',
      answer:
          'En Mi perfil toca "Cambiar contraseña", ingresa la actual y la nueva (mínimo 6 caracteres). Tu correo no se puede modificar.',
    ),
    FaqItem(
      icon: Icons.delete_outline_rounded,
      question: '¿Cómo elimino mi cuenta?',
      answer:
          'Desde Mi perfil toca "Eliminar mi cuenta". La acción es irreversible: borramos todos tus datos personales conforme a la política de privacidad.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const FaqListScreen(
      bannerTitle: 'Manual de uso',
      bannerSubtitle: 'Todo lo que necesitas saber para ganar premios con Fidelity.',
      items: _faqs,
    );
  }
}
