# 📑 System Requirements Specification (SRS) - Fidelity

## 1. Introducción y Propósito
El sistema **Fidelity** es una solución omnicanal de fidelización de clientes para comercios locales. El sistema sustituye las tarjetas físicas de sellos por tarjetas digitales y códigos QR interactivos con validación de tiempo de enfriamiento (*cooldown*) anti-fraude, canje de recompensas y transferencias entre usuarios.

## 2. Requerimientos Funcionales

### RF-01: Autenticación y Gestión de Identidad
- Registro de usuarios con roles diferenciados: `client` (cliente) y `business` (dueño de negocio).
- Protección estricta contra escalamiento de privilegios al rol `admin`.
- Autenticación mediante JSON Web Tokens (JWT) y soporte de actualización de token FCM para notificaciones push.
- Eliminación integral de cuenta (*Right to be Forgotten*) con borrado en cascada transaccional.

### RF-02: Gestión de Negocios y Códigos QR
- Creación y edición de perfiles de negocio por parte de sus dueños.
- Configuración de parámetros de fidelización: `points_required` (puntos para ganar premio) y `cooldown_hours` (ventana mínima entre escaneos).
- Generación de códigos QR estáticos y dinámicos para escaneo en puntos de venta.
- Moderación administrativa para activar/desactivar comercios en la plataforma.

### RF-03: Tarjetas de Fidelización y Escaneo QR
- Emisión automática de tarjeta de fidelidad al primer escaneo o consulta.
- Validación atómica de escaneo mediante `/api/v1/scans/validate`:
  1. Validación de QR y estado activo del comercio.
  2. Verificación de cooldown respecto a `last_scan_at`.
  3. Incremento de puntos y registro en histórico de escaneos.
  4. Generación automática de premios al alcanzar la meta.
- Asignación manual de puntos por el dueño (`/api/v1/scans/manual-points`) con validación de premios pendientes.

### RF-04: Premios y Transferencias
- Generación de premios en estado `pending` al completar el ciclo de puntos.
- Flujo de aprobación y entrega de premios (`approved`, `claimed`, `rejected`).
- Transferencia atómica de premios entre clientes mediante correo/identificador de usuario con creación automática de tarjeta de fidelidad para el destinatario.

### RF-06: Acople e Integración de App Móvil con Backend NestJS
- Comunicación HTTP/REST directa con la API de NestJS (`/api/v1`) utilizando tokens JWT en encabezados Bearer.
- Sincronización en tiempo real basada en WebSockets con Socket.io conectado a la pasarela centralizada de NestJS.
- Eliminación de la capa de acceso directo a base de datos de Supabase en el cliente móvil.

## 3. Requerimientos No Funcionales
- **Seguridad:** Encriptación de contraseñas con bcrypt (cost factor 10), validación de esquemas con class-validator y autorización basada en roles (RBAC).
- **Consistencia:** Operaciones críticas de saldo y transferencias ejecutadas bajo transacciones ACID en PostgreSQL.
- **Rendimiento:** Tiempos de respuesta inferiores a 100ms para validación de escaneos y consultas de tarjetas indexadas.
