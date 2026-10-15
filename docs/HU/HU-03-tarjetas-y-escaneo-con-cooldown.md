# HU-03: Tarjetas de Fidelización y Validación de Escaneos con Cooldown

## Historia de Usuario
**Como** cliente de un comercio,  
**quiero** escanear el código QR del local con mi teléfono,  
**para** acumular puntos de fidelidad de manera segura, con la aprobación del local.

## Criterios de Aceptación
1. Si el cliente escanea dentro de la ventana de cooldown configurada por el comercio, el sistema rechaza la operación con código HTTP 429 indicando el tiempo restante.
2. Si el código QR es válido y el cooldown ha expirado, el sistema registra el escaneo en estado `pending` (la tarjeta se crea si no existía), marca la fecha del último escaneo y avisa al comercio. **El punto todavía no se suma.**
3. Mientras el cliente tenga un escaneo `pending` en un comercio no puede registrar otro en ese mismo comercio (HTTP 409, `pending_scan`). Tampoco puede escanear si tiene un premio `pending` sin entregar en ese comercio (HTTP 409, `pending_reward`).
4. El comercio aprueba o rechaza el escaneo con `PATCH /scans/:id/status` (`approved` o `rejected`). Solo el dueño del comercio o un administrador pueden hacerlo, y un escaneo se procesa una sola vez (un segundo intento responde 409).
5. Al **aprobar**, el sistema suma 1 punto a la tarjeta en una transacción. Si el nuevo puntaje alcanza o supera la meta (`points_required`), se genera automáticamente un premio en estado `pending` y el contador de puntos reinicia su ciclo. La respuesta incluye `rewardCompleted`. El cliente recibe una notificación y la actualización en tiempo real.
6. Al **rechazar**, no se suma ningún punto y el cliente recibe una notificación.
7. El comercio puede asignar puntos manualmente desde su dashboard validando que el cliente no posea premios pendientes de entrega.
