# HU-04: Canje, Aprobación y Transferencia de Premios

## Historia de Usuario
**Como** cliente acreedor de un premio,  
**quiero** canjear mi recompensa en el comercio o transferirla a otro usuario,  
**para** disfrutar de mi beneficio o compartirlo con amigos/familiares.

## Criterios de Aceptación
1. El comercio puede aprobar (`approved` / `claimed`) o rechazar (`rejected`) los premios pendientes en el punto de venta.
2. El cliente puede transferir un premio no reclamado a otro usuario mediante su identificador/correo.
3. La transferencia es atómica: transfiere la propiedad del registro del premio y asegura que el receptor tenga una tarjeta de fidelidad emitida para ese comercio.
4. Queda un registro inmutable en `reward_transfer_history` con fecha y participantes.
