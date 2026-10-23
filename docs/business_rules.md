# ⚖️ Reglas de Negocio Críticas

Este documento detalla las reglas que gobiernan el comportamiento de Fidelity. Muchas de estas reglas están implementadas a nivel de base de datos para máxima seguridad.

## 1. El Ciclo de Recompensa (Puntos ➔ Premios)
-   Cada negocio define sus propios `points_required` (ej: 10 puntos para un café gratis).
-   **Automatización**: Cuando `current_points` llega al límite, el sistema:
    1.  Crea un registro en la tabla `rewards` con estado `pending`.
    2.  Resetea `current_points` a 0.
    3.  Incrementa `rewards_claimed` en el historial de la tarjeta.
-   **Bloqueo de Seguridad**: Un usuario con un premio **pendiente** no puede recibir más puntos de ese negocio hasta que el premio sea marcado como canjeado. Esto evita "acumulación infinita" sin control del local.

## 2. Restricción de Tiempo (Cooldown)
-   Para evitar fraudes, un cliente solo puede realizar un escaneo exitoso cada **X horas** (por defecto 4 horas).
-   Esta validación se hace comparando el `last_scan_at` de la `loyalty_card` (se marca en el momento de escanear, aunque el escaneo aún esté pendiente) con la hora actual.
-   Además, un cliente no puede tener más de un escaneo **pendiente** de aprobación por negocio.
-   Si el cliente intenta escanear antes, el sistema devuelve un error claro indicando cuánto tiempo falta.

## 3. Puntos Manuales vs. Escaneos QR
-   **QR**: El cliente escanea el código del local. El sistema valida cooldown, que no haya un escaneo pendiente y que no haya un premio pendiente, y deja el escaneo en estado `pending`. **El punto se suma cuando el negocio lo aprueba**; si lo rechaza, no se suma.
-   **Manual**: El dueño del negocio puede usar la función `add_manual_points` desde su dashboard. Esto genera automáticamente registros de "escaneos aprobados" en el historial para mantener la trazabilidad de la auditoría.

## 4. Sistema de Notificaciones Push (FCM)
-   **Captura de Token**: Cada vez que un usuario inicia sesión, la app captura su `fcm_token` y lo guarda en su perfil.
-   **Lógica de Envío**: Cuando un premio es generado o un punto es aprobado, una Edge Function de Supabase (o un trigger) dispara una notificación al dispositivo del usuario.

## 5. Activación de negocios (PAGA YA)
-   El registro de un negocio **tiene costo** (lo fija el administrador desde *Admin → Ajustes → Precios* o *Pagos → Precios del registro*; `REGISTRATION_FEE` y `BRANCH_FEE` solo son el valor inicial mientras no los cambie). Al crearse, el negocio queda **inactivo** (`is_active = false`) sin importar lo que envíe la app, y se genera su **orden de pago** con una referencia única (`FID-XXXXXX`).
-   Mientras está inactivo, su dueño ve la pantalla **"Activa tu cuenta"** con el botón **PAGA YA**, y sus QR no se pueden escanear.
-   **PAGA YA** es un asistente guiado por Fido en tres pasos: (1) plan y costo, (2) **elegir cómo pagar** y (3) confirmar. Se paga dentro de la app, sin pedir los datos por WhatsApp ni correo:
    -   **Transferencia bancaria:** la app muestra la cuenta (banco, número, tipo, beneficiario y CI/RUC, cada dato con botón de copiar), el monto y la referencia del pago. Después el dueño **sube la foto del comprobante** (obligatoria) y, si quiere, el número de transacción.
    -   **Tarjeta débito/crédito (PayPhone):** la app lleva a la página de pago de PayPhone y el cliente vuelve a la app. El servidor **confirma el cobro directamente con PayPhone** (monto y transacción deben coincidir con la orden); el dueño no puede marcarlo como pagado a mano. Con el cobro aprobado **el pago se valida solo y la cuenta se activa sola** (sin administrador; el comprobante lleva los datos de PayPhone). La app nunca recibe ni guarda datos de la tarjeta.
    -   **Precios:** los fija el **administrador** desde *Pagos → Precios del registro* (registro de negocio y alta de sucursal). Un cambio vale para las órdenes nuevas; las ya emitidas conservan su monto. Sin precios guardados se usan `REGISTRATION_FEE` y `BRANCH_FEE` del servidor.
    -   **Cuentas bancarias:** las fija el **administrador** desde *Pagos → Cuentas bancarias* (hasta 5: banco, número, tipo, titular y cédula/RUC). Sin cuentas guardadas se usa `BANK_ACCOUNTS` del servidor; si el administrador guarda una lista vacía, solo queda el pago con tarjeta.
    -   La tarjeta se configura en el servidor porque son claves secretas (`PAYPHONE_TOKEN`, `PUBLIC_API_URL`; `PAYPHONE_STORE_ID` es opcional). El dominio de `PUBLIC_API_URL` debe ser el "Dominio web" de la app en PayPhone. Si un método no está configurado, la app no lo ofrece. Una **transferencia** sí la valida el administrador con la foto del comprobante.
-   Estados del pago: `pending` (orden creada) → `reported` (el dueño avisó) → `paid` (validado) o `rejected` (con motivo; el dueño puede reportarlo de nuevo).
-   Al abrir un pago (*Panel admin → Pagos → tocar el pago*), el administrador ve el **detalle completo**: la foto del comprobante (ampliable), los datos del pago, **toda la información del negocio** (logo, categoría, estado, descripción, teléfono, cédula/RUC, dirección con enlace al mapa, premio y puntos, fecha de registro) y los datos del **dueño** (nombre, correo, teléfono), cada dato con botón de copiar. Desde ahí valida o rechaza.
-   El **administrador valida** desde *Panel admin → Pagos*: al validar se activa la cuenta, se emite el **comprobante digital** (`FID-R-AAAAMMDD-XXXXXX`) y el dueño recibe una notificación. Activar manualmente un negocio desde *Negocios* equivale a confirmar el pago y también emite el comprobante.
-   El dueño consulta sus pagos y comprobantes en *Mi negocio → Mis pagos y comprobantes*.
-   Los negocios anteriores a esta regla conservan su estado.

## 6. Sugerencias y reclamos (buzón de Fido)
-   Un cliente solo puede opinar de un local **donde ya escaneó al menos una vez**. El botón aparece al terminar un escaneo ("Califica la atención") y en el historial de cada tarjeta ("Sugerencia o reclamo").
-   La opinión lleva una **calificación rápida** (1 mal, 2 regular, 3 excelente), **etiquetas de motivo** (hasta 5) y un comentario. Un reclamo o una sugerencia exigen comentario (mínimo 5 caracteres); una felicitación puede ir solo con la calificación.
-   Tipo: calificación 1 = **reclamo**; con comentario = **sugerencia**; solo calificación buena = **felicitación** (nace resuelta).
-   **Destino:** las sugerencias y reclamos llegan al **administrador** (Panel admin → Sugerencias y reclamos) y al **dueño** del negocio (Mi negocio → Opiniones de clientes). Ambos reciben una notificación. Las felicitaciones solo avisan al dueño.
-   Quien gestiona el caso lo marca como **resuelto** y puede dejar una respuesta; el cliente la ve en *Perfil → Mis sugerencias y reclamos* y recibe una notificación.
-   Límite anti-spam: 3 opiniones por cliente y local cada 24 horas.

## 7. Varios negocios y sucursales
-   Un dueño puede tener **varios negocios**. Una **sucursal** es un negocio que cuelga de un negocio principal del mismo dueño (`parent_id`); una sucursal no puede tener sucursales propias.
-   Cada sucursal se registra como un negocio nuevo: **nace inactiva**, tiene su propia orden de pago con el precio de sucursal (`BRANCH_FEE`) y se activa al validarse el pago (ver sección 5). El formulario de sucursal parte de los datos del negocio principal.
-   *Mis negocios* (icono de tienda en el panel) es la **matriz de control**: por cada negocio y sucursal muestra estado, clientes, escaneos de hoy, escaneos pendientes y tamaño del equipo. Desde ahí se cambia de negocio, se paga una sucursal pendiente, se agregan sucursales y se gestiona el equipo.
-   El negocio con el que se trabaja es el **negocio actual**; se conserva entre sesiones y, al iniciar sesión, se prefiere un negocio activo.

## 8. Rol Aprobador (equipo del negocio)
-   El **dueño** asigna el rol *Aprobador* a una persona ya registrada, por su correo (*Mi negocio → Mi equipo*). La persona pasa a usar la app como aprobador de ese local (hasta 10 aprobadores por negocio). Solo se puede asignar a cuentas de cliente; no a dueños ni administradores.
-   Un **aprobador puede**: ver y aprobar/rechazar escaneos pendientes, validar la entrega de premios y atender (responder y resolver) las opiniones de los clientes. Recibe las mismas notificaciones de escaneos y premios que el dueño.
-   Un aprobador **no puede**: editar el negocio, ver pagos, QR, clientes o estadísticas, dar puntos manuales ni gestionar el equipo.
-   Al quitar a un aprobador de su último negocio, su cuenta vuelve a ser de cliente.

## 9. Campañas (programables, tarjetas de regalo, rutas y eventos)
-   El dueño crea campañas desde la pestaña **Campañas** de su panel, para uno o varios de sus negocios activos (sucursales participantes). Hay cuatro tipos:
    -   **Evento:** un anuncio o novedad para los clientes fidelizados (sin cupón).
    -   **Tarjeta de regalo:** un **descuento** (1–100 %) o un **mini premio**. Se entrega sola a los clientes (ver sección 9a); el local canjea el código con QR.
    -   **Ruta (pasaporte):** el cliente junta **sellos** visitando los locales de la ruta (mínimo 2). Un local da su sello cuando se **aprueba un escaneo real de QR** del cliente mientras la ruta está vigente (los puntos regalados a mano no cuentan, y cada local da un solo sello). Al juntar los sellos requeridos, el cliente recibe un **premio con código** para canjear.
-   **Programación:** una campaña puede lanzarse ya o programarse con fecha y hora de inicio, y tener fecha de fin opcional. Estados: *Programada → Activa → Finalizada* (o *Cancelada*). Un programador interno revisa cada minuto y avisa a los clientes cuando llega la hora de inicio (si el servidor estuvo apagado, avisa al volver).
-   **Quién la recibe:** los clientes con tarjeta en alguno de los negocios participantes. Reciben una notificación al empezar la campaña y la ven en **Novedades** (arriba de su pantalla de inicio). Las tarjetas y premios quedan en *Perfil → Mis regalos*.
-   **Canje:** el dueño y los aprobadores canjean el código en la pestaña *Campañas* (dueño) o *Canjear* (aprobador). Un código no se canjea dos veces ni cuando la campaña ya terminó o fue cancelada.
    -   **Reto de escaneos:** el dueño pide un número de escaneos (de **2 a 100**) y un premio (descuento o mini premio). El cliente gana el premio **automáticamente**, como una gift card con su código `RTO-…`, cuando llega a ese número de escaneos **reales de un QR, aprobados, en los locales del reto mientras la campaña está vigente** (los puntos regalados a mano no cuentan). El cliente recibe un aviso con su avance en cada escaneo y otro al completarlo; ve cuánto lleva en el detalle de la campaña (Explorar → Novedades). El premio se canjea como cualquier gift card.
-   Solo se crean campañas para negocios propios y **activos**.

## 9a. Gift cards del dueño
-   Desde *Gift cards* en su panel, el dueño crea un **descuento** (1–100 %) o un **mini premio**, con título, descripción e imagen opcionales, y la dirige a **todos sus clientes** o a **clientes elegidos** (los que tienen tarjeta en ese negocio). Puede enviarla ya o programarla con fecha de inicio y de vencimiento opcional.
-   **Entrega automática:** al empezar la gift card, a cada cliente destinatario le llega **su propia gift card** con un código `GFT-…` y su QR, en *Perfil → Mis regalos*, más una notificación. El cliente no tiene que reclamarla. Si el cliente ya recibió esa gift card, no se duplica.
-   **Canje:** el dueño y los aprobadores escanean el QR (o escriben el código) del cliente. Un código se canjea **una sola vez** y no se canjea si la gift card venció o fue cancelada.
-   El dueño puede **editar** una gift card (título, descripción, imagen, beneficio y fechas; la fecha de inicio solo mientras no haya empezado) y **cancelarla**: las gift cards ya canjeadas no se alteran, las pendientes dejan de ser canjeables. Ve cuántas **envió**, **canjeó** y cuántas están **sin canjear**.

## 9b. Centro de notificaciones
-   Cada usuario tiene una **bandeja de notificaciones** (campana en la pantalla de inicio) donde queda **cada movimiento** que le llega: escaneos, premios, gift cards, campañas, minijuegos, pagos y avisos del administrador. Lleva un contador de no leídas; se marcan como leídas al abrirlas o todas a la vez.
-   **Limpieza automática:** el servidor borra solo lo viejo que únicamente se acumula, cada 6 horas: avisos ya leídos con más de **30 días** y cualquier aviso con más de **90 días**; el registro de intentos de escaneo con más de **90 días**; y los retos de minijuegos terminados o vencidos hace más de **90 días**. Nunca toca retos abiertos, gift cards, tarjetas ni premios.
-   Las notificaciones push (FCM) siguen funcionando; la bandeja las **conserva** para verlas después y tocar una abre la pantalla correspondiente (*Mis regalos*, un juego pendiente, el panel...). Cada usuario solo ve las suyas.

## 9c. Minijuegos
-   Hay tres minijuegos: **Tres en raya** (contra la computadora), **Ahorcado** y **Flappy Bird** (pasar 10 tubos sin chocar). El dueño los usa para que sus clientes vuelvan y ganen un regalo.
-   **Flujo:** (1) el dueño **solicita** los minijuegos desde *Minijuegos* en su panel; (2) el **administrador** revisa la solicitud (*Admin → Minijuegos*), **asigna los juegos** (al menos uno) y **define el premio** que ganarán los clientes (un descuento % o un mini premio); también puede retirar los minijuegos o rechazar la solicitud con un motivo que ve el dueño; (3) el dueño **envía un juego** a todos sus clientes o a clientes elegidos; (4) cada cliente recibe una **notificación**, la toca y abre el juego.
-   **Horario:** al enviar un juego, el dueño fija **cuándo empieza** (ahora o programado) y **cuándo termina** (por defecto, 7 días después del inicio; máximo 90 días; ambos los fija el administrador en *Ajustes*). El cliente recibe la notificación **cuando empieza** el juego (si es programado, la manda el servidor a esa hora) y solo puede jugar dentro del horario; fuera de él el reto aparece como *Todavía no empieza* o *Vencido*. Una partida en curso tampoco continúa después de la hora de fin.
-   **Intentos:** cada cliente tiene **hasta 3 intentos** (ajustable por el administrador, de 1 a 10) para ganar cada juego enviado. Si pierde un intento y le quedan, puede intentarlo de nuevo (empieza una partida nueva); si gana, el reto termina y recibe el premio; si pierde el tercero, el reto termina sin premio. Quien ya ganó ese premio no recibe el mismo juego de nuevo. Un envío llega como máximo a **1000 clientes** (ajustable).
-   **Premio:** al ganar, el cliente recibe **automáticamente una gift card** con el premio fijado por el administrador (con su código para canjear, igual que una gift card del dueño). Si ya tenía ese premio, se le avisa y no se duplica.
-   **Justicia (servidor):** el resultado lo decide el servidor, no la app. En Ahorcado la palabra nunca viaja al cliente hasta que termina; en Tres en raya el servidor valida cada jugada y responde la computadora; en Flappy el servidor comprueba que el puntaje sea posible según el tiempo transcurrido.
-   El dueño ve lo que envió: **enviados**, **jugaron** (usaron al menos un intento), **ganaron** y el estado de cada cliente (*Programado, Enviado, Intento 2 de 3, Jugando, Ganó, Perdió, Venció*).

## 9d. Cumpleaños
-   **Fecha de nacimiento (opcional):** al registrarse, el **cliente** puede poner su fecha de nacimiento (con un calendario); también puede cambiarla o **borrarla** desde su perfil. Es opcional y solo la guardan los clientes (los dueños no). Debe ser una fecha real, no futura y desde 1900.
-   **Privacidad:** el dueño ve solo el **día y el mes**, nunca el año ni la edad, y únicamente de los clientes que tienen tarjeta en sus locales. Si el cliente borra su fecha, deja de aparecerle al dueño.
-   **Aviso al dueño:** el servidor revisa cada 30 minutos y, a partir de la hora que fija el administrador (8:00 hora de Ecuador por defecto), avisa al **dueño** del local: *"Hoy cumple años Ana"* — *"Ana es cliente de Café Aurora. Regálale una gift card para celebrarlo."* El aviso sale **una sola vez por cliente, local y año** (aunque el servidor se reinicie) y llega a la **bandeja de notificaciones** y como push. Al **tocarlo** abre directamente la **plantilla de gift card de cumpleaños** con ese cliente ya marcado. Quien nació un 29 de febrero lo celebra el 28 en los años no bisiestos. Solo se avisa de locales activos.
-   **Plantilla de cumpleaños** (solo dentro de *Gift cards → Cumpleaños*, o desde el aviso): una gift card con el **diseño y el texto ya puestos** (cheque rosa con confeti, *"Feliz cumpleaños, Ana"* y *"Un regalo de Café Aurora por tu cumpleaños. Vale solo ese día."*). El dueño **no edita** la imagen ni el texto; solo elige:
    -   **El premio:** un descuento (%) o un mini premio.
    -   **A quién:** uno o varios de la lista de clientes que cumplen años **hoy o en los próximos días** (por defecto 7, ajustable por el administrador) y todavía no tienen su regalo de este año (cada uno recibe su propia gift card, con su cheque y código). Los que ya cumplieron no aparecen: la gift card vale solo ese día. Se ve el día y el mes, nunca la edad.
    -   **La hora:** *desde* (por defecto la hora del aviso, 8:00) y *hasta* (por defecto todo el día). **La fecha no se elige:** la gift card vale **solo el día del cumpleaños** de ese cliente (hora de Ecuador). Si el cumpleaños es otro día, el cliente la recibe ese día a la hora de inicio, con su aviso *"Café Aurora te regaló una gift card de cumpleaños"*; la ve en *Mis regalos* con el diseño de cumpleaños y *"Válida solo el 25.10.26"*, y se canjea como las demás.
-   Solo se puede **una por cliente, local y año**. El dueño también ve estas gift cards en su lista de *Gift cards*.
-   **Administrador:** en *Ajustes → Cumpleaños* fija la hora del aviso y con cuántos días de anticipación ve el dueño los cumpleaños.

## 9e. FidelyUsuario (insignia de fidelidad)
-   **Qué es:** el cliente que ya escaneó **3 veces** en un mismo local (y el local le aprobó cada escaneo) se vuelve **FidelyUsuario de ese local**, por su fidelidad. Es una insignia **por local**: se puede ser FidelyUsuario de un café y todavía no de una pizzería.
-   **Qué cuenta:** solo los **escaneos reales de un QR** que el local **aprobó**. No cuentan los puntos regalados a mano, ni los escaneos pendientes o rechazados. Como se calcula con escaneos ya aprobados, la insignia **no se pierde**.
-   **Lo que ve el cliente:** al entrar a la tarjeta de un local ve un recuadro con su estado: si ya la ganó, la insignia **FIDELYUSUARIO** con *"Por tu fidelidad a Café Aurora"*; si no, *"Te faltan 2 escaneos para ser FidelyUsuario"* con un punto por cada escaneo. En su lista de locales, donde ya es fiel, la tarjeta lleva la insignia.
-   **Lo que ve el dueño:** en *Clientes* cada FidelyUsuario lleva su insignia (y en su ficha), y un filtro **Todos / FidelyUsuarios (n)** (aparece cuando ya hay alguno) que se junta con la búsqueda por nombre.
-   **Avisos (una sola vez):** en el escaneo que completa la cantidad, el cliente recibe *"¡Ya eres FidelyUsuario de Café Aurora!"* (al tocarlo abre su tarjeta del local) y el dueño *"Nuevo FidelyUsuario: Ana ya es FidelyUsuario de Café Aurora"* (al tocarlo abre *Clientes*). Los escaneos siguientes no repiten el aviso.
-   **Administrador:** en *Ajustes → Negocios → Escaneos para ser FidelyUsuario* fija la cantidad (3 por defecto, de 1 a 50). Si la cambia, la insignia se recalcula con los escaneos que ya tiene cada cliente; el aviso solo sale cuando alguien llega justo a la cantidad.

## 10. Idiomas
-   La app está disponible en **español** (idioma base) e **inglés**. El idioma se elige en *Perfil → Idioma* (cliente y dueño), en el botón de idioma de la pantalla de inicio de sesión, en la barra lateral del panel del negocio en PC y en el panel de administración. El cambio es inmediato, sin cerrar sesión, y se recuerda en el dispositivo.
-   Los textos se escriben en español en el código y se traducen con un diccionario (`lib/core/l10n/strings_en.dart`): si un texto no tiene traducción se muestra en español. Para agregar un idioma o completar traducciones basta con ampliar ese diccionario.
-   **Avisos del servidor:** las notificaciones (push y bandeja) salen en el idioma de la app de cada usuario. La app le avisa al servidor su idioma al iniciar sesión y cada vez que lo cambia (`PATCH /users/language`). En la bandeja se guarda el texto original en español y se traduce al leerlo, así que si el usuario cambia de idioma sus avisos viejos también cambian. Las traducciones están en `backend/src/modules/notifications/notification-strings.en.ts`; un aviso sin traducción se muestra en español. Lo que escribió una persona (nombres, opiniones, motivos) no se traduce.
-   Los mensajes de error que devuelve el servidor siguen en español.

## 11. Versión web / PC
-   La app funciona en el navegador (Flutter Web). En pantallas anchas (≥ 960 px) el **panel del negocio y del aprobador** reemplaza las pestañas por una **barra lateral** (con avisos de pendientes, *Mis negocios*, idioma y cierre de sesión) y ocupa más ancho; el **panel de administración** muestra sus tarjetas y módulos en cuadrícula, y las listas y detalles se ensanchan hasta 1,5 veces su ancho móvil.
-   Los formularios (inicio de sesión, registro, alta de negocio) conservan un ancho angosto para leerse bien.
-   Los carruseles y filas de filtros se pueden arrastrar con el ratón. Escanear un QR en PC usa la cámara del navegador (requiere HTTPS o `localhost`).

## 11a. Ruta de Misiones (pantalla principal del cliente)
-   Las tarjetas del cliente se muestran como una **ruta en zigzag**: cada negocio es un **nodo** con su logo dentro de un anillo que se llena con los puntos, el premio, los **sellos** (un círculo por punto requerido; con más de 12 se resume en una barra) y el avance (p. ej. `6/10`).
-   Arriba, un aviso destaca la próxima meta: un **premio listo** para reclamar o, si no hay, el negocio **más cerca de completarse** ("Te falta 1 punto en...") con su barra de progreso.
-   Un nodo con premio sin entregar se marca con un regalo; uno con escaneo pendiente de aprobación, con un reloj de arena. Tocar un nodo abre el historial de esa tarjeta.

## 11a-bis. Pantalla de un local (tarjeta del cliente)
-   Al tocar un local en el inicio se abre su pantalla: arriba una **cabecera** con el logo del negocio, su nombre, su categoría y dirección, los **sellos** (un círculo por punto, el último es el premio) y el premio del local; debajo, tres pestañas fijas:
    -   **Premios:** los premios ganados (por reclamar, entregados o rechazados), con la transferencia a otro usuario.
    -   **Tarjetas:** las **gift cards** (y premios de rutas, retos y minijuegos) que **ese local** le dio al cliente, con su código.
    -   **Minijuegos:** los juegos que **ese local** le mandó: para jugar (con intentos restantes y hasta cuándo), programados, ganados, perdidos o vencidos. Tocar uno lo abre.
-   El registro de escaneos ya no se muestra en esta pantalla. El filtro de fechas de la cabecera filtra los premios.

## 11b. Seguridad de cuentas y datos
-   **Recuperar contraseña:** desde *¿Olvidaste tu contraseña?* se envía un **código de 6 dígitos** al correo (vence en **15 minutos**; se puede pedir otro cada minuto). Con el código el usuario crea su nueva contraseña. El código se guarda cifrado, se usa **una sola vez** y se bloquea tras **5 intentos fallidos**. La respuesta es la misma exista o no el correo (no se revela qué cuentas existen). El correo sale con la marca de Fidelity y **en el idioma de la app** de la persona; al cambiar la contraseña (por recuperación o desde el perfil) se envía además un **aviso de seguridad** por correo. Se configura con SMTP (`SMTP_HOST`, `SMTP_USER`, `SMTP_PASS`, `MAIL_FROM`; guía en `docs/correo.md` y prueba con `npm run mail:test`); la conexión va siempre cifrada. Sin SMTP, fuera de producción, el correo se escribe en el log del servidor; en producción el servidor avisa en rojo al arrancar.
-   **Contraseñas:** al registrarse, al recuperarla y al cambiarla se exigen **al menos 8 caracteres, con letras y números**, y no se aceptan las más comunes (`12345678`, `password1`, `fidelity123`...). Las cuentas anteriores con claves más cortas siguen entrando.
-   **Límite de intentos:** **10 inicios de sesión por minuto** por IP y correo (quien se equivoca con su cuenta no bloquea a los demás), **5 códigos de recuperación cada 10 minutos**, 10 intentos de usar un código cada 10 minutos, **20 registros por hora** por IP y 120 peticiones por minuto en el resto de la API. Al pasarse responde 429 ("Demasiados intentos"). Detrás de un proxy se define `TRUST_PROXY`.
-   **Administrador:** no existe ninguna clave por defecto. `npm run seed:admin` crea la cuenta con una clave fuerte al azar que se muestra **una sola vez**; si el administrador ya existe no se le toca la clave (`--rotate` le pone una nueva).
-   **Claves del servidor:** en producción el servidor **no arranca** si `JWT_SECRET` falta, es el valor de ejemplo o tiene menos de 32 caracteres, ni si se usa el secreto de ejemplo del webhook o la clave `postgres` de la base de datos.
-   **Registro:** solo se puede crear una cuenta de *cliente* o de *negocio*. El administrador lo asigna el sistema y el aprobador lo asigna un dueño desde su equipo.
-   **Listado de negocios:** requiere sesión. Un usuario normal ve solo los negocios activos con datos públicos (nombre, categoría, ubicación, premio...), **sin** el perfil del dueño, sus clientes ni su cédula/RUC. Ver inactivos (`all=true`) y los datos del dueño y los clientes es solo del administrador. Los tokens de notificaciones push no se devuelven a nadie.

## 11c. Ajustes que controla el administrador
-   El administrador cambia las reglas del sistema desde *Panel admin → Ajustes del sistema* (y las cuentas bancarias desde *Pagos → Cuentas bancarias*), sin tocar el servidor. Cada ajuste tiene un **rango permitido** (para que nadie deje la app inservible) y un **valor por defecto**; tocar un ajuste permite escribir otro valor o **restablecerlo**. Los cambios valen desde el momento en que se guardan (el servidor los recuerda unos 15 segundos).
-   **Precios:** registro de negocio (20 USD) y alta de sucursal (10 USD). Solo afectan a las órdenes nuevas.
-   **Minijuegos:** intentos por reto (3; de 1 a 10), duración si el local no pone fin (7 días), duración máxima de un reto (90 días) y clientes por envío (1000).
-   **Negocios:** aprobadores por negocio (10), opiniones por cliente y local al día (3) y escaneos aprobados para ser FidelyUsuario (3).
-   **Cumpleaños:** hora del aviso al dueño (8, hora de Ecuador; también es la hora de inicio por defecto del regalo) y días de anticipación con que el dueño ve los cumpleaños (7).
-   **Limpieza de datos:** días que se guardan los avisos leídos (30), cualquier aviso (90), el registro de intentos de escaneo (90) y los retos de minijuegos terminados (90). Los avisos leídos no pueden guardarse más que cualquier aviso, ni la duración por defecto de un reto superar a la máxima.
-   Lo que **no** se cambia desde la app son las claves secretas (SMTP, PayPhone, JWT, base de datos, Firebase): viven solo en el `.env` del servidor. Las reglas de seguridad de las contraseñas y los límites de intentos de inicio de sesión también son fijos del servidor, a propósito.
-   Cada negocio sigue fijando lo suyo (premio, puntos necesarios, cooldown entre escaneos, campañas); el administrador controla los límites y los precios que valen para todos.

## 12. Roles y Permisos
| Rol | Capacidades |
| :--- | :--- |
| **Client** | Ver sus tarjetas y su insignia FidelyUsuario por local, escanear QRs, ver sus premios, editar su perfil (incluida su fecha de cumpleaños, opcional), enviar sugerencias y reclamos de los locales donde escaneó. |
| **Approver** | Aprobar escaneos, validar premios y atender opiniones de los locales donde fue asignado. |
| **Business** | Generar QRs, aprobar escaneos, dar puntos manuales, ver métricas de su local, gestionar sucursales y equipo, pagar su registro, y regalar una gift card a sus clientes en su cumpleaños. |
| **Admin** | Dashboard global, exportar reportes CSV de todos los usuarios/negocios, validar pagos y activar/desactivar locales, atender sugerencias y reclamos, y fijar los precios, las cuentas bancarias y los ajustes del sistema. |

---
> [!WARNING]
> Cualquier cambio en `points_required` en la tabla `businesses` afectará los próximos ciclos de premios, pero no recalculará retroactivamente los premios ya emitidos.
