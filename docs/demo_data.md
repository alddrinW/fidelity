# Datos de demostración

Para ver la plataforma llena (negocios, clientes, escaneos, premios, campañas, minijuegos, pagos, opiniones y notificaciones) sin crearlos a mano:

```bash
cd backend
npm run seed:demo             # crea los datos (si ya existen, no duplica)
npm run seed:demo -- --reset  # los borra y los crea de nuevo
npm run seed:demo -- --clean  # solo los borra
```

- **Solo toca lo suyo:** todo cuelga de cuentas con correo `@demo.fidelity.test`. Al borrarlas se borra también todo lo que crearon (las claves foráneas son en cascada). Tus datos reales no se tocan.
- **Solo en local:** el script se niega a correr si `DB_HOST` no es local o `NODE_ENV=production` (salvo `DB_SEED_ALLOW_REMOTE=true`).
- **Es repetible:** el aleatorio usa una semilla fija, así que siempre sale lo mismo.
- **Clave de todas las cuentas demo:** `DEMO_PASSWORD` en `backend/src/database/seeds/demo-data.ts` (es solo para desarrollo local).

## Qué crea

| Qué | Cuánto |
|---|---|
| Negocios | 10 de 9 dueños: 8 activos (uno con sucursal), uno con pago por validar y uno con pago pendiente |
| Clientes | 28, con 2 a 5 tarjetas cada uno (puntos, historial de escaneos y premios canjeados) |
| Aprobadores | 4, en Café Aurora, El Fogón y Barbería Don Filo |
| Escaneos | Aprobados (historial de 80 días), pendientes de aprobar y algunos rechazados |
| Premios | Canjeados, por entregar (pendientes y aprobados) y uno rechazado |
| Campañas | Eventos (activos, programado y terminado), gift cards (a todos y a clientes elegidos, canjeadas y sin canjear, una cancelada, una programada) y la *Ruta del sabor* con sellos |
| Minijuegos | Solicitud aprobada (Café Aurora), pendiente (Don Filo) y rechazada (Gym), con 12 retos en todos los estados |
| Pagos | Pagados con tarjeta o validados por el administrador, uno reportado y uno pendiente |
| Opiniones y soporte | Elogios, sugerencias y reclamos (algunos respondidos) y 2 tickets |
| Notificaciones | Bandeja de clientes, dueños y aprobadores, con leídas y sin leer |

## Cuentas útiles

- Dueño con más datos: `aurora.zhunio@demo.fidelity.test`
- Dueño con solicitud de minijuegos pendiente: `filomeno.chavez@demo.fidelity.test`
- Aprobador: `josue.ramos@demo.fidelity.test`
- Clientes: `nombre.apellido@demo.fidelity.test` (los nombres salen al correr el script)
- El administrador es el que ya existe en tu base (el script no lo cambia).
