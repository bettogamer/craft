# FR-061 — `Craft.Menu:OpenAtCursor()` abre el panel desplazado del cursor

**Reportado por:** Coffer (SortedBags), M9 F2 — menú contextual de favorito (Alt+clic derecho en una
celda del grid); el usuario reporta in-game que "el menú sí se ve, pero no aparece donde está
apuntando el cursor", 2026-07-24
**Componente:** `Craft/components/Menu.lua` (`Menu:OpenAtCursor()` / `Menu:_doOpen()`)
**Tipo:** Bug (posicionamiento / escala)
**Prioridad:** Media (la ruta anclada `Open(anchor, opts)` funciona; `OpenAtCursor` es la afectada)
**Estado:** ✅ Cerrado — implementado y **verificado in-game** (2026-07-24, en dev): el menú abre bajo
el cursor. El cursor se convierte con la escala efectiva del frame al que el panel se ancla de verdad
(`scaleRef`, `UIParent` por defecto), leída en el mismo sistema de coordenadas que `panelBaseScale`;
`OpenAtCursor(scaleRef)` acepta un host con escala propia. Extra fuera del MVP: el `zoom-in-95` ya no
multiplica el offset del ancla (ver §Solución). Tests `tests/menu_spec.lua` (+3)

---

## Problema

`Menu:OpenAtCursor()` posiciona el panel con un **offset respecto al cursor** en vez de bajo el
puntero. La causa es que la escala usada para convertir la posición del cursor a coordenadas de
UIParent se lee del panel en el momento equivocado y del frame equivocado:

```lua
function Menu:OpenAtCursor()
    local s = self._panel:GetEffectiveScale() or 1   -- (1) escala del PANEL, leída AQUÍ
    local cx, cy = GetCursorPosition()
    self._anchorFrame    = UIParent
    self._anchorPoint    = "TOPLEFT"
    self._anchorRelPoint = "BOTTOMLEFT"
    self._anchorX        = (cx or 0) / s              -- (2) offset relativo a UIParent
    self._anchorY        = (cy or 0) / s
    self._panelSlideDir  = 1
    self:_doOpen(UIParent)
end
```

Dos problemas encadenados:

1. **Escala equivocada.** El offset se ancla a `UIParent` (BOTTOMLEFT), así que la conversión de
   `GetCursorPosition()` debe dividir por `UIParent:GetEffectiveScale()`, no por
   `self._panel:GetEffectiveScale()`. Cuando el panel corre a una escala distinta de UIParent, `s`
   no corresponde al sistema de coordenadas del ancla.
2. **Momento equivocado (escala stale).** `s` se lee **antes** de que `_doOpen` haga
   `self._panel:SetScale(self._panelBaseScale)`. En `OpenAtCursor`, `scaleRef = UIParent` →
   `panelBaseScale = 1`, pero `self._panel:GetEffectiveScale()` en (1) todavía refleja la escala del
   **open anterior** (p. ej. un `Open(anchor)` previo dejó `panelBaseScale = eff/uiEff ≠ 1`). El
   offset queda calculado con una escala que ya no es la que el panel tendrá al pintarse.

Se manifiesta en el **primer** consumidor de `OpenAtCursor` (Coffer M9 F2): todos los menús previos
de Coffer usan `Open(anchor, opts)` (section-sort, "Mover a", combobox add, detail menu), que sí
posicionan bien. Igual que FR-060, es un camino que pasó desapercibido en demos sin uso real.

## Solución propuesta

Convertir con la escala de **UIParent** (el frame del ancla), no la del panel, y no depender de la
escala aún-no-aplicada del panel:

```lua
function Menu:OpenAtCursor()
    local uiEff = UIParent:GetEffectiveScale() or 1
    local cx, cy = GetCursorPosition()
    self._anchorFrame    = UIParent
    self._anchorPoint    = "TOPLEFT"
    self._anchorRelPoint = "BOTTOMLEFT"
    self._anchorX        = (cx or 0) / uiEff
    self._anchorY        = (cy or 0) / uiEff
    self._panelSlideDir  = 1
    self:_doOpen(UIParent)
end
```

Como `_doOpen(UIParent)` fija `panelBaseScale = UIParent_eff / UIParent_eff = 1`, el panel queda a
escala 1 sobre UIParent y el offset en coords de UIParent cae exacto bajo el cursor. Verificar
también en un host con escala propia (Craft_Browser 0.75x): si el panel debe respetar esa escala,
el offset del cursor debe dividirse por la escala del frame al que finalmente se ancla, consistente
con el `panelBaseScale` que `_doOpen` calcula.

### 3. (Encontrado al implementar) El zoom de apertura multiplica el offset del ancla

Los offsets de `SetPoint` se interpretan en las unidades del **frame posicionado**, y el effect de
apertura anima `panel:SetScale(base * zoom)` con `zoom` 0.95→1. Con el offset de −2px de un
dropdown la deriva es 0.1px (invisible), pero el de `OpenAtCursor` es una coordenada de pantalla
completa: a zoom 0.95 el panel arranca al 95% de la distancia a la esquina inferior-izquierda y
"vuela" hasta el cursor durante la animación. Se divide el zoom fuera del offset en el effect
(`comp = 1/zoom`), de modo que el punto de ancla queda fijo y sólo escala el panel.

**Implementado:** `OpenAtCursor(scaleRef)` — `scaleRef` opcional (frame cuya escala adopta el
panel, mismo rol que `anchor` en `Open`; default `UIParent`). El offset se divide por
`scaleRef:GetEffectiveScale()`, que es exactamente la escala efectiva que el panel tendrá tras
`_doOpen(scaleRef)` (`panelBaseScale = refEff/uiEff`, panel hijo de UIParent → efectiva `refEff`).
`AttachContextMenu` sigue abriendo a escala `UIParent` (sin cambio de comportamiento).

### Aplicación en la spec / tests

- `docs/components/menu.md`: nota en `OpenAtCursor` sobre el sistema de coordenadas (cursor →
  UIParent-local vía `UIParent:GetEffectiveScale()`).
- `tests/menu_spec.lua`: con un `GetCursorPosition` y `UIParent:GetEffectiveScale` mockeados, assert
  de que `_anchorX/_anchorY` == cursor/uiEff (independiente de la escala previa del panel).

## Notas

- **Fallback en Coffer mientras tanto** (`Coffer/ItemButton.lua`, `openFavMenu`): en vez de
  `OpenAtCursor`, se ancla el menú a la **celda** con
  `menu:Open(button, { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", y = -2 })` — usa la ruta
  `Open()` probada y además lee mejor como menú contextual pegado al ítem. Se puede mantener incluso
  tras cerrar el FR (no bloquea), pero el FR arregla `OpenAtCursor` para el resto de consumidores.
- Relacionado: FR-060, FR-059 (otros caminos de Craft que solo Coffer ejercita de verdad).

## Alcance mínimo (MVP)

- Reescribir el cálculo de escala en `OpenAtCursor` (pocas líneas).
- 1 test de posicionamiento, 1 nota en spec.

## Referencias

- Implementación: [`Craft/components/Menu.lua`](../../Craft/components/Menu.lua)
  (`OpenAtCursor` `:604-614`, `_doOpen` `:616-642`, `panelBaseScale` `:626`)
- Consumidor: Coffer `Coffer/ItemButton.lua` (`openFavMenu`, M9 F2)
