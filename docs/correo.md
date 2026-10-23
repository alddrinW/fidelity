# Correo saliente (recuperar contraseña)

Fidelity manda dos correos, con la marca (franja rosa y código resaltado), en español o en inglés según el idioma de la app de cada persona:

- **Código para restablecer la contraseña** (6 dígitos, vence en 15 minutos).
- **Aviso de contraseña cambiada**: si la cambió alguien más, la persona sabe que debe actuar.

Sin SMTP configurado, en desarrollo el correo solo se escribe en el registro del servidor (así se puede probar el flujo). **En producción sin SMTP nadie puede recuperar su contraseña**: el servidor lo avisa en rojo al arrancar.

## Configurarlo con Gmail (5 minutos)

1. Usa una cuenta de Gmail **solo para Fidelity** (por ejemplo `fidelity.app@gmail.com`), no tu cuenta personal.
2. Activa la **verificación en 2 pasos** de esa cuenta (Google → Seguridad).
3. Entra a <https://myaccount.google.com/apppasswords>, crea una **contraseña de aplicación** (nómbrala "Fidelity") y copia las 16 letras. No es tu clave normal.
4. En `backend/.env` pon (los espacios de la clave se ignoran):

   ```
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   SMTP_USER=fidelity.app@gmail.com
   SMTP_PASS=abcdefghijklmnop
   MAIL_FROM=Fidelity <fidelity.app@gmail.com>
   ```

5. Comprueba que funciona (nunca muestra la clave):

   ```bash
   cd backend
   npm run mail:test -- tu@correo.com
   ```

   Primero verifica la conexión y las claves, y luego envía un correo de prueba (agrega `en` al final para verlo en inglés). Revisa también la carpeta de spam la primera vez.
6. Reinicia el backend. Al arrancar debe decir `Correo: SMTP configurado (smtp.gmail.com:587)`.

> Gmail deja enviar unos 500 correos al día: sobra para empezar. Cuando crezca, usa un servicio de correo transaccional (Brevo, Resend, Amazon SES o Mailgun): todos dan datos SMTP y se configuran con las mismas variables.

## Con un dominio propio

Si envías desde `no-reply@tudominio.com`, pide a tu proveedor los registros **SPF** y **DKIM** (y, si puedes, DMARC) y agrégalos en el DNS del dominio: sin ellos, muchos correos terminan en spam.

## Variables

| Variable | Para qué |
|---|---|
| `SMTP_HOST`, `SMTP_PORT` | Servidor (587 usa STARTTLS; 465 usa TLS directo) |
| `SMTP_USER`, `SMTP_PASS` | Usuario y contraseña (de aplicación, en Gmail) |
| `MAIL_FROM` | Remitente. Con Gmail debe ser la misma cuenta de `SMTP_USER` |
| `SMTP_SECURE` | Fuerza TLS directo (`true`) o no (`false`) |
| `SMTP_REQUIRE_TLS` | `false` solo para probar con un servidor local sin cifrado (por ejemplo MailHog) |

## Si algo falla

| Mensaje | Qué hacer |
|---|---|
| `Usuario o contraseña del correo rechazados` | En Gmail hace falta la **contraseña de aplicación** (paso 3), con la verificación en 2 pasos activa |
| `No se pudo conectar al servidor de correo (ETIMEDOUT/ECONNREFUSED)` | Revisa `SMTP_HOST` y `SMTP_PORT`; algunas redes bloquean el puerto 587 (prueba 465) |
| El código no llega | Mira el spam; el servidor registra `No se pudo enviar el correo a …` con el motivo |
| Llega, pero a spam | Falta SPF/DKIM del dominio (ver arriba) |
