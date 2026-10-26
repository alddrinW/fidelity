# Banner de Fido: medidas e imágenes

Referencias visuales: `docs/designs/banner_fido_inicio.png` (el inicio con el banner) y `docs/designs/banner_fido_variantes.png` (los mensajes con cada pose y fondo). Son una vista previa generada por la app con tipografías de reemplazo, no un diseño final.

## Medidas
| Pieza | Tamaño | Notas |
|---|---|---|
| Zona del banner | **432 × 152 dp** = **1296 × 456 px** a 3x | Sin recuadro: solo Fido y su nube sobre el fondo de la pantalla. Crece hasta 1.6 veces si el usuario agranda la letra del sistema. |
| Fido (cada pose) | alto **126 dp** ≈ **380 px** a 3x | PNG con fondo transparente, ~300 px de lado hoy (poco para 3x: conviene pedir originales de 600 × 600 px o más). |
| Nube | la dibuja la app | Texto vivo (cambia con el precio, el local y el idioma). Título de hasta 2 líneas y descripción de hasta 2. |

## Poses (en `fidelity_app/assets/images/`)
| Archivo | Se usa para |
|---|---|
| `fido_cafe.png` | Tarjetas en venta |
| `fido_pulgares.png` | ¡Premio listo! |
| `fido_brazos.png` | Te falta 1 punto |
| `fido_laptop.png` | Juega y gana y Juego de la semana |
| `fido_idea.png` | Invita a un amigo |
| `fido_lapiz.png` | Sin uso todavía (por ejemplo, completar el perfil o el cumpleaños) |

Se recortaron de una hoja de stickers y se les quitó el fondo blanco; pesan 5 a 8 KB. Como no hay recuadro, Fido va sobre el fondo blanco de la pantalla. La nube puede ser rosa muy claro, rosa o negra.

## Para agregar un mensaje nuevo
Agrega un `FidoBanner` en `FidoBannerCarousel` (`lib/features/cards/widgets/fido_banner_carousel.dart`) con su `id`, `pose`, `tone`, título, texto, botón y acción, y las traducciones al inglés en `strings_en.dart`.
