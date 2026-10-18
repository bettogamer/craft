# FR-073 — `Craft.Dialog`: el zoom de apertura ROMPE la medida de texto de su contenido (todo `Label` con `maxWidth` elide)

**Reportado por:** Bis (addon de BiS para WoW 12.0.7) — modal "Elegir objeto" del `/bis`.
Síntoma del owner (2026-08-04): *"todos los labels en el modal están con ellipsis"*.
**Componente:** [`Craft/components/Dialog.lua`](../../Craft/components/Dialog.lua) —
spec [`docs/components/dialog.md`](../components/dialog.md)
**Tipo:** Bug (el contenido del consumidor se mide con la escala del tween, no con la real)
**Prioridad:** Alta — afecta a **cualquier** `Craft.Label` con `maxWidth` dentro de un `Dialog`,
que es el modo normal de poner texto en un modal. El fallo es silencioso y se ve como "el texto
no cabe" (bug del consumidor) cuando en realidad la caja se midió mal.
**Estado:** ✅ Implementado (2026-08-16, en `dev`) — **propuesta A** (reforzada) **+ C**, no B.
El efecto del zoom ya no aparca el frame en `motionZoomFrom` cuando está **cerrado y el tween no
anima**: escribe la escala base. El pop se conserva porque el tween arranca en `motionZoomFrom`
en el instante en que `_open` cambia.
**Por qué no B (contenedor animado):** en `Dialog` y `Window` el frame raíz es además la unidad
movable/resizable/clamped y todo (`_ringTex`, `_bg`, `_header`, `_content`, `_footer`, título,
close) cuelga de él; mover el zoom a un frame intermedio obligaba a reparentar y re-anclar el
componente entero, a cambio de cubrir solo el caso residual. Se combinó en su lugar con
[FR-068](FR-068-window-consumer-scale.md): `_baseScale` + zoom multiplicativo en **ambos**
componentes (`config.scale`, `SetBaseScale`/`GetBaseScale`), que ataca la causa de fondo que los
dos FR señalaban — la escala del frame raíz no es propiedad exclusiva de la animación.
**Residuo conocido y documentado:** medir texto *durante* los ~150ms de la animación sigue
saliendo mal; el orden normal (`refresh(); dialog:Show()`) no lo toca.
C aplicada en los dos sitios: `docs/components/dialog.md` (sección propia) y
`docs/components/label.md` (aviso general de que `maxWidth` mide con la escala efectiva, no solo
dentro de `Dialog`). **✅ Verificado in-game por el owner (2026-08-16, 12.1)** — página Dialog
del Browser, "Open measure test": tres labels con `maxWidth = 400` escritos con el diálogo
CERRADO; ninguno sale con "…". **Cerrado** — Bis puede devolver los `maxWidth` a los labels del
picker al re-vendorear.

---

## Problema

`Dialog` conduce el zoom de apertura (`zoom-in-95`) escribiendo la escala del frame raíz:

```lua
local scale = Weave.tween(
    Weave.computed(function() return self._open() and 1 or motion.motionZoomFrom end),  -- 0.95
    { duration = motion.motionFast, easing = ... })                       -- Dialog.lua:108-110
...
self._effects[#self._effects + 1] = Weave.effect(function()
    self.frame:SetScale(scale())                                          -- Dialog.lua:125-127
end)
```

Como `_open` arranca en `false`, el frame queda **aparcado en 0.95 mientras está cerrado**. Y
`FontString:GetStringWidth()/GetStringHeight()` de WoW **escalan con la escala efectiva del
frame**, así que todo lo que el consumidor escriba en el diálogo **antes de `Show()`** se mide
un ~5% corto:

```lua
-- Craft/components/Label.lua:115-141 (_recalcSize)
text:SetWidth(0)
local natural = text:GetStringWidth()      -- medido a 0.95 → 5% menos de lo real
local w = natural
if maxWidth and maxWidth < w then w = maxWidth end
if maxWidth then text:SetWidth(w) end      -- caja 5% estrecha → WoW trunca y añade "…"
```

Resultado: con `maxWidth`, **cada** label del modal elide, y elide *proporcionalmente* a su
longitud (3 caracteres en un nombre corto, 6 en una línea larga), que es la huella de un error
de escala y no de un `maxWidth` mal calculado. Los `Label` SIN `maxWidth` del mismo diálogo se
ven bien — no pinean el ancho, así que nada puede truncarlos. Ese contraste es el diagnóstico.

**Lo delator:** los mismos textos, con el mismo `maxWidth`, en la misma sesión, dentro de un
`Craft.Window` NO eliden. El modal era el único sitio del addon con "…" por todas partes.

### La propia librería ya lo tiene documentado… en otro componente

`Craft.Tooltip` sufre exactamente esto y lo resuelve reseteando la escala **antes** de medir:

```lua
-- Craft/components/Tooltip.lua:269-275
-- Measure/size at scale 1. The zoom effect parks the idle frame at motionZoomFrom
-- (0.95); WoW's GetStringWidth/GetStringHeight scale with the frame's effective
-- scale, so measuring at 0.95 undersizes the text box → ...
_tooltip:SetScale(1)
_layoutTooltip(config)
```

`Dialog` no hace nada equivalente, y a diferencia de `Tooltip` **no puede**: el contenido no es
suyo, lo rellena el consumidor cuando quiere (típicamente `refresh(); dialog:Show()`).

## Reproducción

```lua
local dlg = Craft.Dialog:Create(UIParent, { title = "Repro", size = "xl" })
local lbl = Craft.Label:Create(dlg:GetContent(), { text = "", maxWidth = 400 })
lbl:GetFrame():SetPoint("TOPLEFT", dlg:GetContent(), "TOPLEFT", 0, 0)
dlg:GetContent():SetHeight(40)

lbl:SetText("Ribbon of Coiled Malice")   -- ~165px de ancho natural, tope 400
dlg:Show()                               -- se dibuja "Ribbon of Coiled Mal…"
```

Escribir el texto **después** de que el tween asiente (p. ej. `C_Timer.After(0.3, ...)`) lo
arregla, lo que confirma la causa.

## Propuestas

**A (mínima) — no aparcar el frame fuera de la animación.** Que el efecto escriba `1` cuando el
tween no está animando y esté cerrado: el frame invisible no necesita estar a 0.95, y el pop
sigue saliendo porque el tween arranca en `motionZoomFrom` al abrir. Cubre el caso real (el
consumidor pinta con el diálogo cerrado y luego llama a `Show()`), es de dos líneas y no cambia
la API. **No** cubre escribir texto *durante* los ~150ms de la animación.

**B (recomendada, la de verdad) — animar un contenedor, no el frame raíz.** Igual que
`Menu`/`Popover`/`Select` con sus paneles: que el zoom viva en un frame intermedio y que
`_content`/`_header`/`_footer` cuelguen de algo que **nunca** cambia de escala. Así ninguna
medida de texto del consumidor depende del estado de la animación, ni antes ni durante. Es el
mismo movimiento que pide [`FR-068`](FR-068-window-consumer-scale.md) propuesta B para `Window`
(y las dos comparten el problema de fondo: **la escala del frame raíz no es propiedad exclusiva
de la animación**).

**C (complementaria) — dejarlo dicho.** Dos sitios:
1. `docs/components/dialog.md`: el contenido de un diálogo **cerrado** está a `motionZoomFrom`,
   así que medir texto ahí sale mal; documentar la vía buena.
2. `docs/components/label.md`: `maxWidth` mide con `GetStringWidth`, que depende de la escala
   efectiva → un `Label` dentro de un frame escalado elide antes de tiempo. Hoy no lo advierte
   nada y es una trampa para cualquier consumidor, no solo dentro de `Dialog`.

## Mientras tanto (workaround en el consumidor)

Bis **quitó `maxWidth`** de todos los labels del modal (`Bis/wow/UI.lua`, sección "the picker"):
sin `maxWidth` no hay `SetWidth` y por tanto no hay nada que truncar, y las filas del picker son
de 608px — más del doble de lo que mide el nombre de objeto más largo del juego. Es aceptable
ahí porque nada necesitaba elidir; **no** es una solución general (un texto que sí desborde se
dibujaría encima de lo que tenga a la derecha, que es justo el caso de
[`FR-071`](FR-071-label-wrap-fill-box.md)).

## Referencias

- [`FR-068`](FR-068-window-consumer-scale.md) — `Window`: el mismo zoom trata la escala del frame
  raíz como suya; ahí rompe la escala del consumidor, aquí rompe la medida de su texto
- [`FR-071`](FR-071-label-wrap-fill-box.md) — modos de ancho de `Label` (`maxWidth` = elide)
- [`FR-024`](FR-024-label-natural-size.md) — el frame de `Label` abraza el texto (origen de la medida)
- `Craft/components/Tooltip.lua:269-275` — el precedente que ya arregla esto dentro de la librería
