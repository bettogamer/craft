# NaowhForever vs Craft — patrones de UI transversales (pixel-perfect primero)

_2026-11-13. Investigación de solo lectura. NaowhForever en `F:\Games\World of Warcraft\_forever_\Interface\AddOns\NaowhForever` (rutas relativas a esa carpeta). Complementa `docs/research/naowhforever-badges.md` (no se repite). Muestreo por grep/extractos, no auditoría exhaustiva: lo no leído va marcado "sin verificar"._

## Resumen (tabla)

| # | Idea | Beneficio | Coste | Componentes afectados | Prioridad |
|---|------|-----------|-------|-----------------------|-----------|
| 1 | **Registro de re-ajuste de píxeles** (fit registry + `OnShow` + `UI_SCALE_CHANGED`/`DISPLAY_SIZE_CHANGED`) | Bordes/separadores 1px dejan de quedar mal tras cambio de escala UI, resolución, reparent o `SetScale` de un ancestro | Medio (1 módulo en Theme + migrar `AnchorBorder`/`SetPixel*`) | Los ~27 componentes que usan `AnchorBorder`/`SetPixel*`/`px()` | **ALTA** |
| 2 | Evento de escala en Theme que re-notifique listeners (alternativa barata a 1) | Arregla el bug sin tocar componentes: reutiliza `_applyTheme` | Bajo | Todos los que re-aplican bordes en `_applyTheme` | **ALTA** (quick win) |
| 3 | `Smooth()` = `SetSnapToPixelGrid(false)` + `SetTexelSnappingBias(0)` en texturas de forma/icono | Evita que el snapping del cliente deforme/desplace pills, círculos, iconos escalados | Bajo | Switch, Avatar, Badge pill, Icons.Apply, Checkbox/Radio marcas | MEDIA (verificar in-game) |
| 4 | Hairline/PixelInset como API declarativa (`Hairline(tex,"h")`, `PixelInset(region,n)`) | Una sola línea por tira; fuente única del grosor | Bajo (sobre 1) | Separator, Section, Tabs, Window, Sidebar | MEDIA |
| 5 | Slider con `OnUpdate` solo durante el arrastre (se quita al soltar) | Cero coste en reposo | Ya lo hacemos parcialmente (sin verificar) | Slider, ScrollBar | BAJA |
| 6 | `Usable(v)` = guard `issecretvalue` en un helper local | Uniformidad | Trivial | Tooltip, medidas de texto | BAJA |
| 7 | `ns.MenuOpen()` suprime tooltips mientras hay menú abierto | Menos ruido visual | Bajo | Tooltip.Attach, Menu | BAJA |
| 8 | Guardas `InCombatLockdown()` en ventanas con propagación de teclado | Evita taint/errores en combate | Bajo | Window, Dialog (sin verificar si ya lo hacemos) | BAJA |

## 1. Pixel-perfect (comparación concreta)

### 1.1 Cómo se calcula "1 px"

- **Craft:** `Theme.px(n, frame)` (`Craft/theme/Theme.lua:464-485`) usa `PixelUtil.GetNearestPixelSize(n, frame:GetEffectiveScale(), min)`; las tiras usan `PixelUtil.SetHeight/SetWidth(frame, n, 1)` (`Theme.lua:487-509`). Redondea al píxel físico entero, mínimo 1.
- **NaowhForever:** `OnePixel(region) = PixelUtil.GetPixelToUIUnitFactor() / region:GetEffectiveScale()` (`Core/Core.lua:639-642`, el bloque de `Core.lua:551-720` leído completo). Es exactamente 1 px físico en unidades UI del propio region, sin redondeo; el snapping lo hace el motor (texturas con `SetSnapToPixelGrid` por defecto).
- **Veredicto:** matemáticamente equivalentes para n=1 con escala consistente. NO es ahí donde ganan; la ventaja está en el CUÁNDO (1.2). `GetNearestPixelSize` además redondea n>1 al entero, útil; lo de ellos con n·px puede dar fracciones (ellos lo toleran porque snapea el motor).

### 1.2 Cuándo se recalcula — el gap real de Craft (VERIFICADO)

- **Craft:** en `Craft/theme/Theme.lua` **no hay ningún listener de `UI_SCALE_CHANGED` / `DISPLAY_SIZE_CHANGED`** (grep en `Craft/**`: solo `Craft/icons/Icons.lua:228-229` los registra, y solo para re-elegir densidad de atlas vía `Icons.Refresh`, `Icons.lua:172-232`). Los únicos `RegisterEvent` de Theme son `ADDON_LOADED`/`PLAYER_LOGIN` para LSM (`Theme.lua:737-738`). El notificador de listeners de tema (`notifyMetricsChanged`, `Theme.lua:608-624`) solo se dispara por asentamiento de fuente y por `use()`; **nunca por escala**.
- `AnchorBorder` (`Theme.lua:523-550`) llama `SetPixelHeight/Width` **una vez**, y los componentes lo invocan desde su build/`_applyTheme` (ej. `Button.lua:241`, `Input.lua:445`). `PixelUtil.SetHeight` calcula con la escala efectiva **en el momento de la llamada** y fija un número absoluto en unidades UI. Consecuencias:
  1. Cambio de UI scale / resolución / `/console uiScale` en sesión → todas las tiras quedan con el grosor del scale viejo (1 px ± fracción: borde borroso, 2 px o desaparecido). Hasta `/reload`.
  2. Frame creado **antes de estar parentado/escalado** (caller hace `SetParent`, `SetScale` o `SetBaseScale` después de `Create`) → `GetEffectiveScale()` en el build es el del padre provisional. El único re-aplicado visible es `Window:SetBaseScale` → solo `Icons.Refresh` (`Window.lua:741-752`), NO re-aplica píxeles.
  3. Hay solo 8 `OnShow` en componentes y ninguno re-ajusta bordes (`CodeEditor:373`, `Scroll:144`, `Section:95`, `Sidebar:295`, `Tabs:124`, `Textarea:170`, `Select:280`…).
  - `Window.lua:435` calcula `px1 = Theme.px(1, self.frame)` en `_applyTheme` (insets del anillo 1px): mismo problema (valor congelado).
- **NaowhForever:** `Register(region, fit)` (`Core/Core.lua:~655-668`): registro débil por "owner" (el frame, o el padre si es textura), un frame vigilante hijo con `OnShow` que re-ejecuta todos los `fit(OnePixel(region))` del owner; `RefitPixels()` recorre todos los owners **visibles** (con guard `issecretvalue` en `IsVisible`) y está enganchado a `UI_SCALE_CHANGED` + `DISPLAY_SIZE_CHANGED` (`~:680-686`). Cada región registra una función de ajuste (no un número), así que grosor e inset se recalculan juntos. `ns.Border` (`:688-720`) guarda `pixels` y `SetPixels` re-ajusta al vuelo.
- **Lo que cubre OnShow y nosotros no:** reparent/`SetScale` de ancestros que ocurre con el frame oculto (ventanas que se abren/cierran, popovers anclados a otro host) — el fit corre justo antes de pintarse. Frames visibles que cambian de escala sin evento (zoom de Window) **tampoco** los cubre OnShow: sin verificar cómo lo resuelven (probablemente no).
- **Ojo (sin verificar in-game):** el evento `UI_SCALE_CHANGED` puede disparar antes de que `UIParent:GetEffectiveScale()` se asiente; Craft ya difiere un frame en Icons (`Icons.lua:231-235`, `C_Timer.After(0, …)`). Ellos refitean síncrono. Copiar nuestro defer.

### 1.3 Snapping de texturas

- **Craft:** ningún `SetSnapToPixelGrid` ni `SetTexelSnappingBias` en todo `Craft/` (grep vacío). Las formas prefab (`Craft/theme/Shapes.lua`, pill del Switch) y los iconos (`Icons.Apply`) quedan con el snapping por defecto del motor.
- **NaowhForever:** `Smooth(tex)` = `SetTexelSnappingBias(0)` + `SetSnapToPixelGrid(false)` (+ `TRILINEAR` en sus TGA) en `Shared/UI/Parts.lua:38-43`, `Core/Options/Widgets.lua:139-142` (aplicado a track/knob/mark del toggle), `Core/Pages/Credits.lua:89-90`. Solo en texturas de **forma/imagen**, nunca en las tiras de color (esas SÍ dependen del snapping).
- **Gap potencial:** nuestros círculos/pill escalados a tamaños impares pueden "saltar" medio píxel por el snapping. **Sin verificar** que sea visible; probar con el Switch/Avatar a uiScale no entero. Regla: snapping OFF solo en formas con mipmaps; ON (default) en tiras de 1px.

### 1.4 Frames con escala efectiva distinta (nameplates, padres escalados)

- Ellos calculan `OnePixel(region)` **por región** (`region:GetEffectiveScale()`), no por UIParent, así que un ancestro escalado se respeta. Craft hace lo mismo en `px(n, frame)` y `SetPixelHeight(frame)` (PixelUtil usa la escala del frame), pero falta el re-cálculo (1.2). Nameplates: sin verificar en Naowh (`Core/Badges/Badges.lua:442` usa `OnUpdate` en la placa, no relacionado con píxeles). Recordar: las nameplates son "restricted regions" (CLAUDE.md global): no medir/anclar por GetCenter.

### 1.5 Tamaños impares y centrado a medio píxel

- No encontré lógica explícita de half-pixel en Naowh: usan `SetPoint("CENTER")` y tamaños `floor(H*share + ROUND)` (`Widgets.lua`, `UI.BuildToggleControl`, redondeo manual de `KNOB`/`INSET`). Es decir, **redondean tamaños a enteros a mano** y dejan el centrado al motor. Craft: sin verificar si centra marcas de Checkbox/Switch con tamaños impares; candidato a revisar al hacer el FR-1.

### 1.6 Posición de texto en la rejilla

- `ns.FontInset(size) = size * 0.075` (`Core/Core.lua:22,551-553`), usado para alinear a la izquierda el borde del trazo de la fuente con elementos vecinos (`Badges.lua:332-334`). Es un ajuste de **óptica de fuente** (side bearing), no de píxel. Craft no lo tiene; sería útil solo con fuentes con bearing marcado (Betto*). **Baja prioridad**, medir antes.

## 2. Otros patrones transversales

| Tema | NaowhForever | Craft | ¿Adoptar? |
|------|--------------|-------|-----------|
| Slider (Options) | `OnUpdate` solo mientras dura el arrastre; `FromCursor` con `GetCursorPosition()/GetEffectiveScale()`; corta si `IsMouseButtonDown` es false (`Core/Options/Widgets.lua:395-430`) | `Craft/components/Slider.lua` (pure custom, ver FR-110): sin verificar el mecanismo de arrastre | Verificar que Craft también quita el OnUpdate al soltar y corta por `IsMouseButtonDown` (robusto ante pérdida de `OnMouseUp`) |
| Tooltip propio | Card propia (`UI.HideWidgetTooltip`, `Widgets.lua:~120-135`), mide con `GetStringWidth` y `Usable(w)` (guard secret) y ajusta el ancho al texto | `Craft.Tooltip` (ya tiene escala del ancla, FR-136) | Solo el `Usable()` guard; el resto ya está |
| Supresión de tooltips con menú abierto | `ns.MenuOpen()` (`Shared/UI/Menus.lua:326-329`) consultado en `Parts.Tip` (`Parts.lua:~25`) | No | Opcional (`Tooltip.Attach` podría callar si `Craft.Menu` abierto) |
| Hover/pressed | Alphas fijos `HOVER_ALPHA 0.15`, `PUSHED_ALPHA 0.35`, capa `ARTWORK sublevel 1` (`Parts.lua:~20-22`) | Tokens por tema (hover/pressed) | No: tokens de Craft son mejores (shadcn-fiel) |
| Combate | 50 usos de `InCombatLockdown` (Options/Window, Core, Onboarding…): `if InCombatLockdown() then return end` antes de `SetPropagateKeyboardInput` (`Core/Options/Window.lua:483-488,592`) | Sin verificar en Window/Dialog | Auditar Window/Dialog/Menu |
| Animación | `OnUpdate` puntuales (32 en total; spinner `SetupWindow.lua:256`, placas `Badges.lua:442`) | Weave (motor propio) | No: Weave ya es superior |
| Pooling | No usan pools propios (solo LibCustomGlow y lectura de pool de RXP) | Pools en DragList/Sidebar/Combobox | No hay nada que copiar |
| Fuentes | `SetGameFontObjects` reescribe todos los `*Font` globales (`Core.lua:~590-610`); fuente por addon con fallback `LocaleFont` | Sonda por TTF + `onFontMetricsChanged` (más robusta) | **No copiar** (tocar fuentes globales del juego es invasivo). Sí el fallback `LocaleFont(default, STANDARD_TEXT_FONT)` para locales CJK/cirílico: **sin verificar** si Craft lo cubre |
| Búsqueda/ajustes UI | `Shared/Settings/Rows.lua`, `Core/Options/*` (settings + búsqueda) | `Craft.Sidebar`, Field, Combobox | Sin verificar a fondo; no leído |
| Frame level | `math.min(frameLevel+1, MAX_FRAME_LEVEL)` al crear el frame de borde (`Core.lua:~695`) — clamp al máximo de nivel | Escala `Craft.Strata` (FR-033) | Copiar el **clamp** a 10000 en cualquier `SetFrameLevel(parent+N)` de Craft (sin verificar si ya lo hacemos) |

## 3. Qué NO copiar

- **Skin "foreverSkin"/Classic** (`ns.foreverSkin`, `ForeverCheck`, `CLASSIC_HEADING_SHADOW`): arte Blizzard-clásico, sombras de texto, bordes con anillos rojos (`Forever.lua:161-169,607`). Contrario al norte "shadcn plano".
- **Reescritura de fuentes globales del juego** (`SetFontObjects`, `STANDARD_TEXT_FONT`, `DAMAGE_TEXT_FONT`): efecto fuera de nuestro alcance.
- **`GameTooltip` nativo para tooltips de widgets** (`Parts.Tip` con `GameTooltip:SetOwner`): Craft tiene Tooltip propio.
- **Discos apilados para contorno** (`Forever.lua:1078-1084`): ya descartado en la investigación de Badge.
- **Hover con alphas hard-coded**: pierde tokens.
- **Sin pooling/virtualización**: peor que Craft.

## 4. FR propuestos

1. **FR-142 — Re-ajuste de píxeles ante cambio de escala/resolución/reparent (`Theme.RegisterPixel`)** _(pixel-perfect, ALTA)_. Hoy `AnchorBorder`/`SetPixelHeight/Width`/`px()` fijan un grosor absoluto una única vez al construir (`Theme.lua:464-550`) y **nada** lo recalcula si cambia `UIParent` scale, la resolución, el `SetScale` de un ancestro o el parent. Añadir un registro débil por owner `Theme.pixelFit(region, fn)` (ejecuta `fn(px)` ahora y en cada re-ajuste) con `OnShow` en un frame vigilante y un watcher de `UI_SCALE_CHANGED`/`DISPLAY_SIZE_CHANGED` (diferido 1 frame, como `Icons.lua:231`), recorriendo solo owners visibles (guard `issecretvalue` sobre `IsVisible`). Reescribir `AnchorBorder`, `SetPixel*` (opcionalmente) y los usos de `px()` en `_applyTheme` (Window `:435`, etc.) sobre él. Un watcher compartido entre copias vendoreadas vía tabla `Craft.Theme` (patrón `I._scaleWatcher`). Spec + test con stub de `GetEffectiveScale`, demo en Browser (botón "cambiar uiScale" que dispare el evento) y fila en la página de Separator/Button.
2. **FR-143 (quick win alternativo, si FR-142 se aplaza) — Notificar listeners de tema en cambio de escala.** Que `UI_SCALE_CHANGED`/`DISPLAY_SIZE_CHANGED` (diferido) llamen a `notifyMetricsChanged()` (`Theme.lua:608`) para que cada `_applyTheme` re-ejecute `AnchorBorder`. Cuesta ~10 líneas pero re-aplica TODO el tema (más caro) y no cubre reparent ni `SetScale` de ancestros; por eso FR-142 es lo correcto y esto solo un parche. Verificar que todos los componentes llaman `AnchorBorder` dentro de `_applyTheme` (hoy algunos lo hacen en build: sin verificar uno por uno).
3. **FR-144 — Snapping off en texturas de forma/icono (`Theme.smooth(tex)`).** Helper `SetSnapToPixelGrid(false)` + `SetTexelSnappingBias(0)` aplicado en `Icons.Apply`, formas de `Shapes.lua` (pill/circle) y marcas de Checkbox/Switch. Primero **probar in-game a uiScale no entero** si hay salto de medio píxel; si no se observa, descartar. Nunca en tiras de color de 1px.
4. **FR-145 — Auditar el centrado de formas de tamaño impar y el clamp de frame level.** Revisar que marcas/thumbs con tamaños impares (Checkbox 16, Switch thumb) no caen a medio píxel, y que ningún `SetFrameLevel(parent + N)` rebasa el máximo del cliente (Naowh clampa, `Core.lua:~695`). Es auditoría; devuelve FR concretos si se halla algo.
5. **FR-146 (opcional) — `Theme.hairline(tex, axis)` y `Theme.pixelInset(region, n, rel)` declarativos** como azúcar sobre FR-142 para Separator/Section/Tabs/Window.

## 5. Sin verificar (resumen)

- Mecanismo exacto de arrastre y quitado de `OnUpdate` en `Craft.Slider`/`ScrollBar`.
- Si Craft ya tiene fallback de fuente por locale (CJK/cirílico).
- Auditoría de `InCombatLockdown` en Window/Dialog/Menu de Craft.
- Líneas exactas de `Register`/`RefitPixels` (leídas íntegras en el extracto `Core.lua:551-720`; los números de línea `~` son aproximados).
- Comportamiento de Naowh en nameplates / escala cambiada con frame visible sin evento.
- Búsqueda de ajustes (`Shared/Settings/Rows.lua`, `Core/Options/*`): no leído.
- Que `UI_SCALE_CHANGED` necesite diferirse un frame (Craft lo hace en Icons; Naowh no): medir in-game.
