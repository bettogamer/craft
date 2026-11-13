# FR-143 — Sin ajuste a la rejilla en las texturas curvas (`Theme.smooth`)

**Solicitante:** Craft (revisión de NaowhForever, 2026-11-13).
**Componente:** `Craft/theme/Theme.lua` (helper nuevo), `Craft/theme/Shapes.lua` y sus usuarios
(Switch, Badge `pill`, Avatar), `Craft/icons/Icons.lua` (`Icons.Apply`), marcas de Checkbox/Radio.
**Tipo:** Calidad visual (pixel-perfect).
**Prioridad:** Media. **Primero medir:** si no hay defecto visible, se cierra sin código.
**Estado:** helper implementado en dev (2026-11-13, sin release); **adopción pendiente de medir**.
`Craft.Theme.smooth(tex)` (comprueba que los métodos existan) y el interruptor
`Craft.Theme.smoothCurves` (default `false`), que leen las esquinas de `Craft.RoundedSurface` (FR-141;
también `opts.smooth` por superficie). Banco en la página Pixels del Browser: misma píldora con ajuste ON
y OFF a ×0.64 / 0.71 / 0.9 / 1.0, x a medio píxel, y botón para cambiar el default. Si se ve mejora:
`smoothCurves = true` y extender a Switch/Avatar/`Icons.Apply` (este último solo si el banco lo
justifica); si no, se cierra sin más código. Regla para CLAUDE.md cuando se decida.

---

## Hipótesis

El cliente ajusta por defecto los vértices de cada textura a la rejilla de píxeles físicos. En
una tira de color de 1 px eso es justo lo que queremos, pero en una forma curva escalada (tapa de
píldora, disco de Switch/Avatar, icono Lucide a tamaño no nativo) puede desplazar el quad medio
píxel o deformar la curva con una escala de UI no entera. Craft no llama a `SetSnapToPixelGrid`
ni a `SetTexelSnappingBias` en ningún sitio.

NaowhForever aplica a todas sus texturas de forma (`Shared/UI/Parts.lua:38-43`,
`Core/Options/Widgets.lua:139-142`):

```lua
texture:SetSnapToPixelGrid(false)
texture:SetTexelSnappingBias(0)
```

y **nunca** a las tiras de color.

## Propuesta

1. **Banco de prueba en el Browser** (página Switch o Badge): mismas formas con y sin el ajuste, a
   `uiScale` 0.64 / 0.71 / 0.9 / 1.0, con zoom de captura. Decidir con lo que se vea.
2. Si mejora: `Craft.Theme.smooth(tex)` (comprobando que los métodos existan: `if tex.SetSnapToPixelGrid`)
   y aplicarlo en las tapas de `pill` y las máscaras/piezas de `Shapes`, el thumb/pill del Switch, el
   disco del Avatar, y en `Icons.Apply` solo si el banco muestra mejora también en iconos.
3. **Regla nueva** para CLAUDE.md: ajuste a la rejilla OFF solo en formas con mipmaps, ON (el default)
   en tiras de 1 px y rellenos rectos.

## Criterio de aceptación

- El banco documenta el resultado a las cuatro escalas (captura en el FR).
- Si se adopta: sin cambio en tiras ni bordes rectos; las curvas no «saltan» medio píxel al mover
  la ventana a escala no entera.

## Referencias

`docs/research/naowhforever-ui-patterns.md` §1.3; CLAUDE.md bugs #5/#6 (formas prefab, TRILINEAR);
FR-141 (anillo redondeado, mismo tipo de pieza).
