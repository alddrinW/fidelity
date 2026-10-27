# Banner de Fido: medidas e imágenes

## Los banners los sube el administrador
Desde **Administración → Banners del inicio** el administrador sube las imágenes del carrusel y controla qué ve el cliente. No hace falta una nueva versión de la app para cambiarlos.

| Qué decide | Cómo |
|---|---|
| La imagen | PNG, JPG, WEBP o GIF de menos de **1 MB**; medida recomendada **2000 × 648 px** (3.09:1). Otra proporción se recorta para llenar el banner. |
| Versión en inglés | Opcional: quien usa la app en inglés ve esta; si no hay, ve la principal. |
| Al tocarlo | Nada, *Invitar amigos*, *Juego de la semana*, *Tarjetas en venta* (Explorar), *Escanear* o un **enlace** http/https. |
| Cómo se ve | *Fundir con el fondo blanco* (para imágenes de fondo blanco como las del ingeniero) o esquinas redondeadas. |
| Cuándo | Encendido/apagado y un horario opcional (desde / hasta, con día y hora). |
| Orden | Con las flechas subir/bajar. Hasta **12** banners. |

Mientras no suba ninguno, salen los dos diseños que vienen con la app (abajo). **Al subir el primero, esos dos dejan de usarse**; los mensajes de Fido con nube (invitar, juego) siguen saliendo con su dato correcto. El servidor entrega al cliente solo los activos y dentro de su horario (`GET /banners?lang=es|en`); el administrador los gestiona en `/banners/admin`.

## Banners que vienen con la app (imágenes del ingeniero)
Mientras el administrador no suba banners, dos vienen como **imagen completa con su texto** (2000 × 648 px, proporción 3.09:1, ~130 KB, WebP):

| Archivo | Dice | Sale cuando |
|---|---|---|
| `fidelity_app/assets/images/banner_invitar_amigos.webp` | *Gana 1 punto · Invita a 3 amigos y canjea 1 punto en cualquier fidelytienda* | Invitar amigos está encendido con la regla de **3 amigos y 1 punto**, el cliente no tiene puntos de invitación por usar, y la app está en **español** |
| `fidelity_app/assets/images/banner_juega_y_gana.webp` | *Juega y gana · Juega los minijuegos y gana 1 punto y descuentos* | La app está en **español** y no hay un mensaje más específico del juego (si ya eligió negocio o el punto es otro, sale el mensaje con datos). También sale con el juego apagado o ya jugado: al tocarla abre el juego de la semana, que lo explica |

Se muestran completas (sin recortar) y **se funden con el fondo blanco de la pantalla**: los bordes donde Fido queda cortado (izquierda, arriba y abajo) se difuminan hacia el blanco, para que no se vea un rectángulo pegado (lo ideal sigue siendo pedir al diseñador las imágenes con fondo transparente); el alto se reserva por la proporción, así que no "salta" al cargar. Al tocarlas llevan a *Invitar amigos* / *Juego de la semana*. Como el texto va **dentro de la imagen**, solo salen mientras lo que dicen sea cierto: si el administrador cambia los amigos o los puntos, si el cliente ya eligió negocio o ya tiene puntos por usar, o si la app está en inglés, sale en su lugar el banner con Fido y nube (abajo), que sí se ajusta y se traduce. Para cambiar una imagen, reemplaza el archivo con el mismo nombre (mismas medidas). Para sumar otra, agrégala a `BannerImages` y al mensaje correspondiente en `fido_banner_carousel.dart`.

## Mensajes con datos (mismo estilo del ingeniero)
Los mensajes que cambian con cada cliente (*¡Premio listo!*, *Te falta 1 punto*, tarjetas en venta, juegos de los locales, y *Juego de la semana* / *Invita a amigos* cuando la imagen ya no vale) no pueden ser una imagen fija. Se dibujan con **el mismo estilo**: **el Fido de fieltro del ingeniero** a la izquierda (`assets/images/banner_fido.webp`, recortado de su banner, 745 × 648 px; sus bordes se difuminan al blanco igual que en las imágenes) y, a la derecha, el **título grande en Anton**, el texto en Jost light y un botoncito. Sin nube, sin recuadro y sin los stickers de antes.

| Pieza | Medida | Notas |
|---|---|---|
| Zona del banner | **432 × 152 dp** | Crece hasta 1.6 veces si el usuario agranda la letra del sistema. Fido ocupa como mucho el 42 % del ancho (se achica en celulares angostos). |
| Fido (`banner_fido.webp`) | 745 × 648 px | Sale del banner *Gana 1 punto*. Si el ingeniero entrega otro Fido, se reemplaza con el mismo nombre. |
| Texto | lo dibuja la app | Cambia con el precio, el local, los puntos y el idioma. Título de hasta 2 líneas y descripción de hasta 3. |

El botón puede ser negro, rosa o negro con letra rosa (`BannerTone`).

## Qué sale en el carrusel
Con el administrador sin banners propios, el cliente ve, en este orden, solo lo que aplica: *¡Premio listo!* · **Juega y gana** (la imagen del ingeniero; sale siempre en español, también con el juego apagado o ya jugado: al tocarla abre el juego de la semana, que explica su estado) · *Te falta 1 punto* · tarjetas en venta · juegos de los locales · **Gana 1 punto** (la imagen del ingeniero, si la regla es 3 amigos y 1 punto). Los dos banners del ingeniero salen juntos aunque no haya nada más, así el carrusel siempre se mueve.

## Para agregar un mensaje nuevo
Agrega un `FidoBanner` en `FidoBannerCarousel` (`lib/features/cards/widgets/fido_banner_carousel.dart`) con su `id`, `tone`, título, texto, botón y acción, y las traducciones al inglés en `strings_en.dart`.
