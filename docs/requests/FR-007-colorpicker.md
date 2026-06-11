# FR-007 — ColorPicker / ColorSwatch

**Reportado por:** Sentry (consumer addon)
**Componente:** nuevo (`Craft/components/ColorPicker.lua` o `ColorSwatch.lua`)
**Tipo:** Feature Request
**Prioridad:** Alta — la presentación de Sentry es color-céntrica
**Estado:** ✅ Resuelto (2026-06-10) — `Craft.ColorSwatch` (swatch + checkerboard + label opcional) envuelve `ColorPickerFrame` nativo con alpha. `SetColor`/`GetColor`/`SetEnabled`. Ver `docs/components/colorswatch.md`.

---

## Problema

Craft no tiene componente de selección de color. Los formularios de Sentry necesitan elegir color (con
alpha) en muchos sitios.

## Caso de uso (Sentry)

Color del display de un aura, overrides de presentación por destino, y cambios de color en condiciones
("rojo cuando remaining<5"). Ver `UI-DESIGN §4`.

## Solución propuesta

### API
```lua
Craft.ColorSwatch:Create(parent, {
  color    = { 0.2, 0.6, 0.8, 1 },   -- {r,g,b,a}
  alpha    = true,                    -- permite editar alpha
  onChange = function(r, g, b, a) end,
})
```
### Comportamiento
- Muestra un swatch (cuadro de color) estilizado con tokens de Craft.
- Al click abre un selector. Puede envolver el `ColorPickerFrame` nativo de Blizzard (con soporte de alpha)
  y devolver el color vía `onChange`, o un picker propio si se quiere estilo Craft completo.

## Workaround actual (Sentry)

Botón swatch propio que abre `ColorPickerFrame` de Blizzard directamente. Funciona pero rompe el look de Craft.

## Impacto

Nuevo componente, additivo. Desbloquea toda la edición de color de la UI (M7.3/M7.5).
