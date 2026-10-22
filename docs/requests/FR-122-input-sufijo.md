# FR-122 · Input: sufijo / prefijo de texto

- **Pide:** SMRT (módulo Auras, editor de triggers; diseño `docs/ux-diseno-2026-10-22-bossmod-timer.md` §4, 2026-10-22)
- **Componente:** `Craft.Input` (`components/Input.lua`)
- **Prioridad sugerida:** baja
- **Estado:** ✅ Implementado en dev (2026-10-22, [Unreleased]) — pendiente in-game

## Necesidad

El editor de auras de SMRT tiene muchos campos en segundos (tiempo restante, desfase, duraciones). Con la caja llena
se lee un «5» o un «0» sin unidad: el placeholder «Segundos» desaparece al escribir. shadcn lo resuelve con
`InputGroup` + `InputGroupAddon`: un texto apagado («s», «%», «px») pegado dentro de la caja, a la derecha o a la
izquierda, que no forma parte del valor.

## Solución propuesta

- `Craft.Input:Create(parent, { suffix = "s" })` y `{ prefix = "#" }`: texto en `mutedForeground`, mismo tamaño
  que el del input, dentro del borde; el área editable se acorta lo que ocupe.
- `SetSuffix(text)` / `SetPrefix(text)` (nil lo quita). Clicar el sufijo da el foco a la caja.
- Tema, foco y estados como el `Input` de hoy.

## Decisiones / límites

- `prefix` / `suffix` = `InputGroupAddon` + `InputGroupText`: `t.mutedForeground`,
  `t.fontMedium`, 12px. Ocupa el sitio del icono (8px del borde) o va tras el icono / antes del
  hueco del ✕; el texto editable empieza 4px después.
- Visible siempre, también con placeholder. Clicar el addon enfoca: los FontStrings no capturan
  ratón y el EditBox cubre todo el interior.
- El ancho se re-mide en `_applyTheme` (bug #4, fuente que asienta tarde).
- _Pendiente devtools Lyra:_ padding exacto del addon (`pl-2` vs `pl-3`); hoy reutiliza la
  geometría del icono.
- Demo: `pages/Input.lua`, filas «FR-122».

## Fallback en el consumidor (mientras tanto)

La unidad va en la etiqueta del campo: «Tiempo restante (s)», «Desfase (s)». Al llegar el build, la etiqueta vuelve a
«Tiempo restante» y la caja lleva `suffix = "s"`.
