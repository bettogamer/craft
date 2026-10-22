# Component: Dialog

> Referencia shadcn: `dialog` — WoW frame base: `Frame` con `SetMovable(true)`

## CSS real de Lyra (referencia)

```css
.cn-dialog-content {
  @apply bg-popover text-popover-foreground ring-foreground/10 grid
         max-w-[calc(100%-2rem)] gap-4 rounded-none p-4 text-xs/relaxed ring-1
         sm:max-w-sm;
}
.cn-dialog-close {
  @apply absolute top-2 right-2;
}
.cn-dialog-header {
  @apply gap-1 text-left;
}
.cn-dialog-title {
  @apply text-sm font-medium;
}
.cn-dialog-description {
  @apply text-muted-foreground text-xs/relaxed;
}
```

## Propósito

Ventana flotante draggable que se eleva sobre el contenido de la UI para capturar la atención del usuario; contiene un área de header (título + descripción), área de contenido editable y zona de acciones opcional.

## Animación ([Unreleased])

Show/Hide/Toggle animan con `Weave.tween` (ADR-0013 §4.6): **fade** por alpha (el overlay en sincronía) + **`zoom-in-95`** (escala `motionZoomFrom`→1.0 al abrir, 1.0→`motionZoomFrom` al cerrar) desde el centro. **Nunca anima height** — WoW no repinta un frame colapsado a 0. Duración/easing salen de los tokens de movimiento del tema (`motionFast`/`motionEasing`). Señal privada `_open`; `shown = open|animating` para mantener visible durante la fade-out. Disposal por `Craft.Reactive.disposeAll` en `Destroy`.

## Jerarquía de frames WoW

```
dialog._overlay        (Frame, strata=modalOverlay, UIParent) backdrop black/10, bloquea clics
dialog.frame           (Frame, strata=modal, UIParent)        raíz draggable (1 strata sobre el overlay)
├── dialog._bg         (Texture, BACKGROUND)          fondo del dialog
├── dialog._header     (Frame, opcional)              zona de título — drag handle
│   ├── dialog._title  (FontString)                   texto del título (text-sm)
│   ├── dialog._desc   (FontString, opcional)         descripción (text-xs)
│   ├── dialog._headerBorder (Frame, 1px alto)        línea separadora bottom (FR-088, opt-in)
│   └── dialog._closeBtn (Frame, 24×24px)             botón de cierre "×"
│       ├── dialog._closeBg  (Texture)                fondo hover/press
│       └── dialog._closeX  (FontString)              símbolo "×"
├── dialog._content    (Frame)                        área editable por el dev
└── dialog._footer     (Frame, opcional)              zona de acciones
    └── dialog._footerBorder (Frame, 1px alto)        línea separadora top (ADR-0011)
```

**Overlay modal (`.cn-dialog-overlay`):** un Frame full-screen en UIParent, en la capa
`modalOverlay` (`Craft.Strata.modalOverlay` = `FULLSCREEN`), con fondo negro `a=0.10`
(`bg-black/10`) y `EnableMouse(true)` para bloquear clics a la UI de abajo → el dialog es
modal. WoW no tiene `backdrop-blur`, así que es solo el relleno plano (sutil). Su visibilidad
se sincroniza con el dialog vía los mismos reactivos `alpha`/`shown` (cubre cierre por X,
Escape, `Hide()` y `Toggle()`).

**⚠️ El overlay va una strata POR DEBAJO del frame — NO en la misma.** El overlay usa
`EnableMouse(true)` para tragarse los clics a la UI de abajo; si compartiera la strata del
frame se tragaría también los botones y la ✕ del propio dialog (solo cerraría con Escape, que
va por `UISpecialFrames` y no depende del z-order del mouse). Poniendo el frame en una strata
**estrictamente superior** (`modal` = FULLSCREEN_DIALOG) al overlay (`modalOverlay` =
FULLSCREEN), los hijos del frame ganan el mouse. **No** separar frame y overlay por frame-level
dentro de una strata compartida (rompía todos los clics del dialog).

**⚠️⚠️ El frame y el overlay se parentan a `UIParent`, NO al `parent` del caller.** Un modal es
un objeto de nivel de pantalla (centrado en UIParent, flota sobre toda la UI). Si el frame es
hijo del frame del caller, **la strata alta NO se honra de forma fiable** frente a un hermano de
UIParent como el overlay: enterrado en la jerarquía del caller (p. ej. dentro de un `ScrollFrame`
en `HIGH`, como la página del Craft_Browser), el `FULLSCREEN_DIALOG` del frame **no supera de
verdad** al backdrop en `FULLSCREEN`, así que el backdrop (con `EnableMouse`) se comía todos los
clics y el drag (solo funcionaba Escape). Parentar el frame a `UIParent` — igual que el backdrop
y todos los paneles de popover — hace que la comparación de strata sea global y correcta. El
parámetro `parent` de `Create` se acepta por compat pero **no** se usa para el frame raíz.

**Capa `modal` y FR-033:** antes el dialog vivía en `DIALOG` y el overlay en `HIGH`. Como
`Craft.Window` también usa `DIALOG` + `SetToplevel` + raise-on-click, un modal abierto DESDE
una ventana nacía en su misma strata (quedaba **detrás**) y el backdrop en `HIGH` (por
**debajo** de la ventana, no la oscurecía). La escala centralizada `Craft.Strata` fija la
invariante `page (Window, DIALOG) < modalOverlay (FULLSCREEN) < modal (Dialog,
FULLSCREEN_DIALOG) < popover (TOOLTIP)`: el modal siempre flota sobre cualquier Window, su
backdrop la cubre, y sus botones quedan clicables. El catcher de click-outside de los popovers
también está en `FULLSCREEN_DIALOG`, así que un dropdown abierto DENTRO de un modal sigue
cerrándose al clicar fuera y su panel (TOOLTIP) queda por encima.

**Notas de estructura:** en Lyra el Dialog no tiene un title bar de altura fija separado. El layout es `p-4 gap-4`: padding de 16px en todos los lados y 16px de gap entre secciones (header → content → footer). El header es simplemente un contenedor con `gap-1` entre título y descripción; no existe una barra fija de 40px. El drag se habilita en el header area.

### Patrón ring-1 ring-foreground/10 (ADR-0011)

Idéntico al Panel: `ring-1` es un outline de 1px en CSS que no afecta el layout. En WoW se implementa pintando el frame exterior con el color del ring y dejando `_bg` insetado 1px:

```lua
-- _bg insetado 1px para que el ring sea visible
dialog._bg:SetPoint("TOPLEFT",     dialog.frame, "TOPLEFT",      1, -1)
dialog._bg:SetPoint("BOTTOMRIGHT", dialog.frame, "BOTTOMRIGHT", -1,  1)
dialog._bg:SetColorTexture(t.popover.r, t.popover.g, t.popover.b)

-- Ring: textura en el frame exterior
dialog._ringTex = dialog.frame:CreateTexture(nil, "BACKGROUND", nil, -1)
dialog._ringTex:SetAllPoints(dialog.frame)
dialog._ringTex:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)
```

> **Focus rings:** NO implementar (WoW es mouse-only — ADR-0011).

## Dimensiones

| Elemento | Valor | Origen CSS |
|---|---|---|
| Ring perimetral | 1px (todos los lados) | `ring-1` |
| Padding exterior (todos los lados) | 16px (`t.spacingLg`) | `p-4` |
| Gap entre secciones (header/content/footer) | 16px (`t.spacingLg`) | `gap-4` |
| Gap título → descripción | 4px (`t.spacingXs`) | `gap-1` |
| Title font size | 14px (`t.fontSizeLg`) | `text-sm font-medium` |
| Description font size | 12px (`t.fontSize`) | `text-xs` |
| CloseBtn size | 24×24px | — |
| CloseBtn offset top-right | 8px (`t.spacingSm`) en X e Y | `top-2 right-2` |
| Footer borde-top | 1px | `border-t` (ADR-0011) |
| Header borde-bottom (opt-in) | 1px | — (FR-088, no existe en Lyra) |

> **Nota:** `text-sm` = 14px en Tailwind/Lyra. El título usa `text-sm font-medium` (14px, no 12px). No existe un titleBar de altura fija — el header crece con su contenido.

## Variantes / Configuraciones

| Size | Width | Origen CSS |
|---|---|---|
| `sm` | 320px | — |
| `default` | 384px | `sm:max-w-sm` |
| `lg` | 512px | — |
| `xl` | 640px | — |

> **Corrección:** el width default en Lyra es `sm:max-w-sm` = **384px** (no 520px). Ajustar la variante `default` a 384px. Las variantes `sm`, `lg`, `xl` son extensiones WoW fuera del CSS base.

**Altura = grow-to-fit (no fija).** El frame **crece** para acomodar
`header + gap(16) + content + gap(16) + footer`. La altura del contenido la fija el
dev con `GetContent():SetHeight(n)` (un Frame WoW no auto-dimensiona según sus hijos);
si no se fija, el área de contenido es 0 y el dialog solo muestra header + footer.
`Show()` re-ejecuta el layout, así que basta fijar la altura del content/footer antes
de mostrarlo. **No** estirar el contenido entre header y footer dentro de un frame fijo
(ese era el bug: con header+footer > altura fija, el contenido colapsaba a tamaño negativo).

### Diferencias conocidas vs shadcn (fuera de MVP)

shadcn expone **`DialogClose`** como sub-componente reutilizable (cualquier elemento
puede cerrar el diálogo). Craft integra el botón de cierre directamente en el header
y no ofrece un `Close` componible. Diferencia de alcance, no bug — ver
`docs/design-reference.md` §9.1. Impacto bajo; el cierre por header cubre el caso común.

## Estados

| Elemento | Estado | Visual |
|---|---|---|
| Dialog | Default | Visible, capa `modal` (FULLSCREEN_DIALOG), fondo `t.popover`, ring `t.border` 1px |
| Dialog | Oculto | `Hide()` — no consume input |
| CloseBtn | Default | Fondo transparente, "×" en `t.mutedForeground` |
| CloseBtn | Hover | Fondo `t.accent`, "×" en `t.foreground` |
| CloseBtn | Press | Fondo `t.accent` con `a=0.7` |
| Header | Dragging | Cursor cambia — el frame se mueve con el mouse |

## Mapa de tokens

| Elemento | Token | Valor dark mode |
|---|---|---|
| Overlay (backdrop) | negro `a=0.10` | `{0, 0, 0, 0.10}` (`bg-black/10`) |
| Fondo del dialog | `t.popover` | {r=0.091, g=0.091, b=0.091} |
| Ring perimetral | `t.border` | {r=1, g=1, b=1, a=0.10} |
| Borde-top del footer | `t.border` | {r=1, g=1, b=1, a=0.10} |
| Borde-bottom del header (`headerBorder`) | `t.border` | {r=1, g=1, b=1, a=0.10} |
| Texto del título | `t.popoverForeground` | {r=0.980, g=0.980, b=0.980} |
| Fuente del título | `t.fontBold`, `t.fontSizeLg` (14px) | — |
| Texto de descripción | `t.mutedForeground` | {r=0.630, g=0.630, b=0.630} |
| Fuente de descripción | `t.font`, `t.fontSize` (12px) | — |
| CloseBtn "×" default | `t.mutedForeground` | {r=0.630, g=0.630, b=0.630} |
| CloseBtn "×" hover | `t.foreground` | {r=0.980, g=0.980, b=0.980} |
| CloseBtn fondo hover | `t.accent` | — |
| CloseBtn fondo press | `t.accent` (a=0.7) | — |
| Content padding | `t.spacingLg` (16px) | — |
| Footer padding horizontal | `t.spacingLg` (16px) | — |
| CloseBtn offset | `t.spacingSm` (8px) | — |

## Config — `Create(parent, config)`

| Parámetro | Tipo | Default | Descripción |
|---|---|---|---|
| `title` | string | `""` | Texto del título en el header |
| `description` | string | nil | Texto de descripción bajo el título |
| `size` | string | `"default"` | Uno de: `"sm"` (320px), `"default"` (384px), `"lg"` (512px), `"xl"` (640px) |
| `onClose` | function | nil | Callback invocado al cerrar (botón × o Escape) |
| `closeOnEscape` | boolean | true | Si true, registrar el frame en `UISpecialFrames` |
| `headerBorder` | boolean | **false** | (FR-088) Dibuja una regla de 1px `t.border` bajo el header, gemela de la del footer. **Opt-in a propósito:** Lyra no pinta `border-b` en `.cn-dialog-header`, así que el default es el shadcn fiel; se enciende en el modal cuyo contenido arranca con controles pegados al encabezado. No cambia la altura de nada. |
| `fontFlags` | string | `nil` | FR-102: flags de fuente de título y descripción (4.º arg de `Theme.applyFont`; `""` = sin contorno, p. ej. texto claro sobre superficie oscura con el tema en `"OUTLINE"`). `nil` = el `t.fontFlags` global del tema. Se reaplica en cada re-tema. |
| `modal` | string \| boolean | `"screen"` | (FR-119) Qué bloquea el backdrop: `"screen"`/`true` = toda la pantalla; `"window"` = solo la ventana que aloja el diálogo (la `Craft.Window` más cercana sobre `parent`, o el ancestro más externo bajo `UIParent`; abre centrado en ella y se cierra si se oculta); `false`/`"none"` = nada (diálogo no bloqueante, sin backdrop). |
| `modalTarget` | Frame \| componente | nil | (FR-119) Ventana que bloquea un modal `"window"` en vez de la encontrada desde `parent` (p. ej. la main window desde una sub-ventana). |
| `nudge` | boolean | true | (FR-119) Un clic en la zona bloqueada sacude el diálogo (`Nudge()`). |
| `strata` | string | `Craft.Strata.modal` (`"FULLSCREEN_DIALOG"`) | Strata del **frame**. Default = capa `modal` (sobre cualquier `Craft.Window`). El overlay va siempre en `Craft.Strata.modalOverlay` (`"FULLSCREEN"`), una strata por debajo. Solo cambiarlo para casos avanzados. |

## API pública

| Método | Retorno | Descripción |
|---|---|---|
| `GetFrame()` | Frame | Retorna `dialog.frame` |
| `GetContent()` | Frame | Retorna `dialog._content` — aquí se agregan los hijos |
| `GetFooter()` | Frame \| nil | Retorna `dialog._footer` o nil si no fue creado |
| `SetTitle(text)` | void | Actualiza el texto de `dialog._title` |
| `Show()` | void | `dialog.frame:Show()` |
| `Hide()` | void | `dialog.frame:Hide()` |
| `Toggle()` | void | Alterna entre Show y Hide según estado actual |
| `Nudge()` | void | (FR-119) Sacude el diálogo una vez (seno amortiguado, 3 vaivenes, 6 px, 0,4 s; vuelve a su sitio exacto). No-op cerrado o si ya se está sacudiendo |
| `SetModalTarget(t)` | void | (FR-119) Cambia la ventana que bloquea un modal `"window"`; se aplica en el siguiente `Show()` |
| `SetBaseScale(s)` / `GetBaseScale()` | void / number | Escala del diálogo (FR-068/FR-073). El zoom multiplica sobre ella; `GetFrame():SetScale()` NO funciona |

## ⚠️ Medir texto dentro de un Dialog (FR-073)

`GetStringWidth`/`GetStringHeight` de WoW **escalan con la escala efectiva del frame**, y el
zoom de apertura conduce la escala del frame raíz. Mientras el diálogo estaba **cerrado**, ese
frame se quedaba aparcado en `motionZoomFrom` (0.95), así que **todo** lo que el consumidor
escribiera antes de `Show()` se medía ~5% corto: cada `Craft.Label` con `maxWidth` recibía una
caja 5% estrecha y elidía con "…", en proporción a su longitud. Silencioso, y con pinta de
"el `maxWidth` está mal calculado". La pista era el contraste: los labels SIN `maxWidth` del
mismo diálogo se veían bien (no pinean ancho, nada que truncar), y los mismos textos dentro de
un `Craft.Window` tampoco elidían.

Arreglado en el origen: **en reposo y cerrado el frame ya no se aparca a 0.95**, se queda a su
escala base. El pop sigue saliendo porque el tween arranca en `motionZoomFrom` al abrir.
`Craft.Tooltip` resuelve lo mismo por otra vía (`_tooltip:SetScale(1)` antes de medir), pero
Dialog no podía copiarla: el contenido no es suyo, lo rellena el consumidor cuando quiere.

**Residuo conocido:** escribir texto *durante* los ~150ms de la animación sigue midiéndose con
la escala del tween. El orden normal (`refresh(); dialog:Show()`) no lo toca; si hace falta
pintar con el diálogo ya abriéndose, esperar a que asiente.

Y la regla general, que no es solo de Dialog: **cualquier** frame escalado a mano por el
consumidor mide su texto en las unidades de ese frame. Ver
[label.md](label.md) §modos de ancho.

## Notas de implementación

**Strata y clamp (FR-033):**
```lua
-- frame y overlay en stratas DISTINTAS: el frame estrictamente por encima del overlay
dialog.frame:SetFrameStrata(Craft.Strata.modal)          -- "FULLSCREEN_DIALOG"
dialog._overlay:SetFrameStrata(Craft.Strata.modalOverlay) -- "FULLSCREEN" (1 rung abajo)
dialog.frame:SetMovable(true)
dialog.frame:SetClampedToScreen(true)
dialog.frame:RegisterForDrag("LeftButton")
```
`SetClampedToScreen(true)` impide que el usuario arrastre el dialog fuera del viewport.
El `_overlay` (FULLSCREEN) queda por debajo del frame (FULLSCREEN_DIALOG) y ambos por encima
de `Craft.Window` (capa `page` = DIALOG), así que el modal flota sobre la ventana, el backdrop
la oscurece, y los botones/✕ del dialog quedan clicables. Ver `Craft.Strata` (Craft.lua).

**Drag desde el header:**
```lua
dialog._header:SetScript("OnMouseDown", function()
    dialog.frame:StartMoving()
end)
dialog._header:SetScript("OnMouseUp", function()
    dialog.frame:StopMovingOrSizing()
end)
```
El header debe tener `EnableMouse(true)`. No existe un titleBar de altura fija: el header es el área de drag natural con `p-4 gap-1`.

**Cierre con Escape (`closeOnEscape = true`):**
```lua
-- Registrar con nombre único por instancia
dialog.frame:SetName("Craft_Dialog_" .. instanceId)
table.insert(UISpecialFrames, dialog.frame:GetName())
```
`UISpecialFrames` es el mecanismo nativo de WoW para que Escape cierre frames.

**Botón de cierre:**
El `_closeBtn` es un Frame con `EnableMouse(true)`, posicionado a 8px (`t.spacingSm`) del borde top-right. Los scripts `OnEnter`/`OnLeave` cambian el color de `_closeBg`. En `OnMouseUp` invoca `onClose` si fue provisto y luego `Hide()`.

> **⚠️ Frame-level sobre el header (FR-033):** el header es el área de drag (`EnableMouse` +
> `StartMoving`) y cubre todo el ancho superior, solapando el botón ✕. Ambos son hijos de
> `dialog.frame`, así que sin nivel explícito **empatan** y el header puede ganar el mouse →
> clicar la ✕ inicia un drag en vez de cerrar. Se sube el frame-level del `_closeBtn` por encima
> del header (`_closeBtn:SetFrameLevel(_header:GetFrameLevel() + 10)`) para que siempre reciba
> el clic.

**Footer borde-top (ADR-0011):**
```lua
dialog._footerBorder = CreateFrame("Frame", nil, dialog._footer)
Craft.Theme.SetPixelHeight(dialog._footerBorder, 1)
dialog._footerBorder:SetPoint("TOPLEFT",  dialog._footer, "TOPLEFT",  0, 0)
dialog._footerBorder:SetPoint("TOPRIGHT", dialog._footer, "TOPRIGHT", 0, 0)
dialog._footerBorder._tex = dialog._footerBorder:CreateTexture(nil, "BACKGROUND")
dialog._footerBorder._tex:SetAllPoints(dialog._footerBorder)
dialog._footerBorder._tex:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)
```

**Header borde-bottom (FR-088, opt-in):** gemelo exacto del anterior, en el otro borde del
mismo diálogo — `CreateFrame("Frame", nil, dialog._header)` anclado `BOTTOMLEFT`/`BOTTOMRIGHT`
del header, `SetPixelHeight(…, 1)`, textura `t.border`. Nace oculto y `headerBorder = true` lo
muestra.

> **Por qué NO es el default.** El norte de Craft es shadcn en WoW, y el CSS real de Lyra
> (arriba) define `.cn-dialog-header { @apply gap-1 text-left; }` — sin `border-b`. Encenderlo
> por defecto haría que TODO diálogo existente dejara de parecerse a su original por un gusto,
> que es exactamente la divergencia que el proyecto no acepta. `Craft.Window` sí pinta su
> `_titleBarSep` porque una barra de título arrastrable no tiene equivalente shadcn: es una
> pieza nativa de WoW. El caso legítimo del header rule — contenido que empieza con controles
> pegados al encabezado — lo pide el consumidor con una línea de config, y no tiene que deducir
> ningún número interno de `_layoutFrames` para dibujarlo por su cuenta.

**Cae en espacio que ya existía:** el header reserva `spacingSm` (8px) de padding inferior y
deja `spacingLg` (16px) hasta el contenido, así que la línea no altera `headerH` ni la altura
total del diálogo.

**Footer opcional:** si `config.footer` no se pasa, `_footer` no se crea y `_content` se extiende hasta el borde inferior (menos el padding exterior).

**Radius = 0:** sin esquinas redondeadas en ninguna textura (`rounded-none` en Lyra).

**Centrado inicial:** para centrar el dialog al abrirlo la primera vez:
```lua
dialog.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
```
Tras ser movido por el usuario, la posición persiste hasta que se llame explícitamente a re-centrar.
