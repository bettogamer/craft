# FR-090 — `Craft.DragList`: el ancho sólo se lee al crear, la lista no puede seguir a una ventana redimensionable

**Solicitante:** SMRT (M1 F3a, panel de opciones, 2026-09-13).
**Componente:** [`Craft/components/DragList.lua`](../../Craft/components/DragList.lua) —
`DragList:Create` / `DragList:SetItems`
**Tipo:** Hueco de API (falta `SetWidth`, o respetar el ancho del frame).
**Prioridad:** Baja. No bloquea: el consumidor deja la lista a un ancho fijo dentro de una tarjeta
que sí se ensancha. Se ve raro, no se rompe.
**Estado:** ✅ **CERRADO** (2026-09-16) — implementada la **opción 1** (`SetWidth`) **y** la 2
(seguir al frame), porque son el mismo camino: ver *Resolución* al final.

---

## Problema

La ventana de opciones de SMRT es un `Craft.Window` con `resizable = true`. Sus páginas se
maquetan de nuevo cada vez que cambia el ancho: `Craft.Panel`, `Craft.Label` en modo caja
(`SetWidth`), `Craft.Input` (reacciona a `OnSizeChanged`) y `Craft.Slider` (su track sigue al
frame) se adaptan todos.

`Craft.DragList` no. `Create` guarda `config.width` en `self._cfg.width` (`DragList.lua:38`) y lo
aplica al frame una vez (`:62`); la reconstrucción de filas vuelve a leer `self._cfg.width`
(`:142`), no el ancho real del frame. Un `GetFrame():SetWidth(w)` desde fuera estira el contenedor
pero las filas conservan el ancho viejo, y no hay API pública para cambiar `_cfg.width`.

## Por qué no hay apaño desde el consumidor

- `_cfg` es privado: tocarlo es depender de internos.
- Destruir y recrear la lista en cada redimensión pierde el estado de arrastre y el pool de filas
  (FR-079), y ocurre en cada frame mientras se arrastra la esquina de la ventana.

## Propuesta

Cualquiera de las dos, la primera es la de menos sorpresa:

1. **`DragList:SetWidth(w)`** — actualiza `_cfg.width`, el frame, y recoloca/redimensiona las filas
   existentes sin reconstruirlas (`renderRow` no necesita volver a correr: su `content` sólo cambia
   de ancho).
2. **Respetar el ancho del frame**: leer `self.frame:GetWidth()` al construir filas y enganchar
   `OnSizeChanged` para redimensionarlas, como hace `Craft.Input`.

## Criterio de aceptación

- Una `DragList` dentro de una ventana redimensionable, con `SetWidth` (o anclada por los dos
  lados), ensancha sus filas en vivo mientras se arrastra la esquina.
- Arrastrar para reordenar después de redimensionar sigue funcionando (bandas de cruce con el ancho
  nuevo).
- `renderRow` no se vuelve a llamar por un cambio de ancho.

## Fallback en SMRT mientras tanto

`modules/PrivateAuras/wow/Options.lua`: la lista de jugadores custom se crea al ancho mínimo de la
página (`PAGE_MIN_W - 2 * padding`) y no se ensancha. Al cerrarse este FR y re-vendorear, basta con
pasar `resize = function(w) custom.list:SetWidth(w) end` a su bloque.


---

## Resolución (2026-09-16)

Se implementaron **las dos propuestas**, que resultaron ser la misma con dos entradas. El ancho
de fila tiene una sola fuente de verdad (`_cfg.width`) y un único sitio donde se aplica
(`DragList:_applyWidth`); lo que cambia es quién lo llama:

1. **`DragList:SetWidth(w)`** (+ `GetWidth()`) — redimensiona el frame y aplica el ancho de
   inmediato, sin esperar a la pasada de layout de WoW.
2. **`OnSizeChanged` del frame raíz** — cubre la lista anclada por los dos lados, que nunca
   recibe un `SetWidth` del consumidor.

Los tres criterios de aceptación quedan fijados por tests (`tests/draglist_spec.lua`, 7 nuevos):

- Las filas visibles se ensanchan y las que se creen después heredan el ancho vigente, no el de
  `config`.
- El pool (FR-079) y las identidades de fila sobreviven, así que el arrastre sigue funcionando
  con las bandas de cruce del ancho nuevo.
- **`renderRow` no se vuelve a llamar**: un test cuenta las invocaciones a través de dos
  resizes. El `content` de la fila está anclado a los dos extremos, así que se ensancha solo.

Un guard de igualdad descarta el `OnSizeChanged` que dispara cada cambio de **alto** —
`_relayout` ajusta la altura en cada reorden—, así que llamarlo en cada frame mientras se
arrastra la esquina de la ventana es barato.

- Implementación: `Craft/components/DragList.lua` (`_applyWidth`, `SetWidth`, `GetWidth`).
- Spec: `docs/components/draglist.md` §*Ancho dinámico (FR-090)*.
- Demo: `Craft_Browser/pages/DragList.lua` → bloque FR-090, con un contador de llamadas a
  `renderRow` visible al lado para comprobar in-game que no se mueve al redimensionar.

**Para SMRT:** al re-vendorear, `modules/PrivateAuras/wow/Options.lua` puede pasar ya
`resize = function(w) custom.list:SetWidth(w) end`, tal y como anticipa el FR.
