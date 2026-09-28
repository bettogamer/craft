# FR-100 — `Craft.Scroll`: desplazamiento horizontal (y en los dos ejes)

**Solicitante:** SMRT (módulo Timeline, planificador de CDs estilo Viserio, 2026-09-27).
**Componente:** `Craft/components/Scroll.lua` (+ `ScrollBar.lua`), v2.26.0 (`139bce1`).
**Tipo:** Feature.
**Prioridad:** Media. **No bloquea:** SMRT monta su propio `ScrollFrame` horizontal dentro del
módulo mientras tanto.

---

## Qué falta

`Craft.Scroll` solo desplaza en vertical. El hijo se fuerza al ancho del viewport
(`Scroll.lua:44` `self._child:SetWidth(self._scrollFrame:GetWidth())` y el `OnSizeChanged` de
`Scroll.lua:49-54`), así que un contenido más ancho que la vista se recorta y no hay forma de
llegar a él. No hay opción `orientation`/`horizontal` en el archivo, y `Craft.ScrollBar` solo
tiene carril vertical.

## Caso de uso

Una línea de tiempo: un lienzo de 1100-2000 px de ancho (varía con el zoom) dentro de una ventana
de ~900 px, con filas que además pueden desbordar en vertical. Es el patrón de cualquier tabla
ancha, Gantt, galería horizontal o lista de columnas, no algo propio de SMRT.

## Propuesta de API

```lua
local sc = Craft.Scroll:Create(parent, {
  width = 900, height = 400,
  orientation = "horizontal",   -- "vertical" (default, comportamiento actual) | "horizontal" | "both"
  onScroll = function(offsetX, offsetY) end,
})
sc:GetContent():SetSize(1800, 600)     -- el dev fija el tamaño del hijo en el eje que desborda
sc:SetHorizontalScroll(px) ; sc:GetHorizontalScroll()
sc:ScrollToX(px, { animate = true })   -- opcional
```

- `"horizontal"`: el hijo se ajusta al ALTO del viewport (espejo del caso vertical) y el carril
  va abajo.
- `"both"`: el hijo no se ajusta en ningún eje; dos carriles, con la esquina reservada.
- Rueda: vertical por defecto; `Shift+rueda` desplaza en horizontal (convención de web y del
  cliente). Con `orientation = "horizontal"` la rueda sola desplaza en horizontal.
- `Craft.ScrollBar` gana `orientation = "horizontal"` con los mismos tokens del carril actual.

## Criterio de aceptación

- `orientation` ausente = comportamiento idéntico al de hoy (sin cambio para los consumidores).
- Contenido de 1800 px en viewport de 900 px: el carril horizontal aparece, llega a los dos
  extremos y `onScroll` informa el offset X.
- Redimensionar la ventana recalcula el rango sin salto del contenido.

---

## Resolución — IMPLEMENTADO en dev (2026-09-28, pendiente verificación in-game)

- `Craft.ScrollBar` gana `orientation = "horizontal"`: riel abajo, mismos tokens y grosor,
  pulgar dimensionado por ancho, arrastre por X, esquina reservada por el final derecho.
- `Craft.Scroll` gana `orientation` (`"vertical"` default | `"horizontal"` | `"both"`),
  `GetContent()` (alias), `GetOrientation()`, `SetHorizontalScroll/GetHorizontalScroll`,
  `ScrollToLeft/ScrollToRight`. Rueda y `onScroll` como en la propuesta; en vertical
  `onScroll(offsetY)` no cambia. Resize recorta el offset X al nuevo rango.
- **No implementado:** `ScrollToX(px, { animate })` (marcado opcional; ningún offset de
  Scroll se anima hoy) — usar `SetHorizontalScroll`.
- Tests: 4 en `scrollbar_spec`, 10 en `scroll_spec`. Demo: página Scroll del Browser
  (lienzo 1800px + rejilla en dos ejes; onScroll imprime al chat).
