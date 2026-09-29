# 🏛️ Arquitectura del Sistema Fidelity

## Estructura General del Repositorio

```text
fidelity/
├── backend/                   # Backend API Dedicado (NestJS + Express + PostgreSQL)
│   ├── src/
│   │   ├── common/            # Decoradores, Guards (JWT, Roles), Filtros e Interceptores
│   │   ├── config/            # Configuración de variables de entorno y TypeORM DataSource
│   │   ├── database/          # Entidades TypeORM y Scripts de Migración SQL
│   │   │   ├── entities/      # Profile, Business, LoyaltyCard, Scan, Reward, etc.
│   │   │   └── migrations/    # Schema SQL inicial
│   │   ├── modules/           # Módulos de dominio (Feature-First)
│   │   │   ├── auth/          # Autenticación JWT, registro, login y roles
│   │   │   ├── users/         # Perfiles, FCM tokens y borrado integral
│   │   │   ├── businesses/    # Categorías, comercios, moderación y métricas
│   │   │   ├── loyalty-cards/ # Tarjetas de fidelidad y balances
│   │   │   ├── scans/         # Motor de escaneo con cooldown y puntos manuales
│   │   │   ├── rewards/       # Ciclo de vida de premios y transferencias atómicas
│   │   │   ├── qr-codes/      # Generación y activación de códigos QR
│   │   │   ├── notifications/ # Servicio Firebase Admin SDK (FCM)
│   │   │   ├── realtime/      # WebSockets Gateway (Socket.io)
│   │   │   ├── support-tickets/# Gestión de tickets de soporte
│   │   │   └── admin/         # Métricas globales y panel de control
│   │   ├── app.module.ts      # Módulo raíz de la aplicación
│   │   └── main.ts            # Entrypoint con Swagger OpenAPI en /api/docs
│   ├── package.json           # Dependencias del backend
│   └── tsconfig.json          # Configuración de TypeScript
├── fidelity_app/              # Aplicación Móvil (Flutter)
│   ├── lib/
│   │   ├── core/              # Configuraciones globales, servicios, temas, utilidades
│   │   │   ├── config/        # Configuración de URLs y API Backend
│   │   │   ├── services/      # ApiClient HTTP, WebSockets, notificaciones, utilidades
│   │   │   ├── theme/         # Sistema de diseño "Pop-Minimalism"
│   │   │   └── utils/         # Helpers y formateadores
│   │   ├── features/          # Módulos por dominio de negocio (Feature-first)
│   │   │   ├── auth/          # Autenticación JWT, roles y wrappers de sesión
│   │   │   ├── business/      # Dashboard del comercio y gestión de locales
│   │   │   ├── cards/         # Visualización y gestión de tarjetas del cliente
│   │   │   ├── scanner/       # Lector QR y validación de escaneos
│   │   │   └── admin/         # Panel administrativo y métricas
│   │   └── main.dart          # Punto de entrada de la aplicación Flutter
│   └── pubspec.yaml           # Dependencias de Flutter
├── supabase/                  # Backend & BaaS Alternativo (Supabase)
│   ├── functions/             # Supabase Edge Functions (Deno / TypeScript)
│   └── migrations/            # Scripts SQL, RLS, Triggers y Funciones PL/pgSQL
├── docs/                      # Documentación del proyecto
│   ├── HU/                    # Historias de Usuario (HU-01 a HU-07)
│   ├── docs_backend/          # Reportes técnicos del Backend
│   ├── requirements/          # Requisitos funcionales (SRS) y Manual de Marca
│   ├── documentacion/         # Documentación integral de arquitectura
│   └── backlog.md             # Backlog maestro de tareas
└── rules/                     # Reglas operativas y definiciones técnicas
```
