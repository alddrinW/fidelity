# Historia de Usuario: HU-12 - Buzón de Sugerencias Conversacional Post-Escaneo

- **Identificador:** `HU-12`
- **Módulo:** Experiencia del Consumidor / Calidad del Servicio / Feedback
- **Prioridad:** Media

---

## 1. Declaración de la Historia
**Como** consumidor que acaba de realizar un escaneo en un local,  
**quiero** calificar la atención y enviar comentarios a través de una mini-interacción guiada por Fido,  
**para** comunicar mi experiencia de forma rápida y lúdica mientras ayudo al negocio a mejorar su servicio.

---

## 2. Criterios de Aceptación (Gherkin)

### Escenario 1: Despliegue automático de calificación rápida
- **Dado** que un escaneo se procesó exitosamente,
- **Cuando** concluye la animación de celebración,
- **Entonces** debe emerger una hoja inferior interactiva donde Fido invita a calificar la experiencia con 3 opciones rápidas y etiquetas de motivo (ej. "Atención rápida", "Local impecable").

### Escenario 2: Envío de sugerencia o reclamo privado
- **Dado** que el usuario selecciona una calificación baja o pulsa el botón de sugerencia detallada,
- **Cuando** ingresa su comentario y presiona enviar,
- **Entonces** la retroalimentación se transmite encriptada al panel del dueño y al supervisor con Rol Aprobador, y Fido agradece el aporte con una animación empática.
