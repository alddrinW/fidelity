# Historia de Usuario: HU-11 - Activación Comercial "PAGA YA" y Jerarquía de Rol Aprobador

- **Identificador:** `HU-11`
- **Módulo:** Transaccional / Planes Comerciales / Control de Acceso RBAC
- **Prioridad:** Media-Alta

---

## 1. Declaración de la Historia
**Como** comerciante de la plataforma,  
**quiero** acceder al flujo de activación de suscripciones comerciales mediante el botón "PAGA YA" y delegar funciones operativas asignando el rol de "Aprobador" a supervisores de local,  
**para** habilitar funciones avanzadas de fidelización y mantener un control estricto sobre canjes y autorizaciones especiales.

---

## 2. Criterios de Aceptación (Gherkin)

### Escenario 1: Flujo de activación mediante PAGA YA
- **Dado** que un comerciante desea activar el plan Fidelity Pro o agregar nuevas sucursales,
- **Cuando** pulsa el botón "PAGA YA" en el panel comercial,
- **Entonces** debe desplegarse un asistente guiado por Fido que presente el resumen de características, desglose de costos y pasarela de pago segura con emisión inmediata de comprobante digital.

### Escenario 2: Asignación y elevación a Rol Aprobador
- **Dado** que un administrador comercial requiere supervisión en una sucursal,
- **Cuando** selecciona un colaborador en la sección de equipo y aplica la opción "Aumentar Rol: Aprobador",
- **Entonces** el usuario adquiere permisos exclusivos para validar canjes de premios especiales, anular transacciones erróneas y moderar sugerencias de clientes.

### Escenario 3: Telemetría e Integración API
- **Dado** que el comercio integra su sistema de punto de venta con la API de Fidelity,
- **Cuando** accede a la sección de configuración de integraciones,
- **Entonces** debe visualizar un semáforo de conectividad con latencia promedio, estado de webhooks y visor de eventos recientes.
