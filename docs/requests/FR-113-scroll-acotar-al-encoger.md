# FR-113 — `Craft.Scroll`: acotar el desplazamiento cuando el contenido encoge

**Solicitante:** SMRT (editor de «Auras personalizadas», pestaña Display, 2026-10-15).
**Componente:** `Craft/components/Scroll.lua` (build vendoreado 2.34.0, `CRAFT_BUILD = 36`).
**Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-18), release v2.35.0. `_clampOffsets()` en `OnScrollRangeChanged` y en el `OnSizeChanged` del ScrollFrame (vertical y horizontal). Demo: bloque FR-113 de `Craft_Browser/pages/Scroll.lua` («Al fondo» → «Quitar 10»). El Sidebar acota igual en cada maquetación.
**Tipo:** Bug.
**Prioridad:** Media. **No bloquea:** SMRT tiene un fallback (ver abajo).

---

## Qué pasa

Con el scroll al fondo, si el contenido encoge (en SMRT: borrar un sub elemento de un aura), el desplazamiento
vertical se queda por encima del nuevo máximo: la vista enseña espacio vacío bajo el contenido. Al pulsar la barra,
el desplazamiento se acota de golpe y la vista salta.

`OnScrollRangeChanged` (Scroll.lua ~l. 126) solo llama a `_updateScrollbar()`; nada acota
`GetVerticalScroll()` al nuevo `GetMaxScroll()`. `SetScrollOffset` sí lo acota, pero solo cuando alguien lo llama.

## Propuesta

En `OnScrollRangeChanged` (y donde cambie la altura del hijo), antes de `_updateScrollbar()`:

```lua
local maxScroll = self._bar and self._bar:GetMaxScroll() or 0
if self._scrollFrame:GetVerticalScroll() > maxScroll then
    self._scrollFrame:SetVerticalScroll(maxScroll)
end
```

Lo mismo en horizontal con `_clampHorizontal()`, que ya existe.

## Fallback en SMRT mientras tanto

`ui/Fields.lua` (`panel.paint`) llama a `scroll:SetScrollOffset(scroll:GetScrollOffset())` tras cada repintado y
otra vez en el frame siguiente. Se quita al re-vendorear la versión que lo arregle.
