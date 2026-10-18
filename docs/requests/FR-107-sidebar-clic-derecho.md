# FR-107 — `Craft.Sidebar`: clic derecho sobre un item (`onContextMenu`)

**Solicitante:** SMRT (módulo «Auras personalizadas», editor: renombrar/borrar un aura desde su fila, 2026-10-11).
**Componente:** `Craft/components/Sidebar.lua`.
**Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-12), sin release.
**Tipo:** Mejora.
**Prioridad:** Baja. **No bloquea:** SMRT pone botones Renombrar/Borrar en el pie de la lista mientras tanto.

---

## Qué falta

Las filas de `Craft.Sidebar` solo atienden el clic izquierdo (`onSelect`, `itemConfig.onClick`) y el
doble clic (FR-098). No hay forma de enterarse de un clic derecho. En una lista de documentos, «clic
derecho = menú de la fila» es lo esperado: el editor de auras de SMRT (paridad con WeakAuras) abre ahí
Renombrar, Duplicar, Exportar y Borrar.

## Propuesta

Un callback opcional, sin romper lo que ya existe:

```lua
Craft.Sidebar:Create(parent, {
  onSelect = function(id) ... end,             -- igual que ahora
  onContextMenu = function(id, anchor) ... end, -- nuevo: clic derecho sobre la fila
})
```

- `itemFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")` **solo cuando alguien escucha**
  (igual que `OnDoubleClick` en FR-098): un sidebar que no lo pide sigue ignorando el botón derecho.
- En `OnClick(self, button)`, `button == "RightButton"` llama a `onContextMenu(id, itemFrame)` y
  **no** cambia la selección ni dispara `onSelect` (el consumidor decide si selecciona). Hay que decidir
  si el clic derecho selecciona antes: WA sí selecciona la fila; proponemos dejarlo en manos del consumidor
  (puede hacer `SetActiveItem(id)` dentro del callback).
- `anchor` es el frame de la fila, para que el consumidor abra un `Craft.Menu` con `menu:Open(anchor, ...)`
  o `menu:OpenAtCursor()`.
- Filas deshabilitadas: no lo disparan. Filas con hijos (`collapsible`): sí, el menú de un grupo tiene
  sentido (renombrar el grupo).
- Opcional, por coherencia: `itemConfig.onContextMenu`, como `itemConfig.onClick`/`onDoubleClick`.

## Apaño actual en SMRT (quitar al re-vendorear)

Botones «Renombrar» y «Borrar» en el pie de la lista del editor de Auras, que actúan sobre la fila
seleccionada (mismo patrón que el botón Borrar de Mis notas). Cuando esto salga, el menú contextual se
añade sobre la fila y los botones del pie se quedan o se quitan según decida el owner.

## Resolución

Como la propuesta: `onContextMenu = fn(id, anchor, itemConfig)` global (el 3.er argumento, para tener `label` sin buscarla, se añadió tras la prueba in-game) e `itemConfig.onContextMenu = fn(id,
anchor, itemConfig)`. El botón derecho solo se registra si alguien escucha; **no selecciona**
(el consumidor llama `SetActiveItem` si quiere el patrón WA). Ramas sí, `disabled` no. El chevrón
de una rama reenvía el clic derecho a la fila (si no, el borde derecho de la fila lo tragaba).

- Código: `Craft/components/Sidebar.lua` (`AddItem`).
- Tests: `tests/sidebar_spec.lua` — 4 casos.
- Demo: `Craft_Browser/pages/Sidebar.lua` §6 — clic derecho abre un `Craft.Menu` en el cursor
  (Seleccionar / Renombrar / Borrar).
