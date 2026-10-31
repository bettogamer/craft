# FR-131 · Marca de «valor cambiado» con botón Restablecer en un campo

- **Pide:** SMRT (módulo Auras, plantillas de aura A17b; diseño `docs/ux-diseno-2026-10-30-a17b.md` §2 y §7,
  2026-10-30). El owner aprobó crear el FR tras probar A17b in-game.
- **Componente:** `Craft.Field` (o un mixin común para `Label` / `Checkbox` / `ColorSwatch` / `Slider`)
- **Prioridad sugerida:** baja (SMRT ya funciona con un fallback propio)
- **Estado:** ✅ Released v2.42.0 (2026-10-30) — verificado in-game

## Resolución

En `Craft.Field` (no mixin): `SetOverridden(on [, tooltip])`, `IsOverridden()`, `OnReset(fn)`.
`tooltip` acepta un string o una config de `Craft.Tooltip` (`title`/`text`/`lines`). Los controles de
etiqueta en línea (Checkbox, ColorSwatch) se usan como `control` de un Field **sin** `label`: la marca va al
borde derecho, centrada en el control. Spec: `docs/components/field.md` §«Marca valor cambiado».
Demo: Craft_Browser → Field → sección 9. Tests: `tests/field_spec.lua` (sin Weave) y
`tests/field_override_spec.lua` (con Weave).

## Necesidad

En SMRT un aura puede heredar su aspecto de una plantilla y cambiar campos sueltos. Cada campo cambiado
lleva una marca que a la vez sirve de botón «Restablecer» (vuelve al valor de la plantilla). Es un patrón
general: cualquier ajuste con valor heredado o por defecto (perfil global con sobrescritura local, opciones
por personaje sobre las de la cuenta…). Hoy cada consumidor monta a mano un icono flotante por fila.

## Propuesta

```lua
field:SetOverridden(on [, tooltipText])  -- muestra u oculta la marca, con fundido
field:OnReset(fn)                        -- clic en la marca
```

- Botón ghost de 16×16 con el icono `rotate-ccw` (12 px) teñido con `t.primary`; con hover pasa a
  `t.foreground`.
- Anclado al borde derecho de la **primera línea** del campo: la del título, o la de la casilla o la
  muestra de color en los campos con la etiqueta en línea. Sin título, en el hueco a la derecha del control.
- **No cambia la altura ni el layout del campo** (flota). Cuando la marca está visible, el título se recorta
  su ancho para no quedar debajo.
- Tooltip por `Craft.Tooltip`, de varias líneas (FR-127): p. ej. «Restablecer a «X»» y debajo
  «Plantilla: 14».
- Fundido de entrada y salida con `Weave.tween` (`motionFast`, `outQuad`). Sin Weave, `Show`/`Hide`
  directos. Mientras sale no recibe clics.

## Aceptación

- Sin reflow al aparecer o desaparecer la marca.
- Llamar `SetOverridden(true/false)` repetido con el mismo valor no parpadea.
- Funciona en Slider (título encima), Select / Combobox / Input (título encima), Checkbox y ColorSwatch
  (etiqueta en línea).
- Documentado en `docs/components/field.md` con su conversión Lyra. Lyra no define este patrón: es de la
  familia «FieldDescription + icon-button» de shadcn y debe declararse así.

## Referencia del consumidor (fallback actual)

SMRT `SMRT/modules/Auras/ui/Fields.lua`: `markFor` (Button crudo + `Craft.Icons.Apply`), `markShow`
(fundido) y `place` (anclaje en la primera línea; regla 9 de la rejilla). Al publicarse el FR, SMRT
re-vendorea y sustituye su botón propio por el de Craft.

**Desviación respecto a la propuesta (aprobada por el owner, 2026-10-30): tamaño, no color.** El icono se
queda en `t.primary` (hover `t.foreground`) pero a **16 px en un botón de 20×20**, no a 12 px en 16×16. El
atlas hornea trazo 2.25 sobre 24: a 12 px sale ~1.1 px y a 14 px ~1.3 px, y con un color oscuro como
`primary` (emerald-800 en Lyra dark) casi no se veía (probado in-game). A 16 px (`size-4`, el icono de los
botones `icon`/`icon-sm` de shadcn) el trazo llega a ~1.5 px y el owner lo validó in-game. Se probó también
`t.mutedForeground` (más contraste, ~6.7:1 frente a ~2-2.4:1 de `primary` según el acento); el owner
prefirió `primary` porque la marca conserva el tinte del acento.
