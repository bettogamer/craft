# FR-130 · Texto vacío con una fuente fuera del tema en el primer arranque

- **Pide:** owner (2026-10-30), al probar la demo de FR-128 in-game
- **Componente:** `theme/Theme.lua` (`applyFont`)
- **Prioridad sugerida:** alta (afecta a todo selector de fuente por elemento: SMRT, Coffer)
- **Estado:** ✅ Implementado en dev (2026-10-30). Pendiente: in-game + release

## Síntoma

En la página Theme del Browser, el catálogo de `getFontFiles()` pinta cada fila con su propio TTF
(Label `font`). En el primer arranque, tres filas (BettoSans Bold Italic, ExtraBold y Black) salieron
**vacías**; tras `/reload` aparecieron las 27. Los archivos están bien y `SetFont` no falla (si fallara,
`applyFont` caería a la fuente del tema y se vería el texto en Inter).

## Causa

Es el bug #4 de CLAUDE.md (carga asíncrona del TTF la primera vez en la sesión), pero en rutas que
**no son del tema**: la sonda por archivo solo vigilaba `font`/`fontMedium`/`fontBold`/`fontMono` del
tema activo, así que nadie re-aplicaba la fuente cuando una ruta suelta terminaba de cargar. Con 20
TTF nuevos a la vez, algunos no llegan a tiempo y su FontString se queda vacío.

## Resolución

`applyFont` (el punto único por donde pasan todas las fuentes de los componentes) arma la sonda para
cualquier ruta que acepte el cliente: `T._armFontProbes({ font = path })`, no-op si ya está sondeada.
Al asentarse, `notifyMetricsChanged` re-ejecuta los `_applyTheme`, que re-aplican la fuente y re-miden
(Label, Button…). Una ruta que `SetFont` rechaza no se sondea (cae a la del tema).

Test: `tests/theme_spec.lua` › «applyFont sondea una ruta fuera del tema y re-notifica al cargar
(FR-130)». Repro: la demo FR-128 de `pages/Theme.lua`, **con reinicio completo del cliente** (`/reload`
no vale: el TTF ya queda en la caché del proceso).
