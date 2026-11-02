# FR-134 · `Window`: acoplar una ventana a otra (anclaje que no sea el centro de la pantalla)

- **Pide:** SMRT (modo edición, panel «Elementos» de E7; owner, 2026-11-01). Vendoreado: Craft v2.43.0 (747be6e).
- **Componente:** `components/Window.lua` (`_captureZoomAnchor`, `_applyScale`, `SetPosition`, `EnableDragFrom`)
- **Prioridad sugerida:** media (SMRT funciona con un parche: re-acoplar a mano en cada cambio)
- **Estado:** cerrado — verificado in-game, v2.44.0

## Necesidad

El modo edición de SMRT tiene dos ventanas: el HUD (Guardar/Cancelar…) y, pegado a su derecha, un panel
lateral «Elementos» que **debe ir con el HUD**: si se arrastra el HUD, el panel lo acompaña; si el panel cambia
de alto (al plegar un grupo de la lista), crece o encoge **desde su borde superior**, que sigue alineado con el
del HUD.

Con `Window` no se puede: `_applyScale` re-ancla el marco por `CENTER` a `UIParent` en cada tick del zoom, y
`SetPosition(point, relTo, ...)` solo sirve para calcular ese centro una vez. Efectos medidos in-game:

- Al cambiar el alto con `frame:SetHeight`, la ventana encoge hacia su centro: el borde de arriba baja y deja
  de estar alineado con el HUD.
- Al arrastrar el HUD, el panel se queda donde estaba.

Lo mismo le pasa al propio HUD cuando crece (encoge/crece alrededor del centro).

Patrón general: inspector o paleta acoplada a una ventana principal (Figma, editores de layout), ventanas que
cambian de alto según su contenido.

## Propuesta

- `config.dock = { to = otherWindowOrFrame, point = "TOPLEFT", relPoint = "TOPRIGHT", x = 8, y = 0 }` (o un
  método `Window:DockTo(...)`): mientras está acoplada, la posición en reposo sale de ese anclaje (sigue al
  otro marco, también durante su arrastre) y el pivote del zoom se recalcula desde él.
- Cambiar el alto o el ancho de una ventana mantiene fijo su punto de anclaje en reposo (el TOP si se ancló por
  TOPLEFT), no el centro. Quizás un `config.growFrom = "TOP"` para ventanas no acopladas que crecen hacia abajo.
- Que `SetHeight` animado (o un `Window:SetSize(w, h, { animate = true })`) respete lo anterior.

## Parche actual en SMRT

`SMRT/wow/EditList.lua` `dock()`: llama a `SetPosition("TOPLEFT", hud, "TOPRIGHT", 8, 0)` después de cada
`SetHeight` (en cada tick de la animación de alto), en cada cambio de alto del HUD y en un `OnUpdate` mientras
la barra de título del HUD está pulsada (`HookScript` de `OnMouseDown`/`OnMouseUp`). Se quita al vendorear
el build que traiga este FR.

## Resolución (dev, 2026-11-02)

- El ancla que `_applyScale` re-escribe en cada tick del zoom ya no es siempre `CENTER`→`UIParent`: es un
  **ancla en reposo** `(point, rel, relPoint, x, y)`. Para que el pop siga saliendo del centro, el punto se
  desplaza `(P→C)·(base − s)` durante el zoom; en reposo el desplazamiento es 0, así que incluso un
  `frame:SetHeight` crudo deja quieto el punto.
- `config.growFrom` (default `"CENTER"`, idéntico a antes): punto que se queda quieto al cambiar de tamaño.
- `config.dock` / `DockTo(to, point, relPoint, x, y)` / `Undock()` / `IsDocked()`: el ancla en reposo es el
  host (Window o frame), así que WoW arrastra la ventana con él sin `OnUpdate`. Un acoplado no se mueve
  desde sus propios drag handles; `SetPosition`/`Center`/`Undock` lo sueltan.
- `SetSize(w, h, { animate = true })`: tamaño animado (`motionBase`) respetando el punto anterior.
- Demo: página Window del Browser, «Open HUD + docked panel». Tests en `tests/window_spec.lua`.
- En SMRT, `dock()` de `EditList.lua` pasa a ser `elements = Window:Create(..., { dock = { to = hud, x = 8 } })`
  + `hud` con `growFrom = "TOP"`; el `SetHeight` animado → `SetSize(nil, h, { animate = true })`.
