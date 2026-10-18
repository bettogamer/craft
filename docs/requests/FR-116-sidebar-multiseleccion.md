# FR-116 · Sidebar: selección múltiple

- **Pide:** SMRT (módulo Auras, lista «Mis auras», fase A12f, 2026-10-17)
- **Componente:** `Craft.Sidebar` (`components/Sidebar.lua`)
- **Prioridad sugerida:** alta (bloquea la UI de A12f; junto con FR-080)
- **Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-18), release v2.35.0. `SetSelection`/`GetSelection`/`IsSelected`, config `selection` y `onClick(id, mods)` con `mods = { ctrl, shift, alt }`; mismo estado visual que el activo; `GetActiveItem()` = el último id. `SetItems` descarta solo los ids que existían y desaparecen (un id seleccionado antes de cargar se conserva). Demo: §11 de `Craft_Browser/pages/Sidebar.lua`.

## Necesidad

La lista de auras tiene que funcionar como la de WeakAuras: Ctrl+clic añade o quita una fila de la selección,
Shift+clic añade un rango, y el menú de clic derecho actúa sobre todas las seleccionadas. Hoy el Sidebar tiene un
solo `activeItem` (`Sidebar.lua:66,1053-1072`): el clic siempre hace `SetActiveItem(id)` y luego `onSelect(id)`
(`:737-739`), sin modificadores, y `_colorItem` pinta un único estado activo (`:385-452`).

## Propuesta

- `SetSelection(ids)` / `GetSelection()` → lista de ids resaltados con el mismo estado visual que el activo (o uno
  hermano, a elegir por el tema). `SetActiveItem(id)` sigue existiendo y equivale a `SetSelection({ id })`.
- Opción `onClick = function(id, mods)` con `mods = { ctrl = bool, shift = bool }` leídos en el clic
  (`IsControlKeyDown/IsShiftKeyDown`). Si el consumidor la da, el Sidebar **no** cambia la selección por su cuenta:
  la decide el consumidor y llama a `SetSelection`. Sin `onClick`, el comportamiento actual (compatible).
- `SetItems` conserva la selección por id (como ya hace con el plegado) y descarta los ids que desaparecen.
- `onContextMenu(id, frame, config)` sin cambios (el consumidor mira si `id` está en la selección).

La lógica de qué entra en la selección (solo hojas, rango del mismo padre…) es del consumidor; el Sidebar solo
pinta y avisa.

## Fallback en el consumidor (mientras tanto)

Ninguno visible: SMRT construye y prueba la selección en su núcleo puro y no la enseña hasta re-vendorear.
