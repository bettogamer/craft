# FR-005 — Panel/Dialog: `movable` + `resizable` (ventana de config)

**Reportado por:** Sentry (consumer addon)
**Componente:** `Craft/components/Panel.lua` (y/o `Dialog.lua`)
**Tipo:** Feature Request
**Prioridad:** Alta — la ventana de configuración debe poder moverse y redimensionarse
**Estado:** 🔵 Propuesto

---

## Problema

`Panel`/`Dialog` muestran título/header pero **no** son movibles ni redimensionables (no hay
`StartMoving`/`StopMovingOrSizing` ni resize handle). La ventana de configuración de un addon necesita
ambas cosas como base.

## Caso de uso (Sentry)

La pantalla de configuración (`Sentry/docs/UI-DESIGN.md`) es una ventana grande con Sidebar + editor por
pestañas; el usuario necesita reubicarla y ajustar su tamaño.

## Solución propuesta

### API
```lua
Craft.Panel:Create(parent, {
  title     = "Sentry",
  movable   = true,    -- arrastrar por el header → StartMoving/StopMovingOrSizing
  resizable = true,    -- handle en esquina inferior-derecha; minWidth/minHeight opcionales
  minWidth  = 480, minHeight = 320,
  onMoved   = function(self, point, x, y) end,   -- opcional, para persistir posición
  onResized = function(self, w, h) end,          -- opcional
})
```
### Comportamiento
- `movable`: header como drag region; `SetUserPlaced` opcional.
- `resizable`: `SetResizable(true)` + handle; respeta `minWidth/minHeight`.

## Workaround actual (Sentry)

Envolver un `Panel` y aplicar `SetMovable/StartMoving` + un resize handle a mano (ya lo hacemos en
`Sentry/UI/ImportExport.lua`). Funciona pero duplica plumbing en cada consumer.

## Impacto

Es la mejora de **mayor impacto** para apps con UI (la usa toda la ventana). Additivo: sin `movable`/
`resizable` el comportamiento actual no cambia.
