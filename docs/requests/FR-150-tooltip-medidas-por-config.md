# FR-150 — `Craft.Tooltip`: ancho, padding, huecos y tamaño de fuente por config

**Solicitante:** QuantumDungeonTools (Instance Tracker, tooltip «Detalle», 2026-11-13).
**Componente:** `Craft/components/Tooltip.lua` (`Show` / `Attach`, líneas estructuradas FR-127).
**Tipo:** API / extensión de opciones.
**Prioridad:** Media (el consumidor lo necesita para clavar su diseño; hoy tiene fallback).
**Estado:** ✅ implementado y verificado in-game (2026-11-13) — release v2.49.0.

---

## Necesidad

QDT pinta un tooltip de detalle con líneas estructuradas (`config.lines`, FR-127) agrupadas en
secciones: título de sección + filas `izquierda … derecha`. El diseño cerrado del consumidor pide
medidas que el tooltip no deja tocar, porque hoy son constantes del módulo:

| Medida | Diseño QDT | Craft hoy |
|---|---|---|
| Ancho | fijo 300 px | se ajusta al contenido, tope `maxWidth` (240 por defecto) |
| Padding | 12 × 12 | `PAD_H = 12`, `PAD_V = 6` |
| Hueco entre filas | 4 | `ROW_GAP = 2` |
| Hueco entre secciones | 10, **sin línea** | solo `separator = true` (línea + `SEP_GAP` 4) |
| Fuente de las filas | 12, medium | `FONT_SIZE = 12`, regular |
| Fuente de los títulos de sección | 11, semibold/medium | igual que las filas (o `title` = solo la primera línea) |

Con `maxWidth` el tooltip puede crecer hasta 300, pero no ocupar 300 si el contenido es más corto;
y el resto de medidas no tiene ninguna vía. El consumidor no puede (ni debe) editar la copia
vendoreada.

## Propuesta

Opciones nuevas, todas opcionales (sin ellas, el comportamiento actual no cambia):

- `config.width` — ancho FIJO del tooltip (incluye padding). Las dobles líneas reparten ese ancho
  (la izquierda se corta con `…` como hoy). Si se pasa junto a `maxWidth`, manda `width`.
- `config.padding` — `{ x = n, y = n }` (o un número para ambos). Por defecto `PAD_H` / `PAD_V`.
- `config.rowGap` — hueco entre líneas. Por defecto `ROW_GAP`.
- `config.fontSize` / `config.fontWeight` — para todas las líneas. Por defecto el tema.
- Por línea (`lines[i]`):
  - `gapBefore = n` — hueco extra antes de esa línea, sin dibujar hairline (secciones sin línea).
  - `size = n`, `weight = "medium"|"bold"|…` — sobrescriben los de config para esa línea
    (títulos de sección más pequeños).

## Criterio de aceptación

- Spec: con `width = 300` el frame mide 300 aunque el contenido sea más estrecho, y una doble línea
  larga corta la izquierda dentro de ese ancho.
- Spec: `padding`, `rowGap` y `gapBefore` cambian la altura medida en exactamente esos píxeles.
- Spec: `size`/`weight` por línea se aplican y vuelven al valor de config en el siguiente `Show`
  (el tooltip es singleton: nada se queda pegado, como `fontFlags` en FR-101).
- Demo en la página Tooltip del Browser: tooltip de secciones con ancho fijo.

## Fallback en el consumidor

QDT sigue usando `Craft.Tooltip` con sus medidas actuales (ancho por contenido, padding 12×6,
hueco 2, sin línea entre secciones). Cuando salga el build con este FR se re-vendorea y se pasan
las opciones.

## Referencias

FR-127 (líneas estructuradas), FR-101 (`fontFlags` por Show). Consumidor:
`QuantumDungeonTools/modules/InstanceTracker/wow/UI.lua` (`detailLines`, `attachDetail`); diseño en
el artboard «Detalle» del lienzo del Instance Tracker.

## Resolución

Implementado tal cual la propuesta en `Craft/components/Tooltip.lua` (estado por `Show` en `_m`,
resuelto junto a `fontFlags`). Decisiones:

- `fontWeight = "semibold"` usa el archivo **medium** (el tema solo trae regular/medium/bold).
- `size`/`weight` de una línea aplican a **las dos columnas**; el `title` sigue en medium salvo que
  lleve su propio `weight` (precedencia: línea > título > config).
- `gapBefore` se suma al `rowGap` (y al hueco del separador si lo hay); se ignora en la primera línea.
- `width` también vale en el modo texto plano, igual que `padding`/`fontSize`/`fontWeight`.

Specs: `tests/tooltip_spec.lua` → «Craft.Tooltip measures by config (FR-150)» (5 casos). Demo:
`Craft_Browser/pages/Tooltip.lua`, botones «Detalle (FR-150)» y «Mismas líneas, sin opciones».
