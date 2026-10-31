# FR-127 · Tooltip: líneas dobles izquierda/derecha y `text` como función

- **Pide:** Coffer (migración de todos sus tooltips de texto a `Craft.Tooltip`, 2026-10-27)
- **Componente:** `Craft.Tooltip` (`components/Tooltip.lua`)
- **Prioridad sugerida:** media (la parte 1 bloquea 2 de los 13 tooltips de texto de Coffer; el resto migra ya)
- **Estado:** ✅ Implementado en dev (2026-10-30) — pendiente in-game + release

## Necesidad

El owner pidió que Coffer use el tooltip de Craft en vez de construir `GameTooltip` a mano. El
inventario (`SortedBags/docs/tooltips-craft-migracion.md`) da 11 sitios que migran tal cual
(`\n` y los escapes `|cff..|r` / `|T..|t` ya funcionan en el FontString), 7 que se quedan nativos
(ítem, moneda, hechizo, ranura) y **2 que no se pueden expresar hoy**:

- **Pie de la ventana, "huecos libres"** (`Coffer/WinBody.lua`, `freeTooltip`): una fila por
  contenedor con el nombre a la izquierda y `libres/total` a la derecha.
- **Oro de la cuenta** (`Coffer/WinBody.lua`, `accountGoldTooltip`): una fila por personaje con el
  nombre (en color de clase) a la izquierda y su oro (`|T` de monedas) alineado a la derecha.

Ambos son el `AddDoubleLine` de `GameTooltip`: dos columnas, la derecha alineada a la derecha y un
color por columna. Con un único FontString no hay forma de alinear la columna derecha.

## Propuesta

1. **Líneas estructuradas (necesario).** Además de `text`, aceptar `lines`:
   ```lua
   Craft.Tooltip.Show(anchor, { lines = {
     { "Nombre de la bolsa", "12/36" },                         -- doble: izq + der
     { "Pepito", "8.770 |T…|t", leftColor = "foreground", rightColor = "mutedForeground" },
     { "Total", "…", separator = true },                         -- opcional: hairline antes
     "una línea simple",                                         -- string = línea de una columna
   } })
   ```
   Colores como **nombre de token** (se re-resuelven con el tema, como `Button.tone`, FR-077) o
   tabla `{r,g,b,a}`. Ancho = el máximo de (izq + hueco + der) acotado por `maxWidth`.
   Opcional: `title` (primera línea en `fontMedium` / `foreground`), el patrón shadcn de cabecera.
2. **`text` (y `lines`) como función (recomendado).** `text = function(anchor) → string`, evaluada
   en cada `Show` / hover de `Attach`. Hoy Coffer lo consigue mutando el `cfg` capturado por
   referencia en `Attach` (`SettingsWin.lua:1725`), que funciona pero es un contrato implícito.
3. **Opcionales:** `Craft.Tooltip.GetOwner()` / `IsShown()` (para re-pintar el tooltip abierto
   tras un clic que cambia lo que describe — hoy se hace con `GameTooltip:IsOwned`), y `delay`
   también en `Show` (hoy solo `Attach` lo aplica).

## Mientras tanto en Coffer

Los 11 sitios migrables pasan ya a `Craft.Tooltip`; `freeTooltip` y `accountGoldTooltip` siguen con
`GameTooltip` hasta que se cierre este FR.

## Resolución

Las tres partes. (1) `lines` + `title`: cada línea es un string (una columna con wrap) o
`{ left, right, leftColor, rightColor, color, separator }`; la doble línea auto-dimensiona la derecha al borde del
contenido y trunca la izquierda con elipsis. Colores por token o tabla, re-resueltos con el tema. `separator` =
hairline `border` a sangre con `my-1`; `title` en `fontMedium`. Ancho = máx(izq + 12 + der) acotado por
`maxWidth`. (2) `text`/`lines`/`title` pueden ser `function(anchor)`, evaluadas en cada `Show`/hover sobre una
copia (la config capturada no se muta). (3) `Craft.Tooltip.GetOwner()` / `IsShown()` y `delay` en `Show` (default
0; `Hide` lo cancela). Spec: `docs/components/tooltip.md`. Tests: `tests/tooltip_spec.lua` › «lines / dynamic text
(FR-127)». Demo: `Craft_Browser/pages/Tooltip.lua`, fila FR-127 (huecos libres, oro de la cuenta, texto dinámico
con re-pintado vía `GetOwner`).
