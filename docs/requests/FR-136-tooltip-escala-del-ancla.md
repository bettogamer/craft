# FR-136 — `Craft.Tooltip`: seguir la escala del ancla, como Menu/Popover/Select

**Solicitante:** Coffer (ajuste Tema ▸ Ventanas ▸ Escala, 2026-11-03).
**Componente:** `Craft/components/Tooltip.lua` (build 46, v2.44.0, la vendoreada en Coffer).
**Tipo:** Bug / inconsistencia entre overlays.
**Prioridad:** Baja. **No bloquea:** sin apaño en Coffer; los tooltips salen a escala de la UI.
**Estado:** cerrado — released en v2.45.0 (build 47), verificado in-game.

---

## Síntoma

Coffer escala sus ventanas desde un host propio (`SetScale` sobre un frame a pantalla completa bajo
`UIParent`, slider 0.5–1.5). Con la escala en 1.3, en la MISMA ventana:

- un `Craft.Menu` abierto desde un botón sale a 1.3 (bien);
- un `Craft.Select` / `Craft.Popover`, igual (bien);
- un `Craft.Tooltip` (por `Attach` o `Show`) sale a 1.0: más pequeño que el texto del botón sobre el
  que aparece.

Antes no se notaba porque esos tooltips eran `GameTooltip`, que tampoco escala. Al migrarlos a
`Craft.Tooltip` (FR-127) la diferencia con los menús queda a la vista.

## Causa

Menu, Popover y Select compensan la escala del contenedor del ancla: su panel vive en `UIParent`,
y al abrir calculan

```lua
local eff   = anchor:GetEffectiveScale()
local uiEff = UIParent:GetEffectiveScale()
self._panelBaseScale = eff / uiEff        -- Menu.lua:1170-1176, Popover.lua:221
```

y el zoom de apertura MULTIPLICA sobre esa base. El singleton del Tooltip no tiene base: en `_show`
hace `_tooltip:SetScale(1)` (Tooltip.lua:496) y el efecto de zoom interpola `motionZoomFrom → 1`
(Tooltip.lua:129-130).

## Propuesta

El mismo patrón que Menu:

1. En `_show`, calcular `TT._baseScale = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()`
   (bajo `pcall`: el ancla puede ser un frame de Blizzard, como el compartimento del minimapa).
2. El efecto de zoom pasa a `SetScale(TT._baseScale * lerp(zoomFrom, 1, alpha()))`, y el
   `SetScale(1)` previo a medir pasa a `SetScale(TT._baseScale)`, o se mide a 1 y se aplica la base
   después, lo que encaje con el margen anti-rewrap de Tooltip.lua:287-291.
3. `_positionTooltip` tiene que dar los offsets y el chequeo de bordes de pantalla en el espacio del
   frame escalado (igual que hizo Menu, el comentario de Menu.lua:209 avisa de que `SetScale` también
   escala el offset del ancla).

Sin opt-in: con un ancla a escala de la UI la base es 1 y nada cambia.

## Criterio de aceptación

- Ancla dentro de un contenedor con `SetScale(1.3)`: el tooltip se ve al 1.3, pegado al ancla y sin
  salirse de la pantalla en ninguno de los cuatro `side`.
- Ancla a escala normal: idéntico a hoy, pixel a pixel.
- Dos tooltips seguidos desde anclas con escalas distintas: el segundo no hereda la del primero.
