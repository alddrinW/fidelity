# 📋 Backlog Maestro del Proyecto Fidelity

## 🚀 Épicas y Estado de Implementación

### 🔐 Épica 1: Autenticación, Seguridad y Roles
- [x] **HU-01:** Registro y Login con JWT en NestJS (`/api/v1/auth/*`).
- [x] **HU-01:** Guard de autenticación JWT y Guard de Roles RBAC (`client`, `business`, `admin`).
- [x] **HU-01:** Protección contra escalamiento de privilegios a admin en registro.
- [x] **HU-01:** Endpoint de eliminación integral de cuenta (`deleteAccount`) con borrado en cascada.

### 🏢 Épica 2: Negocios y Códigos QR
- [x] **HU-02:** Gestión de categorías de negocios (`/api/v1/businesses/categories`).
- [x] **HU-02:** CRUD de Negocios con configuración de meta de puntos y horas de cooldown.
- [x] **HU-02:** Generación y activación de códigos QR únicos (`/api/v1/qr-codes`).
- [x] **HU-02:** Moderación de estado de comercios por administradores (`PATCH /api/v1/businesses/:id/status`).

### 💳 Épica 3: Tarjetas de Fidelidad y Validación de Escaneos
- [x] **HU-03:** Emisión y consulta de tarjetas de clientes (`/api/v1/loyalty-cards/*`).
- [x] **HU-03:** Endpoint transaccional de escaneo QR (`/api/v1/scans/validate`) con cálculo de cooldown en horas/minutos.
- [x] **HU-03:** Registro de intentos en `scan_attempts` con tracking de fallos por cooldown o negocio inactivo.
- [x] **HU-03:** Asignación manual de puntos (`/api/v1/scans/manual-points`) con validación de premios pendientes.
- [x] **HU-03:** Aprobación y rechazo de escaneos.

### 🎁 Épica 4: Premios y Transferencias
- [x] **HU-04:** Generación automática de premios al completar meta de puntos.
- [x] **HU-04:** Gestión de ciclo de vida de premios (`pending`, `approved`, `claimed`, `rejected`).
- [x] **HU-04:** Transferencia atómica de premios entre usuarios (`/api/v1/rewards/transfer`) con registro en `reward_transfer_history`.

### 🔔 Épica 5: Notificaciones Push y WebSockets
- [x] **HU-05:** Integración con Firebase Admin SDK para despacho de notificaciones FCM v1.
- [x] **HU-05:** Eventos dirigidos a clientes, comercios y administradores.
- [x] **HU-05:** Realtime WebSocket Gateway (Socket.io) para streaming de escaneos y recompensas.
- [x] **HU-05:** Centro de notificaciones: bandeja por usuario con cada movimiento, contador de no leídas y apertura de la pantalla relacionada.

### 📊 Épica 6: Panel de Administración y Soporte
- [x] **HU-06:** Dashboard de métricas globales del sistema (`/api/v1/admin/stats`).
- [x] **HU-06:** Directorio de usuarios y asignación de roles (`/api/v1/admin/users`).
- [x] **HU-06:** Ajustes del sistema controlados por el administrador (`/api/v1/settings`): precios, reglas de minijuegos, límites de negocios y días de limpieza de datos, con rango y valor por defecto; cuentas bancarias de los pagos (`PUT /api/v1/payments/bank-accounts`).
- [x] **HU-06:** Monitoreo de actividad reciente en tiempo real.
- [x] **HU-06:** Módulo de tickets de soporte (`/api/v1/support-tickets`).

### 📱 Épica 7: Acople Integral App Móvil con Backend NestJS
- [x] **HU-07:** Implementación de `ApiClient` HTTP y almacenamiento seguro de tokens JWT.
- [x] **HU-07:** Migración de `AuthRepository` y `AuthNotifier` hacia los endpoints REST de NestJS.
- [x] **HU-07:** Migración de repositorios de negocio (`LoyaltyCards`, `Scans`, `Rewards`, `Businesses`, `Users`, `Admin`).
- [x] **HU-07:** Adaptación de `RealtimeSyncService` a Socket.io WebSocket Gateway.
- [x] **HU-07:** Desacople completo de `Supabase.initialize()` y validación estática de la app.

### 🎮 Épica 8: Gamificación y Rutas de Progreso Estilo Duolingo
- [x] **HU-08:** Dashboard interactivo en formato "Ruta de Misiones" con barras de progreso a la siguiente recompensa. *(Pantalla principal del cliente: cada negocio es un nodo en un camino en zigzag con anillo de progreso y sellos; aviso de cuánto falta para el próximo premio.)*
- [x] **HU-08:** Módulo de mini-juegos. *(Tres en raya, Ahorcado y Flappy Bird: el dueño los solicita, el administrador asigna los juegos y el premio, el dueño los envía y el cliente los abre desde una notificación; un intento por envío y premio automático en gift card.)*
- [ ] **HU-08:** Ruleta de beneficios.
- [ ] **HU-08:** Sistema de rachas y multiplicadores de puntos por constancia de visita.

### 🐾 Épica 9: Mascota Guía "Fido" y Micro-interacciones
- [x] **HU-09:** Integración de Fido como guía en flujos de bienvenida, escaneo y soporte. *(Bienvenida del dueño con accesos directos; consejo en el escáner; asistentes de pago y buzón.)*
- [x] **HU-09:** Animación de entrada de la app: Fido aparece, escanea un código con su teléfono, lo esconde, guiña y se queda con los brazos cruzados junto a "FIDELITY" (se ve al abrir la app en el celular y en la web; un toque la salta y respeta "reducir movimiento").
- [x] **HU-09:** Micro-animaciones de celebración con confeti y reacciones dinámicas de estado. *(Salto de victoria con confeti al escanear.)*
- [x] **HU-09:** Modos reactivos (calma, alerta de cooldown, euforia de canje). *(`FidoMascot`: calma, celebración, pensativo con reloj de arena y euforia; se detienen solos y respetan "reducir movimiento".)*

### 🏢 Épica 10: Panel Empresarial Multi-sucursal y Campañas
- [x] **HU-10:** Matriz de control centralizado de múltiples sucursales para comercios. *(Mis negocios: estado, clientes, escaneos y equipo por negocio y sucursal.)*
- [x] **HU-10:** Creador de campañas de marketing segmentadas para clientes fidelizados. *(Eventos, tarjetas de regalo y rutas/pasaporte; programables; llegan a los clientes de los locales participantes.)*
- [x] **HU-10:** Gift cards del dueño (descuento o mini premio) con entrega automática a todos o a clientes elegidos, edición, cancelación y canje por QR.
- [x] **HU-10:** Cumpleaños: el cliente puede poner su fecha de nacimiento (opcional) al registrarse o en su perfil; el servidor avisa al dueño el día del cumpleaños y el dueño le regala una gift card con la **plantilla de cumpleaños** (diseño y texto ya puestos; elige premio, a quién y la hora; vale solo el día del cumpleaños) desde *Gift cards → Cumpleaños* o tocando el aviso que le llega al dueño (`/api/v1/birthdays`). Solo se ve día y mes, nunca la edad.
- [x] **HU-10:** Insignia **FidelyUsuario**: al 3.er escaneo aprobado en un local (cantidad ajustable por el administrador) el cliente gana la insignia de ese local; la ve al entrar a su tarjeta y el dueño la ve en su lista de clientes (con filtro). Ambos reciben un aviso una sola vez.
- [x] **HU-10:** Selector global de idiomas en tiempo real para el panel de escritorio. *(Español e inglés; cambia al instante y se recuerda.)*

### 💳 Épica 11: Módulo Transaccional "PAGA YA" y Rol Aprobador
- [x] **HU-11:** Asistente interactivo guiado por Fido para activación de planes y sucursales (PAGA YA). *(Orden de pago con referencia, reporte con comprobante y validación del administrador; sin pasarela de pago.)*
- [x] **HU-11:** Control de acceso avanzado con rol de "Aprobador" para validación de premios especiales. *(Aprueba escaneos, valida premios y canjea tarjetas; no anula transacciones.)*
- [ ] **HU-11:** Monitor visual de estado de conectividad API y puntos de venta.

### 💬 Épica 12: Buzón de Sugerencias Conversacional Post-Escaneo
- [x] **HU-12:** Hoja interactiva post-escaneo para calificación ágil de atención.
- [x] **HU-12:** Enrutamiento privado de comentarios y reclamos al panel de dueños y aprobadores. *(También llegan al administrador.)*
