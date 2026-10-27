import {
  NotificationTranslator,
  normalizeLanguage,
  notificationTranslator,
  translateNotification,
} from './notification-translator';
import { NOTIFICATION_PATTERNS_EN, NOTIFICATION_STRINGS_EN } from './notification-strings.en';

const en = (text: string) => notificationTranslator.toEnglish(text);

describe('notificationTranslator', () => {
  describe('avisos reales del servidor', () => {
    // Los textos tal como los escribe cada servicio.
    const cases: Array<[string, string]> = [
      // cuentas y negocios
      ['Nueva Cuenta de Negocio', 'New business account'],
      ['Ana Paz creo cuenta como business.', 'Ana Paz created an account as business.'],
      ['Se creo el negocio Café Aurora por Aurora Zhunio.', 'The business Café Aurora was created by Aurora Zhunio.'],
      ['Se creo el negocio Café Aurora por un usuario.', 'The business Café Aurora was created by a user.'],
      ['¡Tu negocio fue activado!', 'Your business was activated!'],
      [
        'Café Aurora ya está activo en Fidelity. Vuelve a iniciar sesión para empezar.',
        'Café Aurora is now active on Fidelity. Sign in again to get started.',
      ],
      ['Ahora eres aprobador', 'You are now an approver'],
      [
        'Café Aurora te asignó como aprobador. Vuelve a iniciar sesión para ver su panel.',
        'Café Aurora made you an approver. Sign in again to see its panel.',
      ],
      // escaneos y premios
      ['Escaneo por aprobar', 'Scan to approve'],
      [
        'Ana Paz escaneo en Café Aurora. Apruebalo para sumarle el punto.',
        'Ana Paz scanned at Café Aurora. Approve it to add their point.',
      ],
      ['Ana Paz escaneo en Café Aurora.', 'Ana Paz scanned at Café Aurora.'],
      ['Punto aprobado', 'Point approved'],
      ['Tu escaneo en Café Aurora fue aprobado.', 'Your scan at Café Aurora was approved.'],
      ['Tu escaneo en Café Aurora fue rechazado.', 'Your scan at Café Aurora was rejected.'],
      ['Café Aurora te ha otorgado 3 puntos.', 'Café Aurora gave you 3 points.'],
      ['Has ganado premio en Café Aurora, acercate a retirar.', 'You won a prize at Café Aurora, come by to pick it up.'],
      ['Ana Paz gano un premio, pendiente de entrega.', 'Ana Paz won a prize, pending delivery.'],
      ['Un cliente gano un premio, pendiente de entrega.', 'A customer won a prize, pending delivery.'],
      ['Ana Paz alcanzo un premio en Café Aurora.', 'Ana Paz reached a prize at Café Aurora.'],
      ['Tu premio en Café Aurora fue aprobado.', 'Your prize at Café Aurora was approved.'],
      [
        'Ana te regalo un premio de Café Aurora. Entra para ver como retirarlo.',
        'Ana gave you a prize from Café Aurora. Open the app to see how to collect it.',
      ],
      ['Ana transfirio su premio a Luis.', 'Ana transferred their prize to Luis.'],
      ['Ana transfirio un premio a Luis en Café Aurora.', 'Ana transferred a prize to Luis at Café Aurora.'],
      // campañas, gift cards y rutas
      // tarjetas en venta
      ['Café Aurora tiene una tarjeta en venta', 'Café Aurora has a card for sale'],
      ['Café pequeño por $0.25. Cómprala en Explorar.', 'Café pequeño for $0.25. Buy it in Explore.'],
      ['Compra aprobada', 'Purchase approved'],
      [
        'Tu tarjeta de Café Aurora: Café pequeño ya está en Mis regalos. Vale hasta el 23/11/2026.',
        'Your card from Café Aurora: Café pequeño is now in My gifts. Valid until 23/11/2026.',
      ],
      ['Vendiste una tarjeta', 'You sold a card'],
      [
        'Luis Mora compró «Café pequeño» por $0.25. Te tocan $0.22 cuando la canjee.',
        'Luis Mora bought "Café pequeño" for $0.25. You get $0.22 when they redeem it.',
      ],
      ['Comprobante de tarjeta por revisar', 'Card payment proof to review'],
      [
        'Luis Mora pagó $0.25 por «Café pequeño» (TJ-ABC234). Revisa el comprobante.',
        'Luis Mora paid $0.25 for "Café pequeño" (TJ-ABC234). Review the proof.',
      ],
      ['Comprobante no aceptado', 'Payment proof not accepted'],
      [
        'No pudimos validar tu pago de $0.25 (TJ-ABC234): El monto no coincide. Puedes intentarlo de nuevo desde la tarjeta.',
        "We couldn't validate your $0.25 payment (TJ-ABC234): El monto no coincide. You can try again from the card.",
      ],
      ['Te pagamos tus tarjetas canjeadas', 'We paid you for your redeemed cards'],
      [
        'Registramos un pago de $0.44 por 2 tarjetas canjeadas.',
        'We recorded a payment of $0.44 for 2 redeemed cards.',
      ],
      [
        'Registramos un pago de $0.22 por 1 tarjeta canjeada.',
        'We recorded a payment of $0.22 for 1 redeemed card.',
      ],
      // juego semanal
      ['¡Ganaste tu juego de la semana!', 'You won your game of the week!'],
      [
        'Sumaste 1 punto en Café Aurora. La próxima semana juega en otro negocio.',
        'You earned 1 point at Café Aurora. Next week play at another business.',
      ],
      ['¡Completaste tu tarjeta!', 'You completed your card!'],
      ['¡Un cliente ganó un punto jugando!', 'A customer won a point by playing!'],
      [
        'Sumaste 2 puntos en Café Aurora. La próxima semana juega en otro negocio.',
        'You earned 2 points at Café Aurora. Next week play at another business.',
      ],
      [
        'Ana Paz ganó 2 puntos con el juego semanal de Fidelity.',
        'Ana Paz won 2 points with the Fidelity weekly game.',
      ],
      [
        'Ana Paz ganó 1 punto con el juego semanal de Fidelity.',
        'Ana Paz won 1 point with the Fidelity weekly game.',
      ],
      ['Tarjeta canjeada', 'Card redeemed'],
      ['Canjeaste: 20% de descuento. ¡Disfrútalo!', 'You redeemed: 20% off. Enjoy!'],
      ['Café Aurora te regaló una gift card', 'Café Aurora gave you a gift card'],
      ['Café Aurora te regaló una gift card de cumpleaños', 'Café Aurora gave you a birthday gift card'],
      [
        '15% de descuento. Vale solo hoy: ábrela en Mis regalos y muestra su código.',
        '15% off. Valid today only: open it in My gifts and show its code.',
      ],
      [
        '20% de descuento. Ábrela en Mis regalos y muestra su código.',
        '20% off. Open it in My gifts and show its code.',
      ],
      ['¡Completaste la ruta Ruta del sabor!', 'You completed the Ruta del sabor route!'],
      ['Muestra el código RTA-ABC234 para reclamar: Cena para dos.', 'Show code RTA-ABC234 to claim: Cena para dos.'],
      ['Nuevo sello en Ruta del sabor', 'New stamp on Ruta del sabor'],
      ['Llevas 2 de 3 sellos. ¡Sigue la ruta!', 'You have 2 of 3 stamps. Keep following the route!'],
      ['Nueva ruta: Ruta del sabor', 'New route: Ruta del sabor'],
      ['Visita 3 locales y gana: Cena para dos.', 'Visit 3 places and win: Cena para dos.'],
      ['Tu gift card cambió', 'Your gift card changed'],
      ['Actualizamos "Regalo": 25% de descuento.', 'We updated "Regalo": 25% off.'],
      ['Gift card cancelada', 'Gift card cancelled'],
      [
        'El local canceló la gift card "Regalo". Ya no se puede canjear.',
        'The business cancelled the gift card "Regalo". It can no longer be redeemed.',
      ],
      // opiniones, soporte y pagos
      ['Nuevo reclamo de un cliente', 'New complaint from a customer'],
      ['Nueva sugerencia de un cliente', 'New suggestion from a customer'],
      ['Café Aurora respondió tu opinión', 'Café Aurora replied to your feedback'],
      ['Nuevo Ticket de Soporte', 'New support ticket'],
      ['Pago por validar', 'Payment to validate'],
      ['Café Aurora reportó su pago (FID-ABC234).', 'Café Aurora reported their payment (FID-ABC234).'],
      [
        'Café Aurora pagó con tarjeta (FID-ABC234) y su cuenta se activó sola.',
        'Café Aurora paid by card (FID-ABC234) and its account was activated automatically.',
      ],
      ['¡Pago validado!', 'Payment validated!'],
      [
        'Validamos tu pago (comprobante REC-1001). Café Aurora ya está activo.',
        'We validated your payment (receipt REC-1001). Café Aurora is now active.',
      ],
      ['No pudimos validar tu pago', "We couldn't validate your payment"],
      [
        'La foto no se ve. Puedes reportarlo de nuevo desde la app.',
        'La foto no se ve. You can report it again from the app.',
      ],
      // invitar amigos
      ['Luis Mora se unió con tu código', 'Luis Mora joined with your code'],
      [
        'Van 2 de 3 amigos. Cuando se unan 3, ganas 1 punto.',
        'You have 2 of 3 friends. When 3 join, you earn 1 point.',
      ],
      [
        'Van 1 de 3 amigos. Cuando se unan 3, ganas 2 puntos.',
        'You have 1 of 3 friends. When 3 join, you earn 2 points.',
      ],
      ['Van 3 de 3 amigos.', 'You have 3 of 3 friends.'],
      ['Cuando haga su primer escaneo, contará para tu punto.', 'When they make their first scan, it will count toward your point.'],
      ['¡Se unieron 3 amigos!', '3 friends joined!'],
      ['Cuando haga su primer escaneo, los dos ganan puntos de invitación.', 'When they make their first scan, you both earn invitation points.'],
      ['¡Ganaste 1 punto de invitación!', 'You earned 1 invitation point!'],
      ['¡Ganaste 2 puntos de invitación!', 'You earned 2 invitation points!'],
      ['Por tu primer escaneo, invitado por Ana Pérez. Elige en qué local usarlos.', 'For your first scan, invited by Ana Pérez. Choose which business to use them at.'],
      ['¡Luis Mora ya hizo su primer escaneo!', 'Luis Mora already made their first scan!'],
      ['Ganaste 1 punto de invitación. Elige en qué local usarlos.', 'You earned 1 invitation point. Choose which business to use it at.'],
      ['Ganaste 3 puntos de invitación. Elige en qué local usarlos.', 'You earned 3 invitation points. Choose which business to use them at.'],
      ['Puntos de invitación usados', 'Invitation points used'],
      ['Sumaste 1 punto en Café Aurora.', 'You added 1 point at Café Aurora.'],
      ['Sumaste 2 puntos en Café Aurora.', 'You added 2 points at Café Aurora.'],
      // FidelyUsuario
      ['¡Ya eres FidelyUsuario de Café Aurora!', 'You are now a FidelyUsuario at Café Aurora!'],
      ['Nuevo FidelyUsuario', 'New FidelyUsuario'],
      [
        'Ana Pérez ya es FidelyUsuario de Café Aurora: 3 escaneos aprobados.',
        'Ana Pérez is now a FidelyUsuario at Café Aurora: 3 approved scans.',
      ],
      // cumpleaños
      ['Hoy cumple años Ana Pérez', 'Ana Pérez has a birthday today'],
      [
        'Ana Pérez es cliente de Café Aurora. Regálale una gift card para celebrarlo.',
        'Ana Pérez is a customer of Café Aurora. Send them a gift card to celebrate.',
      ],
      // minijuegos
      ['Solicitud de minijuegos', 'Mini-games request'],
      ['Café Aurora pidió los minijuegos.', 'Café Aurora requested the mini-games.'],
      ['¡Minijuegos activados!', 'Mini-games activated!'],
      [
        'Ya puedes mandarle a tus clientes: Tres en raya, Ahorcado, Flappy Bird.',
        'You can now send your customers: Tic-tac-toe, Hangman, Flappy Bird.',
      ],
      [
        'No pudimos activar los minijuegos: Falta validar tu pago.',
        "We couldn't activate the mini-games: Falta validar tu pago.",
      ],
      ['Café Aurora te reta a jugar', 'Café Aurora challenges you to play'],
      [
        'Juega Ahorcado y gana: 20% de descuento. Tienes 3 intentos hasta el 28/10, 15:00.',
        'Play Hangman and win: 20% off. You have 3 tries until 28/10, 15:00.',
      ],
      ['Juega Flappy Bird. Tienes 3 intentos hasta el 28/10, 15:00.', 'Play Flappy Bird. You have 3 tries until 28/10, 15:00.'],
      ['¡Ganaste!', 'You won!'],
      [
        'Ganaste Ahorcado y tu premio es: 20% de descuento. Ábrelo en Mis regalos.',
        'You won Hangman and your prize is: 20% off. Open it in My gifts.',
      ],
      ['¡Un cliente ganó!', 'A customer won!'],
      ['Ana Paz ganó Ahorcado.', 'Ana Paz won Hangman.'],
    ];

    it.each(cases)('%s', (spanish, english) => {
      expect(en(spanish)).toBe(english);
    });
  });

  describe('reglas', () => {
    it('lo que escribió una persona pasa tal cual', () => {
      expect(en('Se creo el negocio El Rincón de María por Mateo Ñ.')).toBe(
        'The business El Rincón de María was created by Mateo Ñ.',
      );
      expect(en('Ticket: no me llega el código')).toBe('Ticket: no me llega el código');
    });

    it('un texto sin traducción se queda en español, sin fallar', () => {
      expect(en('Un aviso que nadie tradujo')).toBe('Un aviso que nadie tradujo');
      expect(en('')).toBe('');
      expect(en('   ')).toBe('   ');
    });

    it('las plantillas más específicas ganan', () => {
      expect(en('Ana escaneo en Café. Apruebalo para sumarle el punto.')).toBe(
        'Ana scanned at Café. Approve it to add their point.',
      );
    });

    it('traduce cada línea de un texto de varias líneas', () => {
      expect(en('Pago por validar\n¡Pago validado!')).toBe('Payment to validate\nPayment validated!');
    });

    it('una plantilla puede reordenar sus datos con {1} y {2}', () => {
      const t = new NotificationTranslator({}, { '{} le escribió a {}': '{2} got a message from {1}' });
      expect(t.toEnglish('Ana le escribió a Luis')).toBe('Luis got a message from Ana');
    });

    it('los caracteres especiales de una clave no rompen la plantilla', () => {
      const t = new NotificationTranslator({}, { '¿Qué tal ({})? (+1) [ok] $5.': 'How are you ({})?' });
      expect(t.toEnglish('¿Qué tal (Ana)? (+1) [ok] $5.')).toBe('How are you (Ana)?');
    });
  });

  describe('por idioma', () => {
    it('en español el texto no cambia', () => {
      expect(translateNotification('Punto aprobado', 'es')).toBe('Punto aprobado');
      expect(translateNotification('Punto aprobado', undefined)).toBe('Punto aprobado');
      expect(translateNotification('Punto aprobado', null)).toBe('Punto aprobado');
    });

    it('en inglés se traduce', () => {
      expect(translateNotification('Punto aprobado', 'en')).toBe('Point approved');
    });

    it('un idioma desconocido se trata como español', () => {
      expect(translateNotification('Punto aprobado', 'fr')).toBe('Punto aprobado');
      expect(normalizeLanguage('fr')).toBe('es');
      expect(normalizeLanguage('en')).toBe('en');
      expect(normalizeLanguage(null)).toBe('es');
    });
  });

  describe('el diccionario', () => {
    it('ninguna traducción está vacía', () => {
      for (const [k, v] of [...Object.entries(NOTIFICATION_STRINGS_EN), ...Object.entries(NOTIFICATION_PATTERNS_EN)]) {
        expect(v.trim().length).toBeGreaterThan(0);
        expect(k.trim().length).toBeGreaterThan(0);
      }
    });

    it('cada plantilla usa tantos datos como su traducción', () => {
      for (const [source, target] of Object.entries(NOTIFICATION_PATTERNS_EN)) {
        const inSource = source.split('{}').length - 1;
        const inTarget = (target.match(/\{\d*\}/g) ?? []).length;
        expect({ source, inTarget }).toEqual({ source, inTarget: inSource });
      }
    });
  });
});
