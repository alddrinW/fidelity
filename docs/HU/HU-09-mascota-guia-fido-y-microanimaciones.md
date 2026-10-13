# Historia de Usuario: HU-09 - Mascota Guía "Fido" y Micro-Animaciones Contextuales

- **Identificador:** `HU-09`
- **Módulo:** Identidad Visual / Motion Design / Avatar de Marca
- **Prioridad:** Alta

---

## 1. Declaración de la Historia
**Como** usuario de la plataforma Fidelity (cliente o comerciante),  
**quiero** interactuar con la mascota oficial "Fido" mediante animaciones expresivas en cada evento clave de la aplicación,  
**para** recibir orientación amigable, refuerzo positivo inmediato y una experiencia inmersiva y humana.

---

## 2. Criterios de Aceptación (Gherkin)

### Escenario 1: Reacción festiva al escanear código QR
- **Dado** que un cliente escanea exitosamente un código QR en un establecimiento,
- **Cuando** la API confirma la validación de puntos,
- **Entonces** Fido debe aparecer en pantalla realizando una animación de salto de victoria con efecto de confeti radial y microcopy motivacional.

### Escenario 2: Orientación en caso de Cooldown activo
- **Dado** que un cliente intenta escanear antes de que venza el tiempo de enfriamiento,
- **Cuando** el sistema detecta la restricción temporal,
- **Entonces** Fido debe mostrarse en pose reflexiva junto a un reloj de arena animado explicando el tiempo restante de forma comprensiva y sin generar fricción.

### Escenario 3: Bienvenida personalizada para dueños de negocios
- **Dado** que un comerciante ingresa al panel administrativo,
- **Cuando** carga el panel principal,
- **Entonces** Fido debe dar la bienvenida en el encabezado ofreciendo accesos directos a la creación de campañas y monitoreo de sucursales.
