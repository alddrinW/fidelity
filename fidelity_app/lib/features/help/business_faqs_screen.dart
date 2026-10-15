import 'package:flutter/material.dart';

import 'faq_list_screen.dart';

/// Preguntas frecuentes para negocios.
class BusinessFaqsScreen extends StatelessWidget {
  const BusinessFaqsScreen({super.key});

  static const List<FaqItem> _faqs = [
    FaqItem(
      icon: Icons.storefront_outlined,
      question: '¿Cómo activo mi negocio?',
      answer:
          'Al crear tu negocio, Fidelity lo revisa y lo activa. Si ves el aviso de cuenta inactiva, escríbenos por WhatsApp desde ese mismo aviso y lo activamos. Una vez activo, tu código QR queda disponible para que tus clientes lo escaneen.',
    ),
    FaqItem(
      icon: Icons.qr_code_2_rounded,
      question: '¿Cómo comparto o imprimo mi código QR?',
      answer:
          'En la pestaña QR toca tu código. Desde ahí puedes descargarlo como IMAGEN (en el teléfono se guarda en la galería) o como PDF listo para imprimir y pegar en tu local. El QR solo lo leen los clientes desde la app de Fidelity, con el botón ESCANEAR.',
    ),
    FaqItem(
      icon: Icons.how_to_vote_outlined,
      question: '¿Cómo funciona el sistema de puntos?',
      answer:
          'Cada cliente escanea tu QR y el escaneo queda en PENDIENTES. Tú lo apruebas y recién ahí el cliente recibe 1 punto. Cuando acumula los puntos necesarios se genera automáticamente un premio que debes entregar.',
    ),
    FaqItem(
      icon: Icons.add_circle_outline_rounded,
      question: '¿Puedo darle puntos manualmente a un cliente?',
      answer:
          'Sí. En la pestaña CLIENTES toca el botón + de la tarjeta del cliente e indica cuántos puntos sumar. Queda registrado como un punto de regalo en su historial.',
    ),
    FaqItem(
      icon: Icons.lock_outline_rounded,
      question: '¿Por qué no puedo darle puntos a un cliente?',
      answer:
          'Si un cliente tiene un premio pendiente en tu negocio no se le pueden sumar más puntos hasta que se lo entregues. En su tarjeta verás un candado en lugar del botón +.',
    ),
    FaqItem(
      icon: Icons.card_giftcard_rounded,
      question: '¿Cómo entrego un premio?',
      answer:
          'Cuando un cliente completa su tarjeta, su premio aparece en la pestaña PREMIOS como "Por entregar". Entrégalo en persona y toca ENTREGAR. Después de eso el cliente puede volver a acumular puntos.',
    ),
    FaqItem(
      icon: Icons.block_rounded,
      question: '¿Qué pasa si rechazo un escaneo?',
      answer:
          'El cliente no recibe el punto y el escaneo queda marcado como rechazado. Úsalo cuando no hubo una compra real. El cliente deberá esperar el tiempo de espera de tu local antes de volver a escanear.',
    ),
    FaqItem(
      icon: Icons.access_time_rounded,
      question: '¿Qué es el tiempo de espera entre escaneos?',
      answer:
          'Es el tiempo mínimo entre dos escaneos del mismo cliente en tu local, para evitar que sume puntos sin comprar. Por defecto son 4 horas. Si necesitas otro valor, escríbenos por WhatsApp. Además, cada cliente solo puede tener un escaneo pendiente a la vez.',
    ),
    FaqItem(
      icon: Icons.bar_chart_rounded,
      question: '¿Cómo veo las estadísticas de mi negocio?',
      answer:
          'En la pestaña MÉTRICAS ves cuántos clientes te visitan, los puntos otorgados, los premios ganados y el requisito de puntos. Toca cada tarjeta para ver el detalle por cliente.',
    ),
    FaqItem(
      icon: Icons.people_outline_rounded,
      question: '¿Cómo veo el progreso de mis clientes?',
      answer:
          'En la pestaña CLIENTES, cada tarjeta muestra los puntos actuales frente a la meta, los puntos en total y los premios ganados. Puedes buscar por nombre.',
    ),
    FaqItem(
      icon: Icons.edit_outlined,
      question: '¿Puedo cambiar la cantidad de puntos necesarios?',
      answer:
          'Sí. Toca el logo de tu negocio, entra a "Ajustar mi campaña" y cambia los puntos, el premio y su descripción. También puedes tocar REQUISITO en MÉTRICAS. Los cambios aplican desde el próximo escaneo de tus clientes.',
    ),
    FaqItem(
      icon: Icons.delete_outline_rounded,
      question: '¿Cómo elimino mi cuenta de negocio?',
      answer:
          'Toca el logo de tu negocio, entra a "Ajustar mis datos" y al final elige "Eliminar mi cuenta". Deberás escribir ELIMINAR para confirmar. La acción es irreversible y borra los datos de tu negocio.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const FaqListScreen(
      bannerTitle: 'Guía para negocios',
      bannerSubtitle: 'Todo para gestionar tus clientes, escaneos y premios.',
      supportMessage: 'Hola, tengo una pregunta sobre mi negocio en Fidelity.',
      items: _faqs,
    );
  }
}
