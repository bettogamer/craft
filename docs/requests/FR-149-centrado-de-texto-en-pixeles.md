# FR-149 — Texto centrado en su caja: aplicar a todos los componentes lo aprendido con Badge

**Solicitante:** Craft (lecciones de FR-140/FR-146 en Badge, 2026-11-13).
**Componente:** `Craft/theme/Theme.lua` (helper nuevo) y los componentes que centran texto en una caja:
Button, Toggle, ToggleGroup, Tabs, Select y Combobox (trigger), Menu (filas), Sidebar (filas),
Input, Avatar (iniciales), Checkbox/RadioGroup/Switch (label). Con texto que dimensiona la caja:
Label, Field, Tooltip, Section.
**Tipo:** Fidelidad shadcn / pixel-perfect (refactor transversal).
**Prioridad:** Media.
**Estado:** en curso. **Paso 1 hecho (2026-11-13):** helpers `Theme.snapPx` / `lineHeight` /
`placeText` / `remeasureNextFrame` + Badge migrado sin cambio de geometría (`tests/textplace_spec.lua`,
`badge_spec` igual); escala pixel-perfect disponible en todas las páginas (`/craft pp`, botón en Pixels).
**Pasos 2-3 hechos y verificados in-game a 1:1 (2026-11-13):** Button, Select (trigger), Toggle y Tabs, todos
con el mismo reparto +1 de Button; de paso, scroll en píxeles enteros (`Theme.snapOffset`, rejilla del
scroll child) y `floor` con tolerancia en Flex/Grid. **Queda:** medir el resto de la lista (ToggleGroup,
Combobox, Menu, Sidebar, Input, Avatar, Checkbox/RadioGroup/Switch, Label/Field/Tooltip/Section) y migrar
solo lo que dé |diff| ≥ 2 o un 1 sistemático.
**Siguiente: medir in-game** Button, Toggle, Tabs, Select… con el «Método» y anotar la tabla aquí, antes
de migrar ninguno.

---

## Qué aprendimos con Badge (verificado in-game)

Hicieron falta tres vueltas de «arreglar a ojo» antes de medir los píxeles. Una vez medidos, el
diagnóstico salió en una. Estas son las lecciones:

1. **WoW pone la línea de Inter ~0.1 em más arriba que el navegador.** En CSS las mayúsculas de Inter
   quedan centradas en su caja de línea (ascender .969, descender .242, cap-height .727 → 3.6 px
   arriba y 3.6 abajo a 12/16). En WoW, el mismo texto anclado al centro sale con ~1 px más de hueco
   debajo que encima. Fix: bajar la etiqueta `round(0.1 · tamaño)`, que es 1 px a 10–14 px.
   Badge: `CAP_NUDGE`.
2. **La caja y el texto redondean a la rejilla cada uno por su cuenta.** Con un alto fraccional en
   píxeles físicos y un ancla `LEFT`/`CENTER`, el mismo componente salía de 17 o 18 px y su texto se
   desplazaba ±1 px según la fila en la que cayera. Fix: redondear el alto (y el ancho) a píxeles
   físicos enteros (`Theme.px`) y anclar el texto y el icono en `TOPLEFT` con un desplazamiento
   entero. Así, a escala pixel-perfect, todos los componentes salen idénticos.
3. **A escala NO entera el ±1 px que cambia de fila en fila es el redondeo del cliente**, no un bug
   de Craft (le pasa a toda la UI, Blizzard incluida). **No se persigue a ojo:** cada «arreglo»
   solo lo mueve de una fila a otra. Corregir la fase en tiempo de ejecución está descartado: se
   rompe con cada scroll. La referencia es siempre la escala pixel-perfect.
4. **`GetStringHeight()` NO es el alto de línea de CSS.** Devuelve aproximadamente el tamaño de
   fuente, sin interlineado. Una caja que se dimensiona con ese valor queda a ras de las letras. Fix:
   línea = `round(tamaño · 16/12)`, el leading de `text-xs`, o el leading del token que toque, y
   nunca menos de lo que mide el cliente.
5. **La primera vez que se rasteriza un peso a un tamaño, el ancho sale ~3 px corto** (Badge bold
   11 px quedó sin padding derecho). Fix: volver a medir una vez en el frame siguiente, con
   `C_Timer.After(0)` coalescido. Es complementario al bug #4 de CLAUDE.md, que trata la carga
   asíncrona del archivo, no el primer uso de un tamaño.

## Propuesta

1. **Helper en Theme** que reúna las lecciones 1, 2 y 5 en un solo sitio (hoy viven dentro de
   `Badge:_recalcSize`), por ejemplo:
   `Craft.Theme.placeText(fs, box, x, boxHeight, fontSize)` → ancla `fs` en `TOPLEFT` de `box`, con
   `x` y el desplazamiento vertical `(boxHeight − GetStringHeight)/2 + round(0.1·fontSize)`
   redondeados a píxeles físicos, y devuelve el desplazamiento usado (para la línea base o un icono).
   Más un `Craft.Theme.snapPx(v, frame)` para altos y anchos. Badge pasa a usarlo, sin cambio de
   geometría (su suite tiene que seguir igual).
2. **Medir antes de migrar** (ver «Método»), componente por componente. Solo se migra lo que salga
   con `|diff| ≥ 2` a escala pixel-perfect (o con 1 sistemático hacia el mismo lado, que es lo que
   tenía Badge).
3. **Migrar de uno en uno**, empezando por Button (el más visible). Cada migración lleva su spec
   (desplazamiento entero a escala ×0.71, como el test «whole-pixel layout» de `badge_spec`) y su
   captura de comprobación.

## Método (obligatorio)

1. `/reload`, abrir la página del componente y pulsar el botón **«Escala pixel-perfect»**
   (`CraftBrowser.PixelPerfectDemo()`; hoy solo está en la página Badge: moverlo al pie del Browser o
   a la página Pixels para que valga en todas).
2. Captura **sin reescalar**, y comprobar que una caja conocida mide lo que debe (Badge `h-5` = 20 px).
3. `python -I scripts/measure-text-centering.py shot.png "fila,y0,y1,x0,x1" …` → tabla de huecos
   arriba/abajo por caja. Juzgar solo texto sin descendentes ni tildes.
4. Anotar la tabla en este FR (antes/después).

## Mediciones

### Button — antes (2026-11-13; la captura resultó NO estar a 1:1, ver «después»)

| Fila | Caja (alto) | Texto juzgable | arriba / abajo | diff |
|---|---|---|---|---|
| Variants | 32 | Default, Destructive | 9 / 11 | −2 |
| Variants | 34 (outline) | Outline | 10 / 12 | −2 |
| Sizes | 32 | Default | 9 / 11 | −2 |
| With icon | **31** | Left / Right / Check | 8/9 · 8/8 · 8/10 | −1 · 0 · −2 |
| Disabled | 31 / 33 | Default / Outline | 9/10 · 10/11 | −1 · −1 |
| SetSize | **29 / 27** (sm = 28) | — | — | — |

Diagnóstico: texto 1 px alto sistemático (lección 1) y caja que no cae en píxeles enteros (31/33 en
`h-8`, 27/29 en `sm`; lección 2). «Secondary», «xs», «sm» y «lg» no se juzgan (descendentes o solo
altura de x). **Corrección posterior:** esta captura iba ~6 % por encima de 1:1 (outline `h-8` = 34
en vez de 32), así que el 31/33 de las cajas es en parte ruido de escala; el −2 del texto casa con lo
medido en Badge a 1:1 (lección 1).

**Migrado (dev, 2026-11-13):** alto/ancho con `snapPx`, texto con `placeText` (`TOP` en texto solo e
icon-only, `TOPLEFT` con icono), icono a desplazamiento entero, `translate-y-px` del press entero,
re-medida al frame siguiente. Spec «whole-pixel layout (FR-149)» en `button_spec`.

### Button — después

Captura a 1:1 verificada (outline `h-8` = 32, `sm` = 28). Ojo al calibrar: los botones **rellenos**
miden `h − 2` (default `h-8` = 30, `sm` = 26, `xs` = 22, `lg` = 34) porque Lyra lleva `bg-clip-padding`
con `border-transparent`: el fondo no pinta bajo el borde de 1 px. Es correcto, no es un bug. **Calibrar
siempre con un outline** (o con Badge `h-5` = 20).

| Fila | Caja | Texto | arriba / abajo | diff |
|---|---|---|---|---|
| Variants | 30 (relleno) | Default, Destructive | 10 / 9 | +1 (hueco 19, impar) |
| Variants | 32 (outline) | Outline | 11 / 10 | +1 (hueco 21, impar) |
| Sizes | 30 | Default | 10 / 9 | +1 |
| With icon | 30 | Left, Check | 9 / 9 | 0 |
| Disabled | 30 / 32 | Default / Outline | 10/9 · 11/10 | +1 · +1 |

Todas las cajas tienen su alto exacto en todas las filas, y todos los `h-8` dan el MISMO reparto (+1 con
hueco impar). **Button cumple el criterio de aceptación.** Queda «Activate» (`sm` + icono `eye`) en
7/5. **Bug destapado (corregido):** Button llamaba a `Icons.Apply` sin tamaño, así que todos los
iconos salían a 16 (`xs`/`icon-xs` debían ir a 12 y `sm` a 14). Con `CENTER` no se notaba; con el
ancla entera calculada para 12, el `icon-xs` quedaba 6/2 (4 px bajo). Medido: icon-xs 6/2 · icon-sm,
icon e icon-lg 0/0 (L/R simétricos en los cuatro). Ahora se pasa `s.icon`; spec en `button_spec`.
**Verificado in-game a 1:1:** icon-xs 6/6 (icono de 10 px de tinta), icon-sm 6/6, icon 8/8, icon-lg 10/10, L/R iguales; «Activate» (`sm` + eye) 8/8.

### Select, Toggle y Tabs — antes (2026-11-13, a 1:1: trigger `h-8` = 32, Button `sm` = 28)

Medido solo sobre mayúsculas/ascendentes (sin chevron ni descendentes). Referencia en la misma captura:
el Button «Healers» (ya migrado) da 12/11.

| Componente | Caja | Texto | arriba / abajo | diff |
|---|---|---|---|---|
| Select `h-8` (5 filas) | 32 | «S», «O», «G», «Pu» | 11 / 12 | −1 (todas) |
| Select `sm` | 28 | «Select…» | 9 / 10 | −1 |
| Toggle outline | 32 | «Outline» | 10 / 11 | −1 |
| Toggle pressed | 30 (relleno) | «On» | 9 / 10 | −1 |
| Tabs (activa, default y fill) | 26 | «Tab One», «Account» | 7 / 8 | −1 |

Todos dentro de ±1, pero **−1 sistemático**: el mismo texto en la misma caja sale 1 px más alto que en
Button (+1). Entra en el criterio «1 sistemático hacia el mismo lado» → migrar los tres con
`placeText` para que coincidan con Button y Badge.

**Migrado (dev, 2026-11-13):** Toggle (`_position`: `TOP` + cap nudge, alto/ancho `snapPx`, icono en
desplazamiento entero), Tabs (nuevo `_placeTrigger`, compartido por `AddTab` y la re-medida; `TOP` en
texto solo y en `fill`, `TOPLEFT` con icono en ancho de contenido) y Select (nuevo `_placeTriggerText`:
`TOPLEFT` + `TOPRIGHT` a la misma altura en vez de la caja `TOP`+`BOTTOM` con `JustifyV MIDDLE`; el
chevron en `TOPRIGHT` entero). Los tres re-miden al frame siguiente. Specs «whole-pixel layout
(FR-149)» en `toggle_spec`, `tabs_spec` y `select_spec`. Las filas del panel del Select NO se tocaron
(no se midieron). Esperado tras la migración a 1:1: Select `h-8` 12/11, `sm` 10/9, Toggle outline
11/10, Tabs 8/7 (mismo +1 de hueco impar que Button).

### Select, Toggle y Tabs — después

Capturas a 1:1 del owner (2026-11-13, 2560×1080: Select `h-8` = 32, Toggle outline = 32). Medido solo sobre
mayúsculas sin descendentes, con un reductor que limita la tinta a la columna de esas letras (el script
general mezcla el chevron y la «p» de «Option»).

| Componente | Caja | Texto | arriba / abajo | diff |
|---|---|---|---|---|
| Select `h-8` (9 filas, incl. disabled y `width=160`) | 32 | «Sel», «O», «G», «Pull», «A», «D», «C» | 12 / 11 | +1 (todas) |
| Select `sm` | 28 | «Sel» | 10 / 9 | +1 |
| Toggle outline | 32 | «Outline» | 11 / 10 | +1 |
| Toggle pressed | 30 (relleno) | «On» | 10 / 9 | +1 |
| Tabs (default, iconos, `fill`), página sin scroll | 26 | «T», «G», «A» | 9 / 8 | +1 (todas) |
| Tabs, misma página **scrolleada** | 26 | ídem | 10 / 7 | +3 (todas) |

Los tres cumplen el criterio a scroll 0, con el mismo reparto que Button. **Hallazgo:** con la página
scrolleada TODAS las filas de Tabs bajaban 1 px respecto a su barra. Causa: `Craft.Scroll` dejaba el
offset vertical fraccional (el máximo es contenido − viewport y el arrastre del thumb da cualquier
valor), así que toda la página se desplazaba una fracción de píxel y caja y texto volvían a redondear
cada uno por su cuenta (lección 2), también a escala pixel-perfect. **Fix (dev):** `Theme.snapOffset(v,
frame, max)` (píxel físico entero, sin pasar del máximo) en `ScrollBar:_setScroll`, que es el punto
único del arrastre, y todos los setters de `Scroll` (rueda, clamp, `ScrollTo*`, `SetScrollOffset`,
horizontal) pasan por él. Specs en `textplace_spec` y `scrollbar_spec`.

**Segunda vuelta (re-captura aún 10/7).** `/craft scrollprobe` (nuevo en el Browser) mostró que el
modo pixel-perfect escala SOLO el scroll child (`_demoFrame`, eff 0.7111) y no el ScrollFrame (eff 0.62),
y que **el cliente aplica el desplazamiento en unidades del child**: un offset de 591.828 desplazó el
contenido 591.83 px. `snapOffset` redondeaba con la rejilla del ScrollFrame (516 px «enteros» en la suya).
Fix: `ScrollBar:_setScroll` redondea sobre la rejilla del scroll child (`sf:GetScrollChild()`). Spec con
un child de escala propia. Nota: el rango (cliente y Craft) mezcla unidades del child y del frame cuando
sus escalas difieren; Craft sigue el rango del cliente, que es el que manda al hacer clamp.
**Tercera captura (2026-11-13):** la sonda da `offset = 592.0000 px` (entero). Tabs scrolleado: fill,
fill + iconos, RemoveTab y el 1.er renglón del wrap, **9/8 (+1) en todos**, igual que sin scroll. ✔

**Hallazgo extra:** el 2.º renglón del wrap salía 8/9: 1 px más alto que su trigger (renglones de texto a
25 px en vez de 26). Causa: `Craft.Flex` coloca con `-math.floor(yOffset)` y `lineHeight` sale de
`GetHeight()`, que con escala propia devuelve 25.99999 → `floor(28.99999)` = 28. Fix (dev): `pxFloor(v) =
floor(v + 1e-4)` en todos los `floor` de posición/tamaño de Flex y de Grid (misma clase). Spec en
`flex_spec`. **Verificado in-game:** los dos renglones del wrap, 9/8. ✔ Los scrolls propios de Select/Combobox/Menu/Sidebar/CodeEditor/Textarea
siguen llamando a `SetVerticalScroll` directamente (su rueda va en pasos enteros, pero el clamp al
máximo no): migrarlos si se mide el mismo efecto.

## Criterio de aceptación

- Con la escala pixel-perfect, cada componente migrado da `|diff| ≤ 1` (1 solo cuando el hueco libre
  es impar), y todos los de un mismo alto dan el MISMO reparto en cualquier fila.
- Sin cambio de tamaño de caja en los componentes de alto fijo (Button `h-8`, etc.).
- Suite completa sin regresiones; un spec de píxeles enteros por componente migrado.

## Referencias

FR-140 (Badge, métricas), FR-146 §2 (centrado impar, medición registrada), `Craft/components/Badge.lua`
(`_recalcSize`, `CAP_NUDGE`, `LEADING`, `_remeasureNextFrame`), `docs/components/badge.md`,
`scripts/measure-text-centering.py`, CLAUDE.md bugs #2/#4.
