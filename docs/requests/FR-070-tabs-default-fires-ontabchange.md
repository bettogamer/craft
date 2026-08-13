# FR-070 — `Craft.Tabs:Create` dispara `onTabChange` con la pestaña por defecto

**Reportado por:** Coffer (SortedBags) — Ajustes ▸ Apariencia, 2026-07-31 (error in-game al abrir la
ventana de Ajustes la primera vez).
**Componente:** [`Craft/components/Tabs.lua`](../../Craft/components/Tabs.lua) —
spec [`docs/components/tabs.md`](../components/tabs.md)
**Tipo:** Inconsistencia de API (sembrar un valor inicial no debería notificar)
**Prioridad:** Media — hay workaround de una línea, pero el fallo es un error de Lua en la cara del
usuario y contradice al resto de la librería, así que se tropieza con él en el primer uso.
**Estado:** Abierto — Coffer lleva el guard de abajo desde hoy.

---

## Problema

Al final de `Create`, la pestaña inicial se activa por `SetActiveTab`, que **notifica**:

```lua
-- Tabs.lua:140-150
local defaultId = (not activeSource) and config.defaultTab or nil
if not defaultId and config.tabs and config.tabs[1] then
    defaultId = config.tabs[1].id
end
if defaultId then
    if activeSource then
        self:_applyActiveTab(defaultId)   -- silencioso
    else
        self:SetActiveTab(defaultId)      -- ← dispara onTabChange (prev=nil ~= id)
    end
end
```

Así que `onTabChange` corre **dentro de `Create`**, antes de que `Create` haya devuelto y, por tanto,
antes de que el consumidor haya terminado de construir nada. En Lua el patrón normal de builder es
declarar locales adelantados y asignarlos más abajo (los callbacks se cierran unos sobre otros), de
modo que el callback se ejecuta contra locales todavía `nil`:

```
Coffer/SettingsWin.lua:701: attempt to call a nil value
[Coffer/SettingsWin.lua]:701: in function '_onTabChange'
[Craft/components/Tabs.lua]:474: in function 'SetActiveTab'
[Craft/components/Tabs.lua]:148: in function 'Create'
```

Dos motivos para considerarlo un defecto y no una decisión:

1. **`Tabs` ya es silencioso en su otra rama.** Tres líneas más abajo, el bind reactivo pasa por
   `_applyActiveTab` justo para no notificar, y el comentario lo dice explícitamente: *"Binds through
   `_applyActiveTab` (not `SetActiveTab`) so a programmatic signal sync never fires `onTabChange` nor
   writes back into the signal"* ([`Tabs.lua:152-155`](../../Craft/components/Tabs.lua)). El mismo
   `Create` sirve semánticas distintas según el `defaultTab` sea literal o señal.
2. **El resto de la librería siembra en silencio.** `ToggleGroup` (`value=`), `Select` (`value=`),
   `Checkbox`/`Switch` (`checked=`) pintan el valor inicial sin llamar a su callback — un consumidor
   que migra una fila de `ToggleGroup` a `Tabs` (exactamente el caso de Coffer) hereda un disparo que
   antes no existía.

## Reproducción

```lua
local onChange           -- forward-declare, como en cualquier builder
local tabs = Craft.Tabs:Create(parent, {
    tabs = { { id = "a", label = "A" }, { id = "b", label = "B" } },
    defaultTab = "a",
    onTabChange = function(id) onChange(id) end,
})
onChange = function(id) print(id) end   -- nunca se llega aquí: Create ya reventó
```

## Propuestas

**A (recomendada) — sembrar siempre por `_applyActiveTab`.** Que la rama literal haga lo mismo que la
reactiva: pintar la pestaña activa sin notificar. Alinea `Tabs` consigo mismo y con `ToggleGroup`/
`Select`/`Checkbox`, y quien de verdad quiera el efecto inicial lo consigue llamando a su propia
función tras `Create` (que es donde ya tiene todo construido). Es *breaking* para quien dependiera del
disparo — pero depender de un callback que corre a mitad de la construcción del consumidor es
justamente lo frágil.

**B — `config.notifyDefault = true` (opt-in).** Mantiene el comportamiento actual para quien lo
quiera y cambia el default a silencioso. Más conservador, a costa de una opción más en la config.

En cualquiera de las dos, el spec debería decir **explícitamente si el valor inicial notifica** —
hoy no lo menciona y el consumidor se entera por un error de Lua.

## Mientras tanto (workaround en el consumidor)

Guard `nil` en el callback (Coffer, `SettingsWin.lua`, página Apariencia):

```lua
onTabChange = function(id)
  currentId = id
  if syncFor then syncFor(id) end   -- Create notifica antes de que syncFor exista
end,
```

Inofensivo aquí porque el builder llama a `syncFor(currentId)` al terminar de todos modos. Se
revertiría al cerrar este FR.
