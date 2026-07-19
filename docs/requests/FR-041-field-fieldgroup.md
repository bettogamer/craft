# FR-041 — `Craft.Field` + `Craft.FieldGroup`: unidad de formulario (label + control + ayuda/error)

**Reportado por:** Análisis de layout de las Form Cards al portar shadcn (Craft_Browser, 2026-07-18)
**Componente:** nuevos `Craft/components/Field.lua` (shadcn: `field` — `Field`, `FieldGroup`)
**Tipo:** Feature (nueva API pública — requiere aprobación del maintainer)
**Prioridad:** Media-baja (hay workaround: componer Label + control + Flex a mano)
**Estado:** 🟢 Implementado en `dev` (sin release). `Craft/components/Field.lua` (Field +
FieldGroup), tests `tests/field_spec.lua` (14), spec en `docs/components/field.md`, demo en
`Craft_Browser/pages/Field.lua` (grupo Layout del sidebar). Aprobado por el maintainer.
Pendiente: bump/release + re-vendoreo (owner) + verificación in-game.

---

## Problema

shadcn agrupa cada campo de formulario en un `Field` (label + control + descripción/error) y
apila varios con `FieldGroup` a un gap consistente. Craft no tiene esa unidad: hoy cada
formulario compone Label + control + textos a mano y calcula el apilado él mismo.

El caso concreto que lo destapó es el Form Card **"Payout Threshold"**
(`Craft_Browser/pages/Panel.lua`): las filas label→control→ayuda se montan combinando `Craft.Label`,
el control y — desde FR-040 — un `Craft.Grid` para el apilado vertical. Funciona, pero:

- El patrón "label + control + (descripción|error)" se repite en cada campo y no está encapsulado.
- El estado `error` no tiene un contenedor que coloree el label y muestre el texto de error de
  forma uniforme (hoy es responsabilidad ad-hoc del caller; ver FR-037, que resolvió el borde del
  control pero no el texto de error del campo).
- La orientación `horizontal`/`responsive` (label a la izquierda del control) no existe como
  concepto reutilizable.

**Escenario:** portar cualquier formulario de shadcn (Card + `FieldGroup`) → no hay componente que
exprese el campo como unidad; se cae a composición manual de Label + control + Flex/Grid + textos.

## Solución propuesta

Añadir `Craft.Field` y `Craft.FieldGroup` según el spec ya redactado en
[`docs/components/field.md`](../components/field.md). Puntos clave (detalle completo en el spec):

- **`Craft.Field:Create(parent, { label, description, error, orientation, control, ... })`** —
  compone `Craft.Label` + el control (recibido ya construido, se reparenta, NO se crea) + textos
  de descripción/error, apilados con `Craft.Flex`. `error` colorea el label a `t.destructive`
  (`data-[invalid=true]`) y pinta el texto de error.
- **`Craft.FieldGroup:Create(parent, { gap, width })`** — apila varios `field:GetFrame()` a gap
  consistente (base 28px; 16px anidado).
- **3 orientaciones**: `vertical` (default), `horizontal`, `responsive` (emula el container query
  `@md`=448px con hook `OnSizeChanged`, patrón Tabs).

Los valores base (gaps, tipografía) están confirmados contra el `.tsx` del registry; queda por
confirmar si **Lyra recalibra** densidades (precedente Badge/Card) vía `/update-design-tokens`.

## Alcance mínimo (MVP)

Aprobado en el spec solo **`Field` + `FieldGroup`**. Fuera de alcance (documentado en el spec):
`FieldSet`, `FieldLegend`, `FieldSeparator`, `FieldTitle`, sub-componentes standalone
(`FieldContent`/`FieldLabel`/`FieldDescription`/`FieldError` — se absorben en la config), y el
patrón "FieldLabel-como-tarjeta" (radio-card seleccionable).

## Consideraciones de implementación

- **Nuevos tokens de spacing** propuestos: `spacing2Xl=28`, `spacingXs2=6` — agregar a
  `design-reference.md §6` solo tras confirmar que Lyra no los recalibra.
- **Descripción multilínea con auto-altura** (RIESGO en el spec): medir `GetStringHeight()` tras
  `SetWordWrap(true)` exige el ancho FINAL antes de medir (CLAUDE.md bug #2). Mitigación: exigir
  `config.width` explícito cuando hay `description`, o exponer `Field:Relayout()` (patrón
  `Flex:Layout()` dev-triggered).
- **Field no crea el control** — lo reparenta (consistente con `Panel.footer`). El caller
  sincroniza el estado visual del control (p. ej. `control:SetError()` de FR-037).
- Reutiliza el auto-remeasure de fuente async de `Craft.Label` (CLAUDE.md bug #4) — no
  reimplementar remedición.

## Referencias

- Spec de diseño: [`docs/components/field.md`](../components/field.md)
- Relacionados: [FR-037](FR-037-error-border-focus-destructive.md) (borde error del control),
  [FR-040](FR-040-craft-grid-layout.md) (`Craft.Grid`, motor de apilado usado hoy en Panel).
