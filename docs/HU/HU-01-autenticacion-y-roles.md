# HU-01: Autenticación, Roles y Perfiles de Usuario

## Historia de Usuario
**Como** usuario de Fidelity (cliente o dueño de negocio),  
**quiero** registrarme e iniciar sesión con credenciales seguras y gestionar mi perfil,  
**para** acceder a mis tarjetas de puntos o administrar mi negocio en la plataforma.

## Criterios de Aceptación
1. El usuario puede registrarse con correo, contraseña, nombre completo y rol (`client` o `business`).
2. El sistema impide que un usuario se registre o se auto-asigne directamente el rol de `admin`.
3. Las contraseñas se almacenan encriptadas con bcrypt.
4. El inicio de sesión retorna un token JWT firmado y permite registrar el token de notificaciones FCM.
5. El usuario puede eliminar su cuenta y todos sus registros asociados mediante una transacción atómica.
