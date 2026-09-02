# FR-081 — `Craft.Tooltip.Attach`: re-adjuntar apila closures de `HookScript` para siempre (y hace disparar configs viejas)

**Reportado por:** auditoría de memoria de la librería del 2026-09-02 (a raíz de FR-079).
**Componente:** [`Craft/components/Tooltip.lua`](../../Craft/components/Tooltip.lua) —
`TT.Attach` / `TT.Detach`
**Tipo:** Bug (fuga acotada por llamadas, no por tiempo) + bug de corrección latente
**Prioridad:** Media. No es grande en bytes, pero es **imposible de evitar desde el consumidor**:
`HookScript` no se puede deshacer en WoW, así que quien re-adjunta no tiene ningún recurso.
**Estado:** Abierto.

---

## Problema

`Attach` engancha con `HookScript`, que es **aditivo y no se puede deshacer**. `Detach` no
desengancha (no puede): solo borra la marca del registro `_attached[frame]`, y las closures
sobreviven comprobándola:

```lua
function TT.Attach(frame, config)
    if _attached[frame] then
        TT.Detach(frame)          -- solo hace _attached[frame] = nil
    end
    ...
    _attached[frame] = true
    frame:HookScript("OnEnter", function() ... end)   -- ← DOS closures nuevas
    frame:HookScript("OnLeave", function() ... end)   --   en CADA Attach
end
```

Cada `Attach` sobre un frame ya adjuntado deja **dos closures más pegadas al frame para siempre**,
cada una capturando su propio `config`, su propio `delay` y el `frame`.

### La mitad de corrección

El guard `if not _attached[frame] then return end` sirve para el caso *detached*, pero **no**
distingue una closure vieja de la vigente: tras un re-`Attach`, `_attached[frame]` vuelve a ser
`true`, así que en un solo `OnEnter` corren **todas** las closures acumuladas y **cada una**
agenda su `C_Timer.After` con **su** config capturada. Gana la última por orden de ejecución, pero
todas se ejecutan y todas mueven `_pendingAnchor`. Con `delay` distintos entre adjuntos, el
tooltip puede acabar mostrando el texto de una configuración ya retirada.

`Craft.ToggleGroup` ya conoce el problema y lo esquiva: mantiene `seg._ttCfg` (una tabla creada
una vez por slot y **mutada**) y un flag `seg._ttOn` para no re-adjuntar
(`ToggleGroup.lua:160-183`). El comentario lo dice explícito: *"re-attaching stacks hook closures —
WoW can't unhook"*. Que un componente de la propia librería tenga que documentar el workaround es
la señal de que el arreglo va en `Tooltip`. Y aun así ToggleGroup **sigue** apilando una closure
por cada ciclo `Detach → Attach` de un slot cuyo tooltip aparece y desaparece.

## Fix propuesto

**Enganchar UNA sola vez por frame y guardar la config en el registro**, en vez de en la closure:

```lua
local _attached = {}   -- [frame] = config        (nil ⇒ detached, sin tooltip)
local _hooked   = {}   -- [frame] = true          (hooks ya instalados; nunca se limpia)

function TT.Attach(frame, config)
    _attached[frame] = config or {}
    if _hooked[frame] then return end             -- ← re-attach = swap de config, sin closures nuevas
    _hooked[frame] = true
    frame:HookScript("OnEnter", function()
        local cfg = _attached[frame]; if not cfg then return end
        ...  -- lee cfg.delay / cfg.text AQUÍ, en tiempo de show
    end)
    frame:HookScript("OnLeave", function() ... end)
end

function TT.Detach(frame)
    if not _attached[frame] then return end
    _attached[frame] = nil
    ...  -- cancelar el timer pendiente, como ahora
end
```

Con esto: `Attach` es **idempotente**, `Detach`/`Attach` no cuesta nada, y siempre gana la config
vigente (se lee en el momento de mostrar, no en el de enganchar).

Dos consecuencias que hay que decidir a propósito:

1. **`delay` pasa a leerse por invocación** (hoy se captura al adjuntar). Es lo correcto —
   permite cambiar el retardo con un `Attach` nuevo— pero es un cambio de comportamiento
   observable si alguien depende de lo contrario.
2. `_hooked` es una tabla indexada por frame que **nunca se vacía** (no hay forma de desenganchar).
   Debe ser **weak-keyed** (`setmetatable(_hooked, { __mode = "k" })`) — y lo mismo para
   `_attached` — para no retener frames abandonados. Hoy `_attached` tampoco es weak.

## Efecto colateral deseable

Con `Attach` idempotente, `ToggleGroup:_applySegTooltip` puede simplificarse: se le cae el flag
`_ttOn` y el comentario de tres párrafos que documenta el workaround.

## Relacionado

- **FR-079** / **FR-080** — la misma familia: *"reconstruir la UI no debe costar memoria"*.
