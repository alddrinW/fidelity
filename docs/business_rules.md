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
-   El registro de un negocio **tiene costo** (precio configurable con `REGISTRATION_FEE`, y `BRANCH_FEE` para sucursales). Al crearse, el negocio queda **inactivo** (`is_active = false`) sin importar lo que envíe la app, y se genera su **orden de pago** con una referencia única (`FID-XXXXXX`).
-   Mientras está inactivo, su dueño ve la pantalla **"Activa tu cuenta"** con el botón **PAGA YA**, y sus QR no se pueden escanear.
-   **PAGA YA** es un asistente guiado por Fido en tres pasos: (1) plan y costo, (2) **elegir cómo pagar** y (3) confirmar. Se paga dentro de la app, sin pedir los datos por WhatsApp ni correo:
    -   **Transferencia bancaria:** la app muestra la cuenta (banco, número, tipo, beneficiario y CI/RUC, cada dato con botón de copiar), el monto y la referencia del pago. Después el dueño **sube la foto del comprobante** (obligatoria) y, si quiere, el número de transacción.
    -   **Tarjeta débito/crédito:** la app lleva a la **pasarela de pago** (enlace configurable con la referencia y el monto) y el dueño vuelve a confirmar "Ya pagué". La app nunca recibe ni guarda datos de la tarjeta.
    -   Los métodos se configuran en el servidor (`BANK_*` y `CARD_PAYMENT_URL`); si uno no está configurado, la app no lo ofrece. No hay confirmación automática de la pasarela: el administrador valida el pago.
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
-   El dueño crea campañas desde la pestaña **Campañas** de su panel, para uno o varios de sus negocios activos (sucursales participantes). Hay tres tipos:
    -   **Evento:** un anuncio o novedad para los clientes fidelizados (sin cupón).
    -   **Tarjeta de regalo:** un **descuento** (1–100 %) o un **mini premio**. El cliente la reclama una sola vez y recibe un código con QR; el local lo canjea.
    -   **Ruta (pasaporte):** el cliente junta **sellos** visitando los locales de la ruta (mínimo 2). Un local da su sello cuando se **aprueba un escaneo real de QR** del cliente mientras la ruta está vigente (los puntos regalados a mano no cuentan, y cada local da un solo sello). Al juntar los sellos requeridos, el cliente recibe un **premio con código** para canjear.
-   **Programación:** una campaña puede lanzarse ya o programarse con fecha y hora de inicio, y tener fecha de fin opcional. Estados: *Programada → Activa → Finalizada* (o *Cancelada*). Un programador interno revisa cada minuto y avisa a los clientes cuando llega la hora de inicio (si el servidor estuvo apagado, avisa al volver).
-   **Quién la recibe:** los clientes con tarjeta en alguno de los negocios participantes. Reciben una notificación al empezar la campaña y la ven en **Novedades** (arriba de su pantalla de inicio). Las tarjetas y premios quedan en *Perfil → Mis regalos*.
-   **Canje:** el dueño y los aprobadores canjean el código en la pestaña *Campañas* (dueño) o *Canjear* (aprobador). Un código no se canjea dos veces ni cuando la campaña ya terminó o fue cancelada.
-   Solo se crean campañas para negocios propios y **activos**.

## 10. Idiomas
-   La app está disponible en **español** (idioma base) e **inglés**. El idioma se elige en *Perfil → Idioma* (cliente y dueño), en el botón de idioma de la pantalla de inicio de sesión, en la barra lateral del panel del negocio en PC y en el panel de administración. El cambio es inmediato, sin cerrar sesión, y se recuerda en el dispositivo.
-   Los textos se escriben en español en el código y se traducen con un diccionario (`lib/core/l10n/strings_en.dart`): si un texto no tiene traducción se muestra en español. Para agregar un idioma o completar traducciones basta con ampliar ese diccionario.
-   Los mensajes que envía el servidor (errores y notificaciones push) están en español.

## 11. Versión web / PC
-   La app funciona en el navegador (Flutter Web). En pantallas anchas (≥ 960 px) el **panel del negocio y del aprobador** reemplaza las pestañas por una **barra lateral** (con avisos de pendientes, *Mis negocios*, idioma y cierre de sesión) y ocupa más ancho; el **panel de administración** muestra sus tarjetas y módulos en cuadrícula, y las listas y detalles se ensanchan hasta 1,5 veces su ancho móvil.
-   Los formularios (inicio de sesión, registro, alta de negocio) conservan un ancho angosto para leerse bien.
-   Los carruseles y filas de filtros se pueden arrastrar con el ratón. Escanear un QR en PC usa la cámara del navegador (requiere HTTPS o `localhost`).

## 12. Roles y Permisos
| Rol | Capacidades |
| :--- | :--- |
| **Client** | Ver sus tarjetas, escanear QRs, ver sus premios, editar su perfil, enviar sugerencias y reclamos de los locales donde escaneó. |
| **Approver** | Aprobar escaneos, validar premios y atender opiniones de los locales donde fue asignado. |
| **Business** | Generar QRs, aprobar escaneos, dar puntos manuales, ver métricas de su local, gestionar sucursales y equipo, pagar su registro. |
| **Admin** | Dashboard global, exportar reportes CSV de todos los usuarios/negocios, validar pagos y activar/desactivar locales, atender sugerencias y reclamos. |

---
> [!WARNING]
> Cualquier cambio en `points_required` en la tabla `businesses` afectará los próximos ciclos de premios, pero no recalculará retroactivamente los premios ya emitidos.
