# FR-121 · Select: multiselección

- **Pide:** SMRT (módulo Auras, trigger «Boss mod» › Temporizador, spec-A5a, 2026-10-22)
- **Componente:** `Craft.Select` (`components/Select.lua`), o un `Craft.MultiSelect` hermano
- **Prioridad sugerida:** media
- **Estado:** ✅ Implementado en dev (2026-10-22, [Unreleased]) — pendiente in-game

## Necesidad

SMRT copia el editor de WeakAuras. WA tiene un campo de **selección múltiple** (`multiselect`): un desplegable cuyas
opciones son casillas, y que en la cabecera resume lo marcado («Pull, Cast»). Lo usa en «Bar Type» del Boss Mod Timer
(Pull / Break / Ability / Cast) y en muchos campos de carga (clases, especializaciones, roles, dificultades…), que
llegarán con la fase de Load de SMRT (A8).

Craft no tiene nada así: `Select` y `Combobox` eligen una opción y `ToggleGroup` dice expresamente que solo hace
selección única (`ToggleGroup.lua:51`). Hoy SMRT pinta una casilla por opción debajo del campo, y el owner ha señalado
que no se entiende de qué campo son.

## Solución propuesta

- `Craft.Select:Create(parent, { multiple = true, options, values = { [v] = true }, onChange(values) })` (o un
  componente aparte con la misma API que `Select`).
- El popover lista las opciones con una casilla (`Checkbox` o el check de `Menu`); clicar marca o desmarca **sin
  cerrar** el popover. Esc o clicar fuera lo cierran.
- La cabecera muestra lo marcado separado por comas, recortado con «…» si no cabe, o el `placeholder` si no hay nada.
- `SetValues(values)` / `GetValues()`; `onChange` recibe una tabla nueva `{ [value] = true }`.
- Mismo tamaño, tema, animación de apertura y teclado que `Select`.

## Decisiones / límites

- **`Craft.Select { multiple = true }`, no un componente aparte.** Norte shadcn: el `Select` de
  shadcn sobre Base UI tiene `multiple`; es el mismo componente con el mismo markup.
- **Sin casillas.** Base UI marca cada elegido con el mismo `ItemIndicator` (el check de la
  derecha), así que Craft también: los items son idénticos al modo simple.
- `values` se copia al entrar y al salir; `onChange` recibe siempre una tabla nueva. Acepta
  también la forma array (`{ "pull", "cast" }`). `SetValues` es silencioso.
- Trigger: labels en el orden de `options`, `", "`, truncado con elipsis; values desconocidos
  van crudos al final.
- **Esc cierra el Select (ambos modos)** — faltaba también en el simple; Radix y Base UI lo hacen.
- Teclado (flechas/Enter): igual que el Select simple, no hay (ADR-0011, mouse-only).
- Demo: `pages/Select.lua`, filas «FR-121» (Bar Type, 9 opciones con scroll, `SetValues`).

## Fallback en el consumidor (mientras tanto)

SMRT sangra las casillas de opción bajo la casilla del filtro (`section` en `ui/Fields.lua`) para que se lea que
cuelgan de él. Cuando llegue el build, el campo pasa a ser el desplegable al lado de la casilla, como en WA, con el
mismo dato guardado (`type_pull`, `type_break`, …).
