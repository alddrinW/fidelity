# HU-05: Notificaciones Push y Comunicación en Tiempo Real

## Historia de Usuario
**Como** usuario del ecosistema Fidelity,  
**quiero** recibir notificaciones push y ver actualizaciones en tiempo real,  
**para** estar enterado al instante de mis puntos, premios, transferencias y actividad del local.

## Criterios de Aceptación
1. El backend despacha notificaciones FCM a través de Firebase Admin SDK ante eventos de escaneo, aprobación de puntos, premios alcanzados y transferencias.
2. El servidor WebSocket emite eventos dirigidos a salas de usuario (`user:{id}`) y salas de comercio (`business:{id}`).
3. El dashboard del negocio se refresca instantáneamente sin necesidad de recargar la pantalla.
