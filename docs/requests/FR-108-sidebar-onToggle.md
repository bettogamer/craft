# FR-108 — `Craft.Sidebar`: avisar al plegar/desplegar un nodo (`onToggle`)

**Solicitante:** SMRT (módulo «Auras personalizadas», editor: recordar qué secciones de la lista están plegadas, 2026-10-12).
**Componente:** `Craft/components/Sidebar.lua`.
**Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-12), sin release.
**Tipo:** Mejora.
**Prioridad:** Baja. **No bloquea:** SMRT guarda el plegado al cerrar la ventana y en `PLAYER_LOGOUT`.

---

## Qué falta

Un nodo `collapsible` se pliega por dos caminos y ninguno avisa al consumidor:

- El **chevrón** (`chevBtn` → `_toggleNode`) no llama a nada: ni `onSelect` ni `itemConfig.onClick`.
- El **clic en la fila** llama a `onSelect(id)`, pero **también** hace `SetActiveItem(id)`: la cabecera de la
  sección pasa a ser el item activo y la fila que el consumidor tenía seleccionada pierde el resaltado.

El consumidor que quiere persistir el plegado (ED-032 de la paridad con WeakAuras: «las secciones de la lista
recuerdan si están plegadas») tiene que leer `GetExpandedState()` en algún momento que adivina.

## Propuesta

Un callback opcional, sin romper lo que ya existe:

```lua
Craft.Sidebar:Create(parent, {
  onToggle = function(id, open) ... end,  -- nuevo: tras plegar/desplegar, por cualquier camino
})
```

- Se dispara al final de `_toggleNode` (chevrón, `ToggleNode`, `Expand`/`Collapse`) con el estado nuevo.
  **No** se dispara desde `SetItems` al restaurar la expansión (eso no es un gesto del jugador).
- Opcional, para el segundo punto: `itemConfig.selectable = false` en una rama, para que el clic en la fila
  la pliegue en vez de volverla activa (el patrón «cabecera de sección» de las listas de WA/NSRT).

## Apaño actual en SMRT (quitar al re-vendorear)

`modules/Auras/ui/Editor.lua`: el `onSelect` de una cabecera llama a `ToggleNode` + guarda + devuelve el
resaltado con `SetActiveItem(selected)`; el plegado por chevrón se guarda en `Editor.SaveState()`, que corre
al cerrar la ventana y en `PLAYER_LOGOUT`. Con `onToggle` todo eso se reduce a guardar en el callback.

## Resolución

- `onToggle = fn(id, open)` al final de `_toggleNode` (chevrón, `ToggleNode`, `Expand`,
  `Collapse`) y también cuando `SetActiveItem` abre ancestros plegados (es un cambio real que el
  consumidor perdería al persistir). Nunca desde `SetItems` ni `SetExpandedState`.
- `itemConfig.selectable = false` en una rama = cabecera de sección: el clic en la fila pliega
  (en shadcn el `SidebarMenuButton` **es** el `CollapsibleTrigger`), no cambia la selección, no
  dispara `onSelect` (sí `itemConfig.onClick` y `onToggle`).

- Código: `Craft/components/Sidebar.lua`.
- Tests: `tests/sidebar_spec.lua` — 5 casos.
- Demo: `Craft_Browser/pages/Sidebar.lua` §6 — rama «Secciones» con `selectable=false`;
  `onToggle` imprime en el chat.
