# Reporte Técnico: Acople Integral Flutter con Backend NestJS & Express

**Fecha:** 2026-09-29  
**Módulo:** Mobile (`fidelity_app`)  
**Autor:** Antigravity  

---

## 1. Resumen Ejecutivo
Se completó la migración y desacople integral de la aplicación móvil Flutter del SDK de Supabase hacia la arquitectura dedicada con el backend en **NestJS**, **Express** y **PostgreSQL**. La aplicación ahora opera consumiendo la API REST centralizada y WebSockets mediante Socket.io.

---

## 2. Componentes Migrados y Nuevas Implementaciones

### 2.1 Capa de Red y Autenticación
- **`ApiClient` (`lib/core/services/api_client.dart`):** Cliente HTTP singleton con soporte para adjuntar el encabezado `Authorization: Bearer <token>`, decodificación automática de respuestas empaquetadas, manejo tipado de excepciones (`ApiException`) y persistencia en `SharedPreferences`.
- **`ApiConfig` (`lib/core/config/api_config.dart`):** Configuración dinámica y adaptable de endpoints para emulador Android (`10.0.2.2`), escritorio/web (`localhost`) y redes locales.
- **`AuthRepository` (`lib/features/auth/data/auth_repository.dart`):** Integración con `/api/v1/auth/login`, `/api/v1/auth/register`, `/api/v1/auth/me` y `/api/v1/auth/reset-password`.
- **`AuthNotifier` (`lib/features/auth/providers/auth_provider.dart`):** Gestión de estados de sesión reactivos (`AuthAdmin`, `AuthBusinessActive`, `AuthBusinessPendingCreate`, `AuthClient`, `AuthUnauthenticated`) sin dependencias de Supabase.

### 2.2 Sincronización en Tiempo Real
- **`RealtimeSyncService` (`lib/core/services/realtime_sync_service.dart`):** Migrado a `socket_io_client` conectado al gateway de NestJS. Escucha eventos en vivo (`scan:new`, `card:updated`, `scan:status`, `reward:status`, `reward:transferred`, `qr:updated`) y gestiona la suscripción a salas de negocio (`join_business` / `leave_business`).

### 2.3 Repositorios de Dominio
- **`MyCardsRepository` & `CardHistoryRepository`:** Migrados a `/api/v1/loyalty-cards/my-cards` e `/api/v1/loyalty-cards/:id/history`.
- **`ScannerRepository`:** Migrado a `/api/v1/scans/validate`.
- **`RewardsManagementRepository`:** Migrado a `/api/v1/rewards/*`.
- **`UserProfileRepository`:** Migrado a `/api/v1/users/profile` y `/api/v1/users/account`.
- **`BusinessRepository` & `DashboardRepository`:** Migrados a `/api/v1/businesses/*` y `/api/v1/admin/*`.

### 2.4 Entrypoint y Notificaciones
- **`main.dart`:** Eliminada la inicialización obligatoria de Supabase. Añadida la inicialización asíncrona de `ApiClient().init()` y arranque seguro de Firebase para entornos multiplataforma.
- **`PushNotificationService`:** Registro de token FCM mediante `PATCH /api/v1/users/fcm-token`.

---

## 3. Verificación de Calidad
- **Flutter Analyzer:** 0 errores de compilación (`flutter analyze`).
- **NestJS TypeScript:** Compilación limpia sin errores de tipos (`npx tsc --noEmit`).
