# FR-110 — `Craft.Slider`: el arrastre no termina si se suelta el botón fuera del pulgar

**Solicitante:** SMRT (módulo «Auras personalizadas», pestaña Display: sliders de ancho/alto, 2026-10-13).
**Componente:** `Craft/components/Slider.lua` (build vendoreado 2.32.0, `8b562e3`).
**Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-14), release v2.33.0. Incluye el opcional: pulsar la pista también arrastra (Radix). Repro en `Craft_Browser/pages/Slider.lua` (bloque FR-110).
**Tipo:** Bug.
**Prioridad:** Media. **No bloquea:** el valor sigue siendo correcto; el usuario lo «suelta» volviendo a hacer clic.

---

## Síntoma

1. Pulsar el pulgar del slider y arrastrar.
2. Con el botón aún pulsado, bajar el cursor hasta el componente siguiente (otro slider, un input…).
3. Soltar el botón ahí.

El slider **sigue moviéndose** con el cursor. Solo para al hacer clic y soltar de nuevo sobre el propio
slider. Visto in-game por el owner en 12.1.5.

## Causa

El fin del arrastre depende solo de `self._thumb:SetScript("OnMouseUp", …)` (Slider.lua ~l. 242). Si el
botón se suelta con el cursor sobre otro frame que acepta ratón, ese `OnMouseUp` no llega al pulgar, así
que `_dragging` queda en `true` y el `OnUpdate` que llama a `_updateFromCursor()` nunca se quita.

## Propuesta

No fiarse del `OnMouseUp`: en el propio `OnUpdate` del arrastre, comprobar el estado real del botón y
terminar el arrastre cuando ya no esté pulsado.

```lua
self._thumb:SetScript("OnUpdate", function()
    if not IsMouseButtonDown("LeftButton") then
        self:_endDrag()          -- mismo cuerpo que el OnMouseUp actual
        return
    end
    self:_updateFromCursor()
end)
```

- `OnMouseUp` del pulgar llama también a `_endDrag()` (idempotente).
- Ídem al ocultarse el slider (`OnHide`) para no dejar un `OnUpdate` vivo.
- Opcional, de paso: pulsar en la pista (no en el pulgar) podría iniciar también el arrastre (shadcn/Radix
  lo hace: pointerdown en la pista salta y sigue al cursor); hoy solo salta una vez.

## Test sugerido

Emular: `OnMouseDown` del pulgar → `IsMouseButtonDown` stub a `false` → un tick de `OnUpdate` → el script
`OnUpdate` es `nil` y `_dragging == false`.

## En SMRT mientras tanto

Sin apaño: es una molestia, no rompe datos. Se quita nada al re-vendorear.
