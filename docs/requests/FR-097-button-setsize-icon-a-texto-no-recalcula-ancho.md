# FR-097 — `Craft.Button:SetSize`: al pasar de `icon`/`icon-sm` a un tamaño con texto, el ancho se queda en el del icono

**Solicitante:** SMRT (página «Mis notas», footer que cambia a solo iconos cuando la ventana
es estrecha, 2026-09-18).
**Componente:** `Craft/components/Button.lua`.
**Tipo:** Bug.
**Prioridad:** Media. **No bloquea:** SMRT usa dos botones por acción (uno con texto y otro
de solo icono) y alterna cuál se ve.

---

## Reproducción

```lua
local b = Craft.Button:Create(parent, { text = "Activate", icon = "eye", size = "sm" })
b:SetText(""); b:SetSize("icon-sm")      -- 28x28, correcto
b:SetSize("sm"); b:SetText("Activate")   -- el frame sigue en 28 de ancho y el texto se desborda
```

Visto in-game: los botones del footer muestran «Activ», «Send», «Copy» y «Delete» pisándose
fuera de un botón de 28 px.

## Causa

`_applySize()` pone el frame en `s.w` (28) en los tamaños de icono, pero no toca
`_intrinsicWidth`, que se queda con el ancho de antes (el del texto). De vuelta en `sm`,
`_recalcWidth()` ve `currentW (28) ≠ _intrinsicWidth` y lo interpreta como un ancho
impuesto desde fuera (el guard de Craft.Flex, Button.lua:173-178). Así que respeta el 28 y
no recalcula.

## Arreglo propuesto

En `_applySize()`: al entrar en un tamaño de icono, poner `self._intrinsicWidth = s.w`. Al
salir, poner `self._intrinsicWidth = nil` antes de recalcular. El guard de Flex solo debe
tener en cuenta anchos que el propio Button no se haya puesto.

## Apaño actual en SMRT (a retirar al re-vendorear)

`SMRT/modules/Notes/wow/Editor.lua`, `dual()`: un par de botones por acción. Cuando esto se
arregle, se puede volver a un solo botón con `SetSize` + `SetText`.

## Resolución — CERRADO (2026-09-18, verificado in-game, released en v2.25.0)

Tal como diagnostica el FR, en la mitad que hacía falta: al entrar en un tamaño de icono,
`_applySize` fija `_intrinsicWidth = s.w`. El cuadrado de icono pasa a ser un ancho **propio** y,
de vuelta a un tamaño con texto, el guard de Flex ya no lo toma por uno impuesto desde fuera. No
hace falta el `nil` al salir: `currentW == _intrinsicWidth` basta para que `_recalcWidth`
recalcule, y así un ancho que Flex le haya puesto a un botón **de texto** se sigue respetando.

Implementación: [`Craft/components/Button.lua`](../../Craft/components/Button.lua)
(`_applySize`). Tests: `tests/button_spec.lua` — la reproducción del FR (falla sin el arreglo:
`expected 90 but got 28`) y la guarda de Flex en un tamaño con texto.

**Para SMRT:** se puede volver a un solo botón por acción con `SetSize` + `SetText`.
