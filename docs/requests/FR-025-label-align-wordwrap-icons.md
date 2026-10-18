# FR-025 — Label: `align ~= "LEFT"` sin `maxWidth` pinea el ancho y rompe texto con iconos incrustados

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/components/Label.lua`
**Tipo:** Bug
**Prioridad:** Media — hay workaround simple en el consumidor (no pasar `align`), pero el bug
sorprende a cualquiera que use `align="RIGHT"/"CENTER"` con texto que trae `|T..|t` incrustado
**Estado:** ✅ Implementado (2026-07-13, dev — pendiente de release). Fix exacto al propuesto:
`_recalcSize` solo hace `SetWidth` con `maxWidth`. Tests de regresión en `tests/label_spec.lua`;
spec actualizado (`docs/components/label.md`, fila `align` + nota). Pendiente verificar in-game
el edge multilínea (`\n` + align CENTER/RIGHT sin maxWidth).

---

## Problema

`Label:_recalcSize()` (`Label.lua`, tras FR-024) hace esto:

```lua
text:SetWidth(0)                      -- libera para medir natural
local natural = text:GetStringWidth()
local w = natural
if self._cfg.maxWidth and self._cfg.maxWidth < w then w = self._cfg.maxWidth end
if self._cfg.maxWidth or self._cfg.align ~= "LEFT" then
    text:SetWidth(w)                  -- ← se ejecuta también sin maxWidth, solo por align~=LEFT
end
self.frame:SetSize(w, text:GetStringHeight())
```

Con `align == "LEFT"` (default) y sin `maxWidth`, el FontString queda con `SetWidth(0)`
(auto, sin wrap posible) — comportamiento correcto.

Con `align == "RIGHT"` (o `"CENTER"`) y **sin** `maxWidth`, el código igual entra al `if` y
fija `text:SetWidth(w)` con `w` = el MISMO valor recién medido por `GetStringWidth()`. Esto no
aporta nada (el frame ya mide `w` de cualquier forma — con `maxWidth` ausente no hay una caja
más ancha contra la que justificar), pero sí **re-constriñe el FontString a su propio ancho
medido**, con `WordWrap` todavía en `true` (solo `maxWidth` lo apaga, arriba en `Create`).

Si el texto trae texturas incrustadas (`GetMoneyString`/`GetCoinTextureString` → `|T..|t` por
cada moneda), el ancho real renderizado de esas texturas puede no calzar exacto con lo que
`GetStringWidth()` reporta (sub-píxel / redondeo). Con el ancho pineado a ese valor y wrap
activo, el ÚLTIMO glyph/textura (el ícono de cobre, al ser lo último en el flujo) se desborda
a una segunda línea. Visualmente: `"219,879 |gold| 36 |silver| 79"` con el ícono de cobre
solo, en la línea de abajo.

## Caso de uso (Coffer)

`MoneyDisplay.Create` y los labels de dinero en `BankActions.CreateFooterMoney` — texto =
`GetMoneyString(...)` (oro/plata/cobre con iconos), anclados por la DERECHA (`align =
"RIGHT"` para que coincida visualmente con el viejo `SetJustifyH("RIGHT")` de la FontString
cruda que reemplazan). Sin `maxWidth` (no truncan, ver owner request 2026-07-10: mostrar el
monto completo). Cada footer con dinero mostró el cobre saltado a una segunda línea.

## Solución propuesta

`align ~= "LEFT"` solo debería re-aplicar `SetWidth` cuando también hay `maxWidth` (i.e. hay
una caja más ancha que el texto natural contra la cual justificar). Sin `maxWidth`, el frame
YA mide exactamente el ancho natural — justificar left/center/right dentro de una caja del
mismo ancho que el contenido no cambia nada visualmente, así que no hay motivo para
constreñir el FontString ahí. Condición sugerida:

```lua
if self._cfg.maxWidth then
    text:SetWidth(w)
end
```

(la rama `align ~= "LEFT"` sale del `if`; `SetJustifyH` ya se aplica una vez en `Create` y
sigue sin efecto visible hasta que haya una caja más ancha que el texto, que es exactamente
cuando `maxWidth` la crea).

## Workaround actual (Coffer)

No pasar `align` a los Labels de dinero (queda en el default `"LEFT"`) y lograr el
alineamiento visual anclando el **frame** por su punto `RIGHT` al padre (`domMoneyFrame:SetPoint("RIGHT", footer, "RIGHT", 0, 0)`) — como el frame ya abraza el ancho natural, el resultado visual es idéntico y evita el `SetWidth` pineado. Ver `Coffer/BankActions.lua`
(`CreateFooterMoney`) y `Coffer/MoneyDisplay.lua`.

## Impacto

Fix acotado a una condición en `_recalcSize`; no cambia la API pública. Riesgo: algún
consumidor que hoy dependa (accidentalmente) de que `align="RIGHT"` sin `maxWidth` fije el
ancho — improbable, ya que hacerlo no tiene efecto visual útil y sí el bug de arriba.
