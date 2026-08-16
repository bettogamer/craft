# FR-068 — `Craft.Window`: el zoom de apertura PISA la escala que ponga el consumidor

**Reportado por:** Coffer (SortedBags) — Ajustes ▸ Tema ▸ Ventanas ▸ Escala (slider 0.5–1.5).
Owner, 2026-07-30: *"el window no respeta el scale cuando se inicia"*.
**Componente:** [`Craft/components/Window.lua`](../../Craft/components/Window.lua) —
spec [`docs/components/window.md`](../components/window.md)
**Tipo:** Bug (la escala del consumidor sobrevive hasta la primera apertura y desaparece)
**Prioridad:** Media — se puede sortear desde fuera (ver workaround), pero el patrón "escala de
ventana configurable" es de manual en un addon y hoy **no hay forma de hacerlo sobre el frame**.
**Estado:** ✅ Implementado (2026-08-16, en `dev`) — **propuesta A**, más la C (documentado en
`docs/components/window.md`). `config.scale` + `Window:SetBaseScale(s)`/`GetBaseScale()`; el
efecto del zoom escribe `_baseScale × zoom` vía `_applyScale()`, y el `SetPoint` del pivote
divide por esa escala **real** (no por el valor del tween), que era el detalle delicado que
señalaba el FR. Se aprovechó para arreglar de paso lo que reportaba
[FR-073](FR-073-dialog-zoom-breaks-child-text-measure.md) y que aquí también aplicaba: en
reposo-cerrada la ventana **ya no se aparca en `motionZoomFrom`**, así que medir texto antes de
`Show()` sale bien. Mismo tratamiento en `Craft.Dialog` (`config.scale` + `SetBaseScale`).
Documentada también la trampa de la geometría persistida (`GetLeft()`/`GetTop()` dejan de estar
en unidades de UIParent con escala ≠ 1). **✅ Verificado in-game por el owner (2026-08-16,
12.1)** — página Window del Browser: slider `SetBaseScale` + ventana con `config.scale = 1.3`,
comprobando que la escala sobrevive al cerrar y reabrir (que era el fallo real). **Cerrado**
salvo revertir el host
intermedio de Coffer al re-vendorear.

---

## Problema

`Window` anima la apertura/cierre con un zoom `0.95 → 1` (shadcn `zoom-in-95`) y lo conduce
escribiendo **directamente** la escala del frame raíz:

```lua
self._effects[#self._effects + 1] = Weave.effect(function()
    local s = zoom()
    local f = self.frame
    if not f then return end
    f:SetScale(s)                                        -- Window.lua:153
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER",
        (self._zoomBaseX or 0) / s, (self._zoomBaseY or 0) / s)
end)
```

`SetScale` es un valor **absoluto**, no un multiplicador: el efecto no compone con nada, asigna.
Cualquier `frame:SetScale(userScale)` que haga el consumidor vive hasta el siguiente tick del
tween — es decir, **hasta la primera apertura**. A partir de ahí la ventana se queda clavada en
el valor del zoom (1.0 en reposo, 0.95 mientras está cerrada).

Lo pérfido del síntoma es que *parece* que funciona: si el consumidor aplica la escala desde un
efecto reactivo atado al slider, **arrastrar el slider sí reescala** (el efecto vuelve a correr y
gana la última escritura del frame)… y se pierde otra vez en cuanto se cierra y se reabre la
ventana. De ahí el reporte como "no lo respeta **al iniciar**": al login se aplica la escala
guardada, la primera apertura la borra, y solo vuelve si tocas el slider.

## Reproducción

```lua
local w = Craft.Window:Create(UIParent, { title = "Escala", width = 400, height = 300 })
w:GetFrame():SetScale(1.4)
w:Show()      -- aparece a 1.0, no a 1.4
```

## Precedente DENTRO de la propia librería

`Menu`, `Popover` y `Select` ya resolvieron exactamente esto para sus paneles: guardan una escala
base y el zoom **multiplica** sobre ella en vez de reemplazarla.

```lua
self._panelBaseScale = eff / uiEff                       -- Menu.lua:699
...
self._panel:SetScale(base * zoom)                        -- Menu.lua:139
```

`Window` es el único componente animado que trata su escala como propiedad exclusiva.

## Propuestas

**A (recomendada) — `Window:SetBaseScale(s)` + zoom multiplicativo.** Un `self._baseScale`
(default 1, configurable también por `config.scale`) y el efecto pasa a
`f:SetScale(self._baseScale * s)`. `SetBaseScale` re-aplica en el acto. Cambio de pocas líneas,
sin ruptura de API y consistente con Menu/Popover/Select.

**Ojo con la matemática del pivote**, que es lo único delicado: `captureZoomAnchor` es
escala-invariante (deriva `s = f:GetScale()` y divide por `fe`), así que sigue devolviendo el
offset en unidades de UIParent — correcto. Pero el `SetPoint` del efecto divide por `s`, el valor
**del tween**, cuando lo que corresponde es la escala **real** del frame; con base ≠ 1 la ventana
quedaría desplazada por ese factor. El fix acompaña al de arriba: dividir por `self._baseScale * s`
(o, mejor, por `f:GetScale()` justo después de asignarla, que es la misma cifra y no puede
desincronizarse).

**B (alternativa mínima) — no tocar la escala del frame.** Mover el zoom a un frame contenedor
propio de la ventana. Más invasivo y con más superficie de anclaje; la A cubre el caso real.

**C (complementaria) — documentarlo en el spec.** Aunque se implemente A, el spec debería decir
explícitamente que **el frame raíz no acepta `SetScale` del consumidor** y cuál es la vía
(`SetBaseScale`). Hoy no hay nada que lo advierta y el fallo es silencioso.

## Mientras tanto (workaround en el consumidor)

Coffer cuelga cada ventana de un **host intermedio escalado** (`Frame` hijo de `UIParent`,
`SetAllPoints(UIParent)`) que se pasa como `parent` a `Window:Create`, y escala **ese** host:

```lua
local host = CreateFrame("Frame", nil, UIParent)
host:SetAllPoints(UIParent)
host:SetScale(userScale)
local win = Craft.Window:Create(host, { ... })
```

Funciona y —esto es lo interesante— **la matemática del pivote de Craft sigue saliendo bien** sin
tocarla: el frame conserva su propia escala (el zoom), la efectiva pasa a ser `zoom × userScale`,
y como `captureZoomAnchor` usa `GetScale()` (la escala **propia**, que Craft sí controla) el
offset capturado compensa la base y el centro no se mueve. Es decir, escalar el PADRE compone;
escalar el FRAME compite. Aun así es un rodeo: obliga a cada consumidor a inventarse un frame que
solo existe para llevar un número, y no es descubrible desde la API.

Un detalle que arrastra el workaround (y que la propuesta A también hereda): con la ventana
escalada, `GetLeft()/GetTop()` y los offsets de `SetPoint` dejan de estar en unidades de UIParent,
así que cualquier posición persistida hay que guardarla convertida (`× GetEffectiveScale() /
UIParent:GetEffectiveScale()`) o las ventanas saltan de sitio al cambiar la escala. Vale la pena
mencionarlo en el spec junto a `onMoved`.
