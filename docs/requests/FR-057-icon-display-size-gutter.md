# FR-057 — `Craft.Icons`: el gutter del atlas se come el 12.5% del tamaño de display pedido

**Reportado por:** Observación del owner: el check del Checkbox se ve más pequeño en Craft que en la web (2026-07-20). Confirmado por análisis del código.
**Componente:** `Craft/icons/Icons.lua` (+ `scripts/export-icons.py` como contexto, NO se toca)
**Tipo:** Bug de fidelidad, sistémico (afecta TODOS los iconos)
**Prioridad:** Media-alta (impacto visual en toda la UI, pero el fix es de una línea)
**Estado:** ✅ Cerrado — implementado (Opción A) y **verificado in-game** (2026-07-20)

---

## Problema

El atlas rasteriza cada icono a **INNER = 56px** y lo pega centrado en una celda de **CELL = 64px**, con **GUTTER = 4px** transparente a cada lado (`scripts/export-icons.py:139-141`; render en `:563` vía `rasterize_svg(prepare_svg(svg), INNER)`, que escala el viewBox de 24 unidades a 56px).

Pero los texcoords de `Craft.Icons.Get` abarcan la celda **ENTERA**, gutter incluido: `left = col/DIVX + INSETX`, `right = (col+1)/DIVX - INSETX` (`Craft/icons/Icons.lua:62-66`), donde INSETX/INSETY son solo medio texel (despreciable). Y `Apply` hace `texture:SetSize(desc.size, desc.size)` (`Icons.lua:82`).

**Consecuencia aritmética:** al pedir un display de `size` px, WoW mete los 64px de celda en `size` px, así que el glyph real (56 de esos 64) se dibuja a `size × 56/64 = size × 0.875`. **El gutter se come el 12.5% del tamaño pedido.**

**Caso concreto que lo destapó:** `Checkbox` pide ICON_SIZE = 14 (`Craft/components/Checkbox.lua:14`, token Lyra `size-3.5` de `.cn-checkbox-indicator svg`) → el check se dibuja a **12.25px**. En web el `<svg>` mide 14px y el viewBox de 24 mapea a esos 14px completos, sin gutter que descontar.

## Alcance: es sistémico, no del Checkbox

TODAS las llamadas pasan el token Lyra crudo sin compensar, así que todos los iconos de Craft están un 12.5% pequeños. Call sites: `Badge.lua:69,91`, `Button.lua:328`, `Checkbox.lua:268`, `Combobox.lua:107,142,285,553,567`, `Dialog.lua:209`, `DragList.lua:242`, `Input.lua:81,97,117`, `Menu.lua:341,353,391,393,410`, `RadioGroup.lua:112` (lista no exhaustiva).

Además el contrato documentado NO se cumple: `docs/components/icons.md:143-144` promete que `size` es "el tamaño de display en px".

## Solución propuesta

### Opción A: Recortar el UV a la región interna (recomendada)

Recortar el UV a la región INTERNA (56 de 64) en `I.Get`, en vez de la celda completa: desplazar `left`/`top` hacia dentro y `right`/`bottom` hacia dentro en `GUTTER/CELL = 4/64` de celda por lado (en coordenadas de textura, dividido por DIVX/DIVY según el eje). Así el viewBox mapea al `size` pedido.

**Ventaja clave:** el footprint de la textura NO cambia (`desc.size` sigue siendo `size`), así que no se mueve ni un ancla ni un gap en ningún componente. El gutter sigue existiendo físicamente en el TGA cumpliendo su función de separar vecinos (bilinear + mipmaps); simplemente deja de mostrarse.

**Detalle técnico:** hay que mantener el inset de medio texel existente, sumado al recorte del gutter.

### Opción B: Agrandar la textura (NO recomendada)

Mantener el UV de celda completa y agrandar la textura: `SetSize(size * CELL/INNER, ...)` = `size × 1.1429`. Funciona pero cambia el footprint de cada icono un 14%, moviendo anclas y gaps en todos los componentes que posicionan alrededor del icono. Mucho más radio de impacto.

## Riesgos / a verificar antes de dar por cerrado

1. **Agranda TODOS los iconos de la UI a la vez** → necesita revisión in-game amplia, no solo del Checkbox.
2. **Puede haber ajustes previos que compensaban este bug a ciegas.** Sospecha concreta: FR-049 subió el chevron del Sidebar de 14→16 "porque se veía pequeño". Si se arregla la raíz, ese 16 puede quedar grande. Revisar los tamaños que se tocaron por criterio visual y no por token Lyra.
3. Verificar que el recorte de UV no reintroduce sangrado de celdas vecinas en el rango de display real (el análisis de mipmaps/TRILINEAR de `icons.md:58-60` y CLAUDE.md bug #5 dice que el gutter aguanta mip 0-2; recortar el UV deja MÁS margen, no menos, así que en principio es más seguro — pero conviene confirmarlo in-game).

## Alcance mínimo (MVP)

Si se elige **Opción A:**
- Cuatro líneas (left/right/top/bottom) en `Craft/icons/Icons.lua:62-66` para recortar el UV
- Actualizar `docs/components/icons.md` para que el contrato de `size` quede descrito como lo que realmente hace, y documentar por qué el UV recorta el gutter
- Revisión in-game de los componentes con iconos + revisión de los tamaños "ajustados a ojo" (punto 2 de riesgos)

## Implementación (2026-07-20)

Opción A. En `Craft/icons/Icons.lua` el inset por lado pasa de medio texel a
`(GUTTER + 0.5) / (DIV * CELL)` con `CELL = 64` / `GUTTER = 4` explícitos, así que el
recorte del gutter y la protección bilineal se suman en la misma constante y las cuatro
líneas de `Get()` quedan intactas. El span visible por eje pasa de la celda entera a
`55/64` (56 del glyph menos medio texel por lado). Documentado en `docs/components/icons.md`
(tabla del atlas, sección nueva "El UV recorta el gutter" y contrato de `size` en la API).
Test de regresión en `tests/icons_spec.lua` — verifica span y centrado en la celda; suite
405 verde, luacheck limpio.

**Verificación in-game (2026-07-20): OK.** Revisión amplia de la UI con los iconos ya
corregidos — sin regresiones. Los tres puntos de Riesgos quedan resueltos por observación:
no apareció sangrado de celdas vecinas (como se preveía: recortar el UV deja MÁS margen
para los mips, no menos), y los tamaños ajustados a ojo —incluido el chevron 14→16 de
FR-049, la sospecha concreta— se ven bien tal cual, así que no se revierte ninguno.

## Referencias

- Implementación: [`Craft/icons/Icons.lua`](../../Craft/icons/Icons.lua) (líneas 33–35 insets, 52–67 Get, 75–83 Apply)
- Generador del atlas: [`scripts/export-icons.py`](../../scripts/export-icons.py) (líneas 139–141 CELL/GUTTER/INNER, 563 rasterizado a INNER)
- Spec: [`docs/components/icons.md`](../components/icons.md) (líneas 41–60 tabla del atlas y supersampling, 143–144 contrato de `size`)
- Origen: auditoría de Checkbox, ver [`FR-054`](./FR-054-checkbox-indeterminate-check-icon.md) (mismo hilo, 2026-07-20)
