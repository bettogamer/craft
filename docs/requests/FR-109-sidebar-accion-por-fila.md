# FR-109 — `Craft.Sidebar`: botón de acción por fila (`itemConfig.action`)

**Solicitante:** SMRT (módulo «Auras personalizadas», editor: el «ojo» de vista previa por fila, 2026-10-12).
**Componente:** `Craft/components/Sidebar.lua`.
**Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-14), release v2.33.0. `items[i].action` con el tamaño real de `SidebarMenuAction` (`w-5`/20px a `right-1`, no `size-6`); demo en `Craft_Browser/pages/Sidebar.lua` §10.
**Tipo:** Mejora.
**Prioridad:** Baja. **No bloquea:** SMRT pone un único botón de ojo en la cabecera del aura seleccionada.

---

## Qué falta

La lista de auras de WeakAuras tiene un **ojo en cada fila** (paridad ED-006/ED-098) que enciende o apaga la
vista previa de esa aura sin seleccionarla. `Craft.Sidebar` solo deja icono, avatar y tooltip por fila: no hay
manera de poner un botón pequeño a la derecha de la fila que reciba su propio clic.

## Propuesta

Un campo opcional por item, sin romper lo que ya existe:

```lua
{ id = "uid", label = "Mi aura",
  action = {                        -- nuevo
    icon = "eye",                   -- icono del atlas lucide
    tooltip = "Vista previa",
    active = true,                  -- pinta el icono en foreground; false = mutedForeground (apagado)
    onClick = function(id) ... end, -- NO selecciona la fila ni dispara onSelect
  },
}
```

- El botón vive en el borde derecho de la fila (tamaño `icon-xs` de shadcn, `size-6`), visible siempre (o solo
  al hover si `action.hover = true`, como `SidebarMenuAction showOnHover` de shadcn).
- Clic izquierdo en el botón → `action.onClick(id)`; no cambia el item activo ni abre el `onContextMenu`.
- `SetItems` lo repinta con los items nuevos (el consumidor cambia `active`/`icon` y vuelve a llamar).
- Referencia de diseño: shadcn `SidebarMenuAction` (sidebar.json new-york-v4).

## Apaño actual en SMRT (quitar al re-vendorear)

`modules/Auras/ui/Editor.lua`: un `Craft.Button` fantasma con icono `eye`/`eye-off` arriba a la derecha de la
vista del aura seleccionada (`w.eye`, `syncPreview`). Como la vista previa es solo la del aura seleccionada
(spec-A1a T-8), el comportamiento es el mismo; lo que se pierde es encender el ojo de un aura sin abrirla.
