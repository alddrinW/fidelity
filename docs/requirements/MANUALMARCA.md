# 🎨 Manual de Marca y UX Writing - Fidelity

---

## 1. Identidad Visual y Estilo General
Fidelity emplea una estética **Pop-Minimalist** que combina modernidad, contraste elegante, energía visual y legibilidad instantánea en entornos móviles y paneles web.

- **Tipografías:**
  - *Títulos, Números y Encabezados de Impacto:* Anton (Impactante, moderno, audaz y distintivo).
  - *Cuerpo de Texto, Formularios y Tablas:* Poppins (Alta legibilidad, balance tipográfico y versatilidad en pesos regular, medium y semi-bold).

- **Paleta de Colores Institucional:**
  - **Primario / Superficie Oscura:** `#1E1E2E` (Dark Slate / Alto Contraste)
  - **Acento Principal:** `#6366F1` (Indigo Vibrant / Nodos de Ruta y Acciones Primarias)
  - **Éxito / Recompensas:** `#10B981` (Emerald Green / Sellos Completados y Validaciones)
  - **Alerta / Cooldown:** `#F59E0B` (Amber / Ventana de Enfriamiento y Rachas)
  - **Fondo Base Claro:** `#F8FAFC` (Slate Light / Lectura Limpia)
  - **Fondo Base Oscuro:** `#0F172A` (Navy Deep / Modo Noche y Paneles de Control)
  - **Superficie de Tarjetas:** `#FFFFFF` (White Clean)

---

## 2. Mascota Oficial de Marca: "Fido"

- **Propósito:** Actuar como el guía carismático, asistente omnicanal y tutor lúdico de la plataforma.
- **Tonalidad Emocional:** Entusiasta, servicial, ingenioso y dinámico.
- **Directrices de Aplicación Visual:**
  - **Posición:** Esquinas superiores de navegación, encabezados de flujo guiado, modales de éxito y hojas inferiores de retroalimentación.
  - **Física de Animación:** Curvas elásticas (`spring physics`), micro-rebotes y partículas de confeti en hitos de celebración.
  - **Consistencia:** Mantener siempre las proporciones y colores corporativos (sin deformaciones ni alteraciones de silueta).

---

## 3. Directrices de UX Writing y Microcopy

- **Tono de Voz:** Cercano, motivador, conciso y orientado al beneficio inmediato del usuario.
- **Prohibición Estricta de Technical Binding y Prompt Echoing:**
  - Queda prohibido exponer nombres técnicos de transporte, sockets o nombres literales de requerimientos de base de datos en las interfaces (ej. Prohibido: *"CRUD de Usuarios"*, *"WebSocket Activo"*, *"Cooldown Status"*).
  - Emplear siempre microcopy de producto profesional (ej. *"Directorio de Clientes"*, *"Monitoreo en Tiempo Real"*, *"Tiempo de Espera para Próximo Sello"*).
- **Cero Emojis en Respuestas de API y Registros:**
  - Las respuestas JSON, códigos de error HTTP, mensajes devueltos por el backend y logs deben ser totalmente sobrios y libres de emojis.
