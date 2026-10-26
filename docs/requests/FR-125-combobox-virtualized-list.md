# FR-125 · Combobox: lista virtualizada para listas largas

- **Pide:** SMRT (módulo Auras, pestaña Load › Ubicación, buscador «Añadir zona…», 2026-10-25)
- **Componente:** `Craft.Combobox` (`components/Combobox.lua`)
- **Prioridad sugerida:** media
- **Estado:** ✅ Released v2.39.0 (2026-10-25) — verificado in-game

## Necesidad

El buscador de zonas de SMRT ofrece el catálogo de mapas del cliente (`C_Map.GetMapInfo`, zonas y mapas de
mazmorra): **1247 entradas** medidas in-game en 12.1.5. `Combobox` crea y pinta una fila por cada entrada filtrada
(`_buildRows`, `Combobox.lua:316-361`): al abrirlo sin texto se crean 1247 marcos de fila, y cada tecla vuelve a
pintar todas las que pasan el filtro. Es la lista «larga o variable» para la que existe Combobox (cabecera del
fichero), pero su lista no escala a ese tamaño.

## Solución propuesta

- Lista **virtualizada**: solo tantas filas como caben en `MAX_LIST_H` (300 px / 24 px ≈ 13) más un margen; al hacer
  scroll se reasignan a las entradas visibles. El alto del scroll child sigue siendo `#entries * ROW_H`.
- El resaltado (hover y ↑/↓), Enter y `_scrollIntoView` trabajan por índice de entrada, no por fila.
- Los grupos (cabeceras) cuentan como entradas de la misma altura.
- API sin cambios para el consumidor.

Alternativa más barata si la virtualización no encaja: `maxResults` (p. ej. 100) con una última fila muda «N más:
sigue escribiendo».

## Fallback en el consumidor (mientras tanto)

Ninguno: SMRT usa el Combobox tal cual (`ui/LoadMore.lua`, `pickerRows`). Funciona; el coste es memoria (un marco por
entrada, creado una vez) y el repintado al escribir.

## Resolución

Virtualización (la propuesta principal; no hizo falta `maxResults`). Pool fijo de 14 filas
(`ceil(292 / 24) + 1`) reasignado a la ventana visible en cada scroll; el scroll child sigue midiendo
`#entries × 24`. Highlight, Enter, click y check van por índice de entrada; los headings son entradas de la
misma altura. API sin cambios. Detalle en `docs/components/combobox.md` (Notas de implementación).
Tests: `tests/combobox_spec.lua` › «virtualized list (FR-125)», con 1247 entradas. Demo:
`Craft_Browser/pages/Combobox.lua`, fila «Long list (FR-125)» con el catálogo real de `C_Map.GetMapInfo`;
`onSelect` imprime en el chat cuántos marcos de fila existen.
