# FR-149 — Texto centrado en su caja: aplicar a todos los componentes lo aprendido con Badge

**Solicitante:** Craft (lecciones de FR-140/FR-146 en Badge, 2026-11-13).
**Componente:** `Craft/theme/Theme.lua` (helper nuevo) y los componentes que centran texto en una caja:
Button, Toggle, ToggleGroup, Tabs, Select y Combobox (trigger), Menu (filas), Sidebar (filas),
Input, Avatar (iniciales), Checkbox/RadioGroup/Switch (label). Con texto que dimensiona la caja:
Label, Field, Tooltip, Section.
**Tipo:** Fidelidad shadcn / pixel-perfect (refactor transversal).
**Prioridad:** Media.
**Estado:** abierto. **Primero medir, después tocar** (ver «Método»).

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

## Criterio de aceptación

- Con la escala pixel-perfect, cada componente migrado da `|diff| ≤ 1` (1 solo cuando el hueco libre
  es impar), y todos los de un mismo alto dan el MISMO reparto en cualquier fila.
- Sin cambio de tamaño de caja en los componentes de alto fijo (Button `h-8`, etc.).
- Suite completa sin regresiones; un spec de píxeles enteros por componente migrado.

## Referencias

FR-140 (Badge, métricas), FR-146 §2 (centrado impar, medición registrada), `Craft/components/Badge.lua`
(`_recalcSize`, `CAP_NUDGE`, `LEADING`, `_remeasureNextFrame`), `docs/components/badge.md`,
`scripts/measure-text-centering.py`, CLAUDE.md bugs #2/#4.
