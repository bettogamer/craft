# FR-142 — Recalcular los píxeles cuando cambia la escala (bordes de 1 px)

**Solicitante:** Craft (revisión de NaowhForever, 2026-11-13).
**Componente:** `Craft/theme/Theme.lua` (`px`, `SetPixelHeight/Width`, `AnchorBorder`, listeners de
tema) y todos los componentes que fijan grosores de 1 px (~27: Button, Input, Select, Combobox,
Checkbox, Toggle, ToggleGroup, Tabs, Empty, CodeEditor, Badge, Window…).
**Tipo:** Bug / pixel-perfect.
**Prioridad:** Alta. Afecta a todos los consumidores que dejan cambiar la escala (Coffer, SMRT).
**Estado:** implementado en dev (2026-11-13, sin release), fases 1 y 2. Theme escucha
`UI_SCALE_CHANGED`/`DISPLAY_SIZE_CHANGED`, espera un frame (ráfagas agrupadas) y llama a
`Craft.Theme.RefreshPixels()`: re-ajusta un registro débil de lo pedido en PÍXELES
(`SetPixelHeight/Width/Size` se registran solos; `pixelInset`/`hairline`/`onPixelRefit`, FR-147) y
re-ejecuta los `_applyTheme` de todos los contextos. Una región que otro redimensionó después (fila de
pool reutilizada) sale del registro en vez de pisarse. `RefreshPixels(root)` para el consumidor que
escala su host (re-ajusta solo bajo `root`); `Window:SetBaseScale` ya lo llama; `onPixelScaleChanged(fn)`
persistente. Sin `OnUpdate`. Los sitios que fijaban 1 px solo en `Create` (Dialog, Panel, Sidebar, Tabs)
quedan cubiertos por el registro sin tocarlos. **Pendiente in-game:** página Pixels del Browser (botón de
escala del host) y cambiar Opciones ▸ Gráficos ▸ Escala de UI con el Browser abierto.

---

## Síntoma (esperado)

Con una ventana Craft abierta, el jugador cambia la escala de UI (Opciones ▸ Gráficos, `/console
uiScale`), la resolución, o el consumidor cambia la escala de un host (`SetScale`, p. ej. el slider
de Coffer de FR-139). Los bordes y separadores de 1 px se quedan con el grosor calculado para la
escala anterior: borrosos, de 2 px físicos o invisibles, hasta `/reload` o un cambio de tema.

## Causa

- `Theme.px(n, frame)` y `PixelUtil.SetHeight/SetWidth` (`Theme.lua:464-509`) convierten 1 px físico a
  unidades de UI con la escala efectiva **del momento de la llamada** y fijan un número absoluto.
- `AnchorBorder` (`Theme.lua:523-550`) se llama una vez, desde el build o desde `_applyTheme`
  (`Button.lua:241`, `Input.lua:445`, …). Los insets de relleno (`px1` en Badge, `Window.lua:435`)
  igual.
- **Nada vuelve a llamar a `_applyTheme` cuando cambia la escala:** Theme solo registra
  `ADDON_LOADED`/`PLAYER_LOGIN` (`Theme.lua:737-738`) y `notifyMetricsChanged` (`:608-624`) solo
  salta por fuentes y `use()`. El único que escucha `UI_SCALE_CHANGED`/`DISPLAY_SIZE_CHANGED` es
  `Icons.lua:228-229` (FR-139), y solo para la densidad del atlas. `Window:SetBaseScale` llama a
  `Icons.Refresh` pero no re-aplica píxeles.

## Cómo lo hace NaowhForever

`Core/Core.lua:639-686`: cada región con tiras de 1 px registra una función de ajuste en una tabla
débil por dueño; un frame vigía oculto re-ajusta en `OnShow`, y `UI_SCALE_CHANGED` /
`DISPLAY_SIZE_CHANGED` re-ajustan todas las visibles (con guard `issecretvalue` sobre `IsVisible()`).
El cálculo del píxel es el mismo que el nuestro; lo que hacen mejor es **cuándo** se recalcula.
Detalle en `docs/research/naowhforever-ui-patterns.md` §1.

## Propuesta (en dos fases)

1. **Quick win:** Theme registra `UI_SCALE_CHANGED` y `DISPLAY_SIZE_CHANGED`, espera un frame (la
   escala efectiva se asienta después del evento, igual que en `Icons.lua`) y re-notifica a los
   listeners de tema, que ya re-aplican bordes e insets en `_applyTheme`. Sin tocar componentes.
   Verificar que todos los componentes hacen `AnchorBorder` / `px()` DENTRO de `_applyTheme` y no
   solo en `Create` (los que no, se mueven). `Window:SetBaseScale` dispara lo mismo para su árbol.
2. **Re-ajuste por región (si la fase 1 no basta):** cubrir los casos que no emiten evento global:
   `SetScale` de un ancestro del consumidor, `SetParent` a otro árbol con otra escala, y frames
   creados ocultos y mostrados tras un cambio de escala. API tipo
   `Craft.Theme.onPixelRefit(frame, fn)` con registro débil + re-ajuste en `OnShow`; o una función
   pública `Craft.Theme.RefreshPixels(root)` que el consumidor llama tras su `SetScale` (como
   `Icons.Refresh(host)` de FR-139).

## Criterio de aceptación

- Con el Browser abierto, cambiar la escala de UI en vivo deja todos los bordes a 1 px físico nítido
  sin `/reload` (Button, Input, Select, Badge, Window, Separator…).
- Igual tras cambiar la resolución.
- Fase 2: con un host escalado ×1.3 por el consumidor + la llamada pública, los bordes quedan a 1 px.
- Sin cambio visible a escala fija. Sin coste en reposo (nada de `OnUpdate`).
- Demo en el Browser: página o botón que cambie `UIParent`/host de escala y muestre una rejilla de
  componentes con borde.

## Referencias

- `docs/research/naowhforever-ui-patterns.md`, FR-058 (`px()` sobre la rejilla física), FR-139
  (`Icons.Refresh`), CLAUDE.md bug #4 (re-medir dentro de `_applyTheme`).
