# FR-132 · Token semántico `modified` (valor cambiado sobre el heredado)

- **Pide:** SMRT (módulo Auras, plantillas de aura A17b; críticas `docs/ux-critica-2026-10-30-overrides.md` y
  `docs/ux-diseno-2026-10-30-overrides-v2.md`, 2026-10-30). El owner aprobó crear el FR.
- **Componente:** el tema (`theme/Presets.lua`, `CraftThemeAxes.semantic`), junto a `warning`/`info`/`success` (FR-126)
- **Prioridad sugerida:** baja (SMRT ya funciona con una constante propia)
- **Estado:** ✅ Released v2.43.0 (2026-11-01) — verificado in-game

## Necesidad

En SMRT un aura hereda valores de una plantilla y puede sobrescribir campos sueltos. El título de un campo
sobrescrito se pinta en dorado (`#C7A65A`, el de los «spec overrides» de EllesmereUI) para que se lea de un
vistazo qué cambió. Es un estado semántico propio — «este valor difiere del heredado o del de por defecto» — que
no es `warning` (no avisa de nada malo), ni `info`, ni el acento `primary`. Hoy SMRT lo lleva como constante local,
fuera del tema.

Es un patrón general: cualquier ajuste con valor heredado (perfil global con sobrescritura local, opciones por
personaje sobre las de la cuenta, el `SetOverridden` de `Craft.Field` de FR-131).

## Propuesta

- Token **`modified`** (+ `modifiedForeground`) en `CraftThemeAxes.semantic`, mismo tratamiento que
  `warning`/`info`/`success`. Valor sugerido: `#C7A65A` (≈7:1 sobre el fondo de tarjeta oscuro).
- Opcional: que la marca de `Craft.Field` (FR-131) pueda teñir el título con él.

## Fallback en el consumidor (mientras tanto)

SMRT `SMRT/modules/Auras/ui/Fields.lua`: constante `OVERRIDE`. Al publicarse, sustituirla por `t.modified`.

## Resolución

- `modified` = `#C7A65A` y `modifiedForeground` = background neutral en `AXES.semantic` (`theme/Presets.lua`);
  fila en `docs/components/theme.md`, swatch en `Craft_Browser/pages/Theme.lua`, test en `tests/theme_spec.lua`.
- **No** se implementa el «opcional» (que la marca de `Craft.Field` tiña el título): shadcn no tiñe labels por
  estado y la marca ya comunica el override (FR-131). Si un consumidor quiere además el título dorado,
  lo pinta con `t.modified` en su propio label (Field no expone color de label; sería otro FR).

## Notas

De la misma revisión, menor: el tooltip de dos líneas de `Craft.Tooltip` deja las líneas casi pegadas (sin
interlineado), visto en la captura de SMRT. Si se confirma, va aparte.
