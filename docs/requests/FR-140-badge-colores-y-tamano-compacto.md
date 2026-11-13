# FR-140 — `Craft.Badge`: colores propios y tamaño compacto

**Solicitante:** QuantumDungeonTools (widget Instance Tracker, 2026-11-13).
**Componente:** `Craft/components/Badge.lua` (build 49, v2.47.0, la vendoreada en QDT @`ac2ebb3`).
Sigue a FR-026.
**Tipo:** Ampliación de API.
**Prioridad:** Media. **No bloquea:** QDT usa tags caseros (`newTag`/`setTag` en
`modules/InstanceTracker/wow/UI.lua`) hasta re-vendorear.
**Estado:** implementado en dev (2026-11-13, sin release). Sin preset `size = "sm"`: `.cn-badge` es de un solo tamaño en Lyra, así que se exponen solo los campos sueltos (el `className` de shadcn) y QDT guarda su tabla «sm» (`fontSize = 11, paddingX = 6, paddingY = 1`). **Corregido tras la primera prueba in-game (2026-11-13):** el alto salía de `GetStringHeight()` (≈ tamaño de fuente, sin interlineado) y la caja quedaba a ras; el desplazamiento de medio descendente (punto 3) dejaba el texto bajo; y los bold medían ~3 px de menos en el primer frame. Ahora: línea = `fontSize · 16/12` (leading de `text-xs`), texto centrado como el `h-5` sin desplazamiento, y re-medida al frame siguiente. `GetBaselineOffset` usa la proporción genérica de descendente 0.2.

---

## Necesidad

El widget de QDT es un HUD transparente sobre el juego, con etiquetas de solo borde, cada una de
su color y más pequeñas que un badge de ventana:

| Etiqueta | Texto | Borde | Tamaño de texto |
|---|---|---|---|
| Dificultad («Normal») | arena `#E6D8B8` | dorado `#F2B84B` al 22 % | 11 px Medium |
| PRIMERA VEZ | `#7FE3E6` | el mismo al 50 % | 11 px Bold |
| NUEVO RÉCORD −1:49 | turquesa `#3FD0D4` | turquesa | 11 px Bold |
| Instancias 8/10 · libre en 12:40 | dorado (o rojo a 10/10) | dorado al 50 % (o rojo) | 11 px Medium |
| RARO | `#93B4B2` | el mismo al 50 % | 9-10 px Medium |

Márgenes del diseño: `padding: 1px 6px` (RARO: `0 4px`); el alto sale del texto.

Hoy `Craft.Badge` no lo cubre:

- **Colores:** solo las 4 variantes, con los tokens del tema. `outline` da texto `t.foreground` y
  borde `t.border`, iguales para todas las etiquetas de un mismo contexto.
- **Tamaño:** todo fijo: `H = 20`, `FONT_SIZE = 12`, `PX = 8`.

Lo único que hace falta tocar sería privado (`_label`, `_fillSurface`, `_recalcSize`), y por eso
QDT mantiene su propia etiqueta. Esa versión casera ya tuvo sus fallos de centrado (texto 1-2 px
fuera por anclar en CENTER sobre un ancho impar y por el hueco del descendente). Badge además se
vuelve a medir tras la carga asíncrona de la fuente (bug #4), cosa que la casera no hace.

## Propuesta

1. **Colores por instancia** (`config` + setter), sobre cualquier variante:
   - `textColor` y `borderColor`: `{r,g,b,a}` o nombre de token; `fillColor` opcional (nil =
     el de la variante, o nada en `outline`).
   - `Badge:SetColors({ text=, border=, fill= })` para cambiarlos en caliente (p. ej.
     Instancias pasa a rojo a 10/10). Un campo nil vuelve al de la variante.
   - Siguen valiendo tras un re-theme: `_paint` usa el override antes que el token.
2. **Tamaño:** `size = "sm"` (preset compacto) y/o los campos sueltos `fontSize`, `paddingX`,
   `paddingY`, `fontWeight` (`"medium"`|`"bold"`).
   - Con `size`/`fontSize` el alto deja de ser `H = 20` y sale del texto:
     `ceil(alto de línea) + 2 * paddingY + 2 * px1`.
   - Propuesta de «sm»: 11 px, `paddingX = 6`, `paddingY = 1` (el `tag` del widget).
3. **Centrado del texto:** anclarlo a píxel entero (LEFT + `paddingX`, no CENTER) y bajarlo medio
   hueco de descendente para que se centren las letras, no la caja de línea. En QDT, con BettoGeo,
   el descendente es 192/932 de la caja (hhea; las métricas Win dan lo mismo, ~20 %) y la corrección
   es `-floor(alto * 0.206 / 2 + 0.5)`. Si Craft lo generaliza, que salga de la fuente del tema.
4. **(Opcional) Línea base expuesta:** `Badge:GetBaselineOffset()`: distancia del borde inferior a
   la línea base del texto, para alinear un badge por base con texto de otro tamaño (en QDT,
   PRIMERA VEZ va junto al reloj de 42 px).

## Criterio de aceptación

- Los cinco tags de la tabla se pintan con `Craft.Badge` igual que en el lienzo (colores,
  márgenes, alto) y con el texto centrado a ojo (no hay 1 px de más arriba ni a un lado).
- Cambiar el color en caliente (`SetColors`) y hacer un re-theme mantiene el override.
- Sin `size`/`fontSize` ni colores, el badge se ve exactamente como en v2.47.0 (sin regresión en
  Coffer ni en Craft_Browser).
- Tras la carga asíncrona de la fuente, el ancho y el alto se recalculan.

## Uso en QDT

`newTag`/`setTag` desaparecen. Cada tag pasa a ser
`Craft.Badge:Create(row, { variant = "outline", size = "sm", textColor = …, borderColor = … })`,
RARO con `fontSize = 10, paddingX = 4, paddingY = 0`, y los que cambian de color con `SetColors`.
El baseline de la fila del reloj usa `GetBaselineOffset()` si existe.
