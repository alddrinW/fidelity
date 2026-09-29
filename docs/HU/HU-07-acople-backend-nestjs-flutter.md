# HU-07: Acople e Integración de la App Móvil con Backend NestJS

## Historia de Usuario
**Como** usuario del sistema Fidelity (Cliente, Dueño de Negocio o Administrador),
**quiero** que la aplicación móvil se comunique de forma segura y directa con la API de NestJS y Express,
**para** disfrutar de un rendimiento optimizado, autenticación JWT unificada y sincronización en tiempo real mediante WebSockets sin dependencia del cliente Supabase.

---

## Criterios de Aceptación (DoD)

1. **Cliente HTTP Centralizado (`ApiClient`):**
   - Gestión automática del token JWT en el encabezado `Authorization: Bearer <token>`.
   - Manejo estandarizado de excepciones HTTP y timeouts.
   - Almacenamiento y recuperación persistente de la sesión en `SharedPreferences`.

2. **Migración de Repositorios:**
   - `AuthRepository`: Migrado a `/api/v1/auth/*` (`login`, `register`, `me`, `reset-password`).
   - `LoyaltyCardsRepository` / `CardHistoryRepository`: Migrado a `/api/v1/loyalty-cards/*`.
   - `ScannerRepository`: Migrado a `/api/v1/scans/validate`.
   - `RewardsManagementRepository`: Migrado a `/api/v1/rewards/*`.
   - `UserProfileRepository`: Migrado a `/api/v1/users/*`.
   - `BusinessRepository`: Migrado a `/api/v1/businesses/*`.
   - `AdminRepository` / pantallas administrativas: Migradas a `/api/v1/admin/*`.

3. **Sincronización en Tiempo Real (`RealtimeSyncService`):**
   - Conexión mediante `socket_io_client` a la pasarela WebSocket de NestJS (`/realtime`).
   - Autenticación con token JWT en el handshake del socket.
   - Escucha reactiva de eventos `card:updated`, `scan:new`, `scan:status`, `reward:status`, `reward:transferred`.

4. **Desacople e Inicio Limpio:**
   - Eliminación de la inicialización de Supabase en `main.dart`.
   - Fallback de plataforma seguro para Firebase en entornos no móviles.
