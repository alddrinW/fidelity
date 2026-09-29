# HU-03: Tarjetas de Fidelización y Validación de Escaneos con Cooldown

## Historia de Usuario
**Como** cliente de un comercio,  
**quiero** escanear el código QR del local con mi teléfono,  
**para** acumular puntos de fidelidad de manera inmediata y segura.

## Criterios de Aceptación
1. Si el cliente escanea dentro de la ventana de cooldown configurada por el comercio, el sistema rechaza la operación con código HTTP 429 indicando el tiempo restante.
2. Si el código QR es válido y el cooldown ha expirado, el sistema suma 1 punto al saldo de la tarjeta y actualiza la fecha del último escaneo.
3. Si el nuevo puntaje alcanza o supera la meta (`points_required`), se genera automáticamente un premio en estado `pending` y el contador de puntos reinicia su ciclo.
4. El comercio puede asignar puntos manualmente desde su dashboard validando que el cliente no posea premios pendientes de entrega.
