# FR-124 · ToggleGroup: `type = "multiple"`

- **Pide:** SMRT (módulo Auras, pestaña Load; diseño `docs/ux-diseno-2026-10-23-load.md` §2.1.5 y §4 FR-B, 2026-10-23)
- **Componente:** `Craft.ToggleGroup` (`components/ToggleGroup.lua`)
- **Prioridad sugerida:** baja-media
- **Estado:** ✅ Implementado en dev (2026-10-24, [Unreleased]) — pendiente in-game

## Necesidad

La pestaña Load tiene multiselecciones de 2 o 3 opciones cortas: rol (Tanque, Sanador, Daño), posición (Cuerpo a
cuerpo, A distancia), facción (Alianza, Horda) y, en la fase siguiente, tipo de grupo y rango. Hoy van en un
`Select multiple` (FR-121), que esconde las opciones detrás de un clic. Con dos o tres opciones, verlas todas y
marcarlas de un clic es más claro.

`togglegroup.md` dice que la selección múltiple «no se implementa» por falta de caso de uso: este es el caso.

## Solución propuesta

- `Craft.ToggleGroup:Create(parent, { type = "multiple", values = { a = true }, onChange = function(values) end })`:
  cada segmento alterna; `onChange` recibe una tabla nueva `{ [value] = true }` (vacía = ninguno).
- `SetValues(set)` / `GetValues()`; `type = "single"` (por defecto) igual que hoy.
- Relleno y animación por segmento como el single.

## Fallback en el consumidor (mientras tanto)

`Select multiple` con placeholder «Cualquiera» (`ui/LoadFields.lua`, `setRows()`).
