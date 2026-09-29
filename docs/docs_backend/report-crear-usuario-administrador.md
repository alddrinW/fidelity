# Reporte: Creación de Usuario Administrador

- **Fecha:** 2026-09-29
- **Módulo:** Autenticación / Base de Datos
- **Tipo de Tarea:** Seed / Creación de Usuario

## 1. Objetivo del Cambio
Crear y aprovisionar en la base de datos PostgreSQL la cuenta de usuario con rol de Administrador (`admin`) con las credenciales solicitadas para el entorno de Fidelity.

## 2. Credenciales Registradas
- **Email:** `admin@fidelity.com`
- **Contraseña:** `hola123` (almacenada con hash `bcrypt` salt rounds 10)
- **Rol:** `admin` (`UserRole.ADMIN`)
- **Nombre:** `Administrador Fidelity`

## 3. Archivos Modificados / Creados
- [`backend/src/database/seeds/create-admin.ts`](file:///home/alddrinW/Documentos/Trabajo/fidelity/backend/src/database/seeds/create-admin.ts): Script de inicialización y sincronización/creación idempotente del usuario administrador.
- [`backend/package.json`](file:///home/alddrinW/Documentos/Trabajo/fidelity/backend/package.json): Se añadió el comando `"seed:admin"` para re-ejecutar el script cuando se requiera.

## 4. Ejecución del Seed
Para volver a ejecutar o actualizar las credenciales del administrador:
```bash
cd backend
npm run seed:admin
```
