# FR-123 · ToggleGroup: `deselectable` (desmarcar el segmento activo)

- **Pide:** SMRT (módulo Auras, pestaña Load; diseño `docs/ux-diseno-2026-10-23-load.md` §2.4 a y §4 FR-A, 2026-10-23)
- **Componente:** `Craft.ToggleGroup` (`components/ToggleGroup.lua`)
- **Prioridad sugerida:** media
- **Estado:** ✅ Implementado en dev (2026-10-24, [Unreleased]) — pendiente in-game

## Necesidad

La pestaña Load de SMRT tiene seis condiciones de tres estados (en combate, vivo, en encuentro, montado, en vehículo,
UI de vehículo): **Sí**, **No** o **Ignorar**. «Ignorar» es el valor vacío, y es el de casi todas: la pantalla debe
quedarse en silencio cuando no hay nada activo. Con un segmento «Ignorar» propio, cada condición ignorada lleva el
relleno de seleccionado siempre: seis controles «encendidos» que no dicen nada.

shadcn `ToggleGroup type="single"` permite **desmarcar** clicando el segmento activo (el valor pasa a vacío). Craft no:
`ToggleGroup.lua:286` hace `if self._value == value then return end`.

## Solución propuesta

- `Craft.ToggleGroup:Create(parent, { deselectable = true, ... })`: clic en el segmento marcado → `value = nil` y
  `onChange(nil)`. Sin la opción, el comportamiento de hoy (no cambia nada para los consumidores actuales).
- `SetValue(nil)` ya limpia; la animación del relleno, la misma que al cambiar de segmento.
- Teclado/foco como hoy.

## Fallback en el consumidor (mientras tanto)

Tres segmentos `[Ignorar][Sí][No]` (`ui/LoadFields.lua`, `tri()`), con el título de la fila apagado cuando está en
«Ignorar». Al llegar el build: dos segmentos `[Sí][No]` con `deselectable = true` y `get`/`set` traduciendo `nil`.
