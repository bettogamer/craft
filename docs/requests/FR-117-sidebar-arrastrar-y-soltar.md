# FR-117 · Sidebar: arrastrar y soltar en el árbol

- **Pide:** SMRT (módulo Auras, lista «Mis auras», fase A12g, 2026-10-17)
- **Componente:** `Craft.Sidebar` (`components/Sidebar.lua`)
- **Prioridad sugerida:** alta (bloquea A12g). Depende de FR-080 (pool) y FR-116 (selección).
- **Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-18), release v2.35.0. Todo lo propuesto. Decisiones: el texto de la fila que sigue al cursor es el **segundo retorno** de `onDragStart(id) -> ids, label`; `dropZones` por defecto `"thirds"` en ramas y `"split"` en hojas; el arrastre se activa con `onDrop`; deslizamiento `motionFast` (0,12 s) `motionEasing`; ESC no se captura en combate (`SetPropagateKeyboardInput` protegida). **Cambio pedido por el owner (2026-10-18), distinto de lo propuesto arriba:** las filas que viajan NO se ocultan ni la lista se cierra; se quedan en su sitio al 50 % y un fantasma sigue al cursor (patrón dnd-kit), y una rama plegada se abre tras 0,6 s de hover si acepta «dentro» (spring-loading), para elegir la posición exacta entre sus hijos. Además (owner, misma sesión): «después» de una rama abierta = antes de su primer hijo; al cancelar, el fantasma vuelve animado a su fila; y clic en una rama seleccionable la abre (o pliega si ya estaba seleccionada). Demo: §11 de `Craft_Browser/pages/Sidebar.lua`.

## Necesidad

Reordenar y mover auras entre grupos arrastrando, como WeakAuras: soltar **antes de**, **después de** o **dentro
de** una fila, con indicador, ESC para cancelar y arrastrando una o varias filas. El Sidebar no tiene nada de
arrastre (sin `RegisterForDrag`, filas privadas en `_sections/_itemFrames`), y `DragList` es plana y sin «dentro».

## Propuesta

Opciones de `Sidebar:Create` (todas opcionales; sin ellas, nada cambia):

- `draggable = function(id) -> bool` — qué filas se pueden arrastrar.
- `onDragStart(id) -> ids|nil` — el consumidor devuelve las filas que viajan (p. ej. la selección, o el grupo con su
  árbol); nil cancela. La fila pulsada sigue al cursor (con un texto opcional `dragLabel`, p. ej. «3 auras»); las
  demás que viajan se ocultan y la lista **se cierra sobre los huecos, animada**.
- `canDrop(ids, targetId, zone) -> bool` con `zone = "before" | "after" | "inside"`. El Sidebar calcula la zona por
  la posición del cursor en la fila; el consumidor declara qué zonas admite cada fila con
  `dropZones = function(id) -> "split" | "thirds" | "inside" | nil` (mitades antes/después, tercios con dentro en el
  centro, toda la fila = dentro, o no es destino). Las filas que viajan nunca son destino.
- Indicador: línea fina sobre/bajo la fila (before/after) o relleno de la fila (inside), con fundido corto; sin
  indicador si `canDrop` es falso.
- `onDrop(ids, targetId, zone)` al soltar sobre un destino válido. Soltar fuera, ESC o `CancelDrag()` → `onDragCancel()`
  y todo vuelve a su sitio sin llamar a `onDrop`.
- ESC solo se captura **mientras dura el arrastre** (no cierra la ventana; fuera del arrastre se propaga).
- Autodesplazamiento de la lista cuando el cursor está cerca del borde superior/inferior.
- Umbral de unos píxeles antes de empezar, para no confundir con un clic.
- Al recolocar filas tras `SetItems` (después de un drop o de un Subir/Bajar), deslizar las filas a su sitio nuevo en
  vez de saltar (Weave, ~0,15 s `outQuad`), como pide el proyecto consumidor.

## Fallback en el consumidor (mientras tanto)

Mover sin arrastre ya existe en SMRT (menú «Mover a grupo ▸», Subir, Bajar). El arrastre no se enseña hasta
re-vendorear.
