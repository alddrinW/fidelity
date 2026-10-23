/**
 * Diccionario español -> inglés de los avisos que escribe el servidor.
 *
 * Las claves son el texto EXACTO que genera el servidor. Los textos con datos
 * usan `{}` (y `{1}`, `{2}` para reordenar en la traducción).
 *
 * Si agregas un aviso nuevo en el servidor, agrega aquí su traducción (el test
 * `notification-translator.spec.ts` revisa los avisos más comunes).
 */

export const NOTIFICATION_STRINGS_EN: Record<string, string> = {
  // Cuentas y negocios
  'Nueva Cuenta de Negocio': 'New business account',
  'Nuevo Cliente': 'New customer',
  'Ahora eres aprobador': 'You are now an approver',
  'Nuevo Negocio Registrado': 'New business registered',
  '¡Tu negocio fue activado!': 'Your business was activated!',
  'un usuario': 'a user',
  'Un usuario': 'A user',
  'Un cliente': 'A customer',
  'Un local': 'A business',
  'Un negocio': 'A business',
  'Tu negocio': 'Your business',
  'Tu local': 'Your business',

  // Escaneos, puntos y premios
  'Escaneo por aprobar': 'Scan to approve',
  'Nuevo Escaneo': 'New scan',
  'Punto aprobado': 'Point approved',
  'Punto asignado manualmente': 'Point assigned manually',
  'Escaneo rechazado': 'Scan rejected',
  'Premio alcanzado': 'Prize reached',
  'Premio Alcanzado': 'Prize reached',
  'Premio solicitado': 'Prize requested',
  'Premio entregado': 'Prize delivered',
  'Premio rechazado': 'Prize rejected',
  'Te han transferido un premio': 'A prize was transferred to you',
  'Transferencia de premio': 'Prize transfer',
  'Premio Transferido': 'Prize transferred',

  // Campañas, gift cards y rutas
  'Tarjeta canjeada': 'Card redeemed',
  'Tu gift card cambió': 'Your gift card changed',
  'Gift card cancelada': 'Gift card cancelled',
  'revisa los detalles': 'check the details',

  // Opiniones y soporte
  'Un cliente calificó tu atención.': 'A customer rated your service.',
  'Nuevo reclamo de un cliente': 'New complaint from a customer',
  'Nueva sugerencia de un cliente': 'New suggestion from a customer',
  'Nueva felicitación de un cliente': 'New praise from a customer',
  'Nuevo reclamo': 'New complaint',
  'Nueva sugerencia': 'New suggestion',
  'Nueva felicitación': 'New praise',
  'Nuevo Ticket de Soporte': 'New support ticket',

  // Pagos
  'Pago por validar': 'Payment to validate',
  'Negocio activado con tarjeta': 'Business activated by card',
  '¡Pago validado!': 'Payment validated!',
  'No pudimos validar tu pago': "We couldn't validate your payment",

  // Minijuegos
  'Solicitud de minijuegos': 'Mini-games request',
  '¡Minijuegos activados!': 'Mini-games activated!',
  'Tus minijuegos cambiaron': 'Your mini-games changed',
  '¡Ganaste!': 'You won!',
  '¡Un cliente ganó!': 'A customer won!',
  'Tres en raya': 'Tic-tac-toe',
  Ahorcado: 'Hangman',
  'Flappy Bird': 'Flappy Bird',
};

export const NOTIFICATION_PATTERNS_EN: Record<string, string> = {
  // FidelyUsuario
  '¡Ya eres FidelyUsuario de {}!': 'You are now a FidelyUsuario at {}!',
  'Por tu fidelidad a {} tienes la insignia FidelyUsuario. ¡Gracias por volver!':
    'For your loyalty to {} you have the FidelyUsuario badge. Thanks for coming back!',
  'Nuevo FidelyUsuario': 'New FidelyUsuario',
  '{} ya es FidelyUsuario de {}: {} escaneos aprobados.': '{1} is now a FidelyUsuario at {2}: {3} approved scans.',

  // Cumpleaños
  'Hoy cumple años {}': '{} has a birthday today',
  '{} es cliente de {}. Regálale una gift card para celebrarlo.':
    '{1} is a customer of {2}. Send them a gift card to celebrate.',

  // Cuentas y negocios
  '{} creo cuenta como {}.': '{} created an account as {}.',
  '{} te asignó como aprobador. Vuelve a iniciar sesión para ver su panel.':
    '{} made you an approver. Sign in again to see its panel.',
  'Se creo el negocio {} por {}.': 'The business {} was created by {}.',
  '{} ya está activo en Fidelity. Vuelve a iniciar sesión para empezar.':
    '{} is now active on Fidelity. Sign in again to get started.',

  // Escaneos, puntos y premios
  '{} escaneo en {}. Apruebalo para sumarle el punto.': '{} scanned at {}. Approve it to add their point.',
  '{} escaneo en {}.': '{} scanned at {}.',
  'Tu escaneo en {} fue aprobado.': 'Your scan at {} was approved.',
  'Tu escaneo en {} fue rechazado.': 'Your scan at {} was rejected.',
  '{} te ha otorgado {} puntos.': '{} gave you {} points.',
  'Has ganado premio en {}, acercate a retirar.': 'You won a prize at {}, come by to pick it up.',
  '{} gano un premio, pendiente de entrega.': '{} won a prize, pending delivery.',
  '{} alcanzo un premio en {}.': '{} reached a prize at {}.',
  'Tu premio en {} fue aprobado.': 'Your prize at {} was approved.',
  'Tu premio en {} fue rechazado.': 'Your prize at {} was rejected.',
  '{} te regalo un premio de {}. Entra para ver como retirarlo.':
    '{} gave you a prize from {}. Open the app to see how to collect it.',
  '{} transfirio su premio a {}.': '{} transferred their prize to {}.',
  '{} transfirio un premio a {} en {}.': '{} transferred a prize to {} at {}.',

  // Campañas, gift cards y rutas
  'Canjeaste: {}. ¡Disfrútalo!': 'You redeemed: {}. Enjoy!',
  '¡Completaste la ruta {}!': 'You completed the {} route!',
  'Muestra el código {} para reclamar: {}.': 'Show code {} to claim: {}.',
  'Nuevo sello en {}': 'New stamp on {}',
  'Llevas {} de {} sellos. ¡Sigue la ruta!': 'You have {} of {} stamps. Keep following the route!',
  '{} te regaló una gift card': '{} gave you a gift card',
  '{} te regaló una gift card de cumpleaños': '{} gave you a birthday gift card',
  '{}. Vale solo hoy: ábrela en Mis regalos y muestra su código.':
    '{}. Valid today only: open it in My gifts and show its code.',
  '{}. Ábrela en Mis regalos y muestra su código.': '{}. Open it in My gifts and show its code.',
  'Nueva ruta: {}': 'New route: {}',
  'Nuevo reto: {}': 'New challenge: {}',
  'Haz {} escaneos en {} y gana: {}.': 'Make {} scans at {} and win: {}.',
  'Reto: {}': 'Challenge: {}',
  'Llevas {} de {} escaneos. ¡Sigue así!': 'You have {} of {} scans. Keep it up!',
  '¡Completaste el reto {}!': 'You completed the {} challenge!',
  'Tu premio: {}. Ábrelo en Mis regalos.': 'Your prize: {}. Open it in My gifts.',
  'Visita {} locales y gana: {}.': 'Visit {} places and win: {}.',
  'Novedades de {}': 'News from {}',
  'Actualizamos "{}": {}.': 'We updated "{}": {}.',
  'El local canceló la gift card "{}". Ya no se puede canjear.':
    'The business cancelled the gift card "{}". It can no longer be redeemed.',
  '{}% de descuento': '{}% off',

  // Opiniones y soporte
  '{} respondió tu opinión': '{} replied to your feedback',
  '{}: Un cliente calificó tu atención.': '{}: A customer rated your service.',
  'Ticket: {}': 'Ticket: {}',

  // Pagos
  '{} reportó su pago ({}).': '{} reported their payment ({}).',
  '{} pagó con tarjeta ({}) y su cuenta se activó sola.':
    '{} paid by card ({}) and its account was activated automatically.',
  'Validamos tu pago (comprobante {}). {} ya está activo.':
    'We validated your payment (receipt {}). {} is now active.',
  '{} Puedes reportarlo de nuevo desde la app.': '{} You can report it again from the app.',

  // Minijuegos
  '{} pidió los minijuegos.': '{} requested the mini-games.',
  'Ya puedes mandarle a tus clientes: {}.': 'You can now send your customers: {}.',
  'No pudimos activar los minijuegos: {}': "We couldn't activate the mini-games: {}",
  '{} te reta a jugar': '{} challenges you to play',
  'Juega {} y gana: {}. Tienes {} intentos hasta el {}.': 'Play {} and win: {}. You have {} tries until {}.',
  'Juega {}. Tienes {} intentos hasta el {}.': 'Play {}. You have {} tries until {}.',
  'Ganaste {} y tu premio es: {}. Ábrelo en Mis regalos.':
    'You won {} and your prize is: {}. Open it in My gifts.',
  '{} ganó {}.': '{} won {}.',
};
