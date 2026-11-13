# Component: Tooltip

> Referencia shadcn: `tooltip` — WoW frame base: `Frame` custom (NO usar GameTooltip de WoW — tiene estilos propios que contradicen Lyra)

## CSS de referencia (Lyra)

```css
.cn-tooltip-content {
  @apply inline-flex items-center gap-1.5 rounded-none px-3 py-1.5 text-xs;
}
```

**Fondo (decisión Craft):** `.cn-tooltip-content` **no** declara background, y el componente
base new-york usa `bg-foreground` (tooltip invertido, claro). Craft usa **`t.popover`**
(oscuro) por coherencia con las demás superficies flotantes (Select content, Dialog). El
valor exacto del tooltip de Lyra no es verificable desde el CSS — esta es una decisión Craft.

## Propósito

Etiqueta informativa flotante que aparece al hacer hover sobre cualquier frame ancla, con delay configurable y posicionamiento automático relativo a la pantalla.

## Animación ([Unreleased])

Fade + `zoom-in-95` + `slide-in-from-side` (ADR-0013 §4.6): alpha eases 0→1, escala interpola `motionZoomFrom`→1.0, y el desplazamiento desliza ~`motionSlide` px desde el anchor (signo según placement vertical: hacia arriba si el tooltip abre arriba, hacia abajo si abre abajo). **Medición a escala 1 ANTES de dimensionar**: el frame idle está a `SetScale(motionZoomFrom)` tras ocultarse, y si se mide a esa escala el texto se subestima (WoW escala `GetStringWidth/Height` con el effective scale). El singleton no tiene destructor → el grafo reactivo (alpha, shown, scale, slide effects) se guarda en `_tooltip._fade` para que nunca sea garbage-collected.

## Jerarquía de frames WoW

```
Craft.Tooltip._frame        (Frame — TOOLTIP strata, singleton compartido por toda la UI)
├── _frame._bg              (Texture — BACKGROUND layer) fondo sólido t.popover
├── _frame._border          (Texture — BORDER layer)     borde 1px, t.border
├── _frame._icon            (Texture — ARTWORK layer)    ícono Lucide 16×16, oculto si no hay icon
└── _frame._text            (FontString — OVERLAY layer) texto del tooltip, t.popoverForeground
```

El tooltip es un **singleton**: existe un único frame `Craft.Tooltip._frame` reutilizado por todos los anchors. No se crea un frame nuevo por cada uso — solo se reposiciona y actualiza el contenido en cada Show(). El borde se implementa con `SetBackdrop` (edgeSize=1, bgFile vacío, edgeFile) o como cuatro texturas de 1px (top, right, bottom, left), una en cada lado del frame.

## Dimensiones / Comportamiento

| Propiedad               | Valor                                                      |
|-------------------------|------------------------------------------------------------|
| Padding horizontal      | 12px (`px-3`) en cada lado                                 |
| Padding vertical        | 6px (`py-1.5`) en cada lado                                |
| Max width               | 240px — el texto wraps con `:SetWordWrap(true)` si supera  |
| Min width               | automático — igual al ancho del texto corto                |
| Offset desde el anchor  | 4px de separación entre el anchor y el tooltip             |
| Ícono                   | 16×16px (iconSizeSm), gap ícono→texto: 6px (`gap-1.5`)     |
| Flecha (arrow)          | shadcn Lyra SÍ define `.cn-tooltip-arrow`; Craft la **omite** (MVP) |
| Delay de aparición      | 300ms por defecto (configurable por anchor)                |
| Strata                  | TOOLTIP — aparece sobre todos los frames excepto UIParent  |
| Font size               | `t.fontSize` (12px)                                        |

### Posicionamiento automático

1. **Por defecto**: el tooltip aparece **arriba** del anchor — `SetPoint("BOTTOM", anchor, "TOP", 0, 4)`.
2. **Sin espacio arriba**: si `anchor:GetTop() + tooltipHeight > UIParent:GetHeight()`, mostrar **abajo** — `SetPoint("TOP", anchor, "BOTTOM", 0, -4)`.
3. **Sin espacio arriba ni abajo**: preferir abajo igualmente.
4. **Clampeo horizontal**: el frame usa `SetClampedToScreen(true)` — WoW lo mantiene dentro de la pantalla automáticamente, sin cálculo manual de `GetRight()`/`GetLeft()`.

El cálculo de posición ocurre **cada vez** que el tooltip se muestra — no se cachea, dado que el anchor puede moverse.

## API pública

| Función                            | Firma                              | Descripción                                                                                     |
|------------------------------------|------------------------------------|-------------------------------------------------------------------------------------------------|
| `Craft.Tooltip.Attach(frame, cfg)` | `(Frame, table) → void`            | Adjunta un tooltip a `frame` via OnEnter/OnLeave. Sobreescribe cualquier attachment previo. **FR-148:** callado mientras haya un `Craft.Menu` abierto y `frame` no esté dentro de él (el `DropdownMenu` de Radix es modal); al cerrarse el menú no se abre nada solo, aparece en el siguiente `OnEnter`. |
| `Craft.Tooltip.Detach(frame)`      | `(Frame) → void`                   | Elimina los scripts OnEnter/OnLeave de tooltip del frame. No afecta otros scripts del frame.    |
| `Craft.Tooltip.Show(anchor, cfg)`  | `(Frame, table) → void`            | Muestra el tooltip manualmente sobre `anchor` con la config dada. Sin `delay` (default 0) es inmediato; con `delay` (FR-127) se difiere y un `Hide` lo cancela. |
| `Craft.Tooltip.Hide()`             | `() → void`                        | Oculta el tooltip activo y cancela cualquier timer de delay pendiente.                          |
| `Craft.Tooltip.GetOwner()`         | `() → Frame?`                      | FR-127: el `anchor` del tooltip abierto (`nil` oculto o en fade-out). Para re-pintarlo tras un clic: `if Craft.Tooltip.GetOwner() == btn then Craft.Tooltip.Show(btn, cfg) end` (equivale a `GameTooltip:IsOwned`). |
| `Craft.Tooltip.IsShown()`          | `() → boolean`                     | FR-127: si hay un tooltip abierto.                                                              |

### Config (para `Attach` y `Show`)

| Clave      | Tipo     | Default  | Descripción                                                              |
|------------|----------|----------|--------------------------------------------------------------------------|
| `text`     | string \| function | —  | Texto visible del tooltip (requerido salvo que haya `lines`/`title`). FR-127: `function(anchor) → string`, evaluada en cada `Show` / hover de `Attach` (la config no se muta). |
| `lines`    | table \| function | `nil` | FR-127 — líneas estructuradas (`AddLine`/`AddDoubleLine` de `GameTooltip`). Cada entrada: `string` = una columna (hace wrap) o `{ left, right, leftColor, rightColor, color, separator }`: con `right` es **doble línea** — la derecha auto-dimensionada y alineada al borde derecho del contenido, la izquierda se trunca con elipsis. Colores = nombre de token (se re-resuelve con el tema) o `{r,g,b,a}`; default `popoverForeground`. `separator = true` = hairline `border` a sangre (como el separador de Menu, `my-1`) antes de la línea; una entrada sin texto es solo el separador. Ancho = máx(izq + 12 + der) acotado por `maxWidth`; 2px entre líneas. También función `(anchor) → table`. |
| `title`    | string \| function | `nil` | FR-127 — primera línea en `fontMedium` (`popoverForeground`). Con `title`/`lines`, `text` pasa a ser una línea con wrap tras el título; `icon` solo aplica al modo texto plano. |
| `icon`     | string   | `nil`    | Nombre Lucide (e.g. `"info"`, `"alert-triangle"`). Usa `Craft.Icons`.   |
| `delay`    | number   | `300` (Attach) / `0` (Show) | Milisegundos antes de que el tooltip aparezca tras OnEnter (`Attach`) o tras la llamada (`Show`, FR-127). |
| `maxWidth` | number   | `240`    | Ancho máximo en px antes de hacer wrap del texto.                        |
| `side`     | string   | `nil`    | Lado forzado (`side` de shadcn): `"top"`\|`"bottom"`\|`"left"`\|`"right"`. `nil` = automático (arriba si cabe, si no abajo). Ver §Lado. |
| `fontFlags`| string   | `nil`    | FR-101: flags de fuente SOLO para este tooltip (4.º arg de `Theme.applyFont`; `""` = sin contorno). `nil` = el `t.fontFlags` global del tema. Se re-resuelve en cada `Show`: no se "pega" al siguiente. |

## Notas de implementación

**Singleton pattern**: `Craft.Tooltip._frame` se crea una sola vez en `Craft.Tooltip._init()`, llamado al cargar el addon. Los consumidores nunca crean ni destruyen el frame — solo llaman a `Attach` / `Show` / `Hide`.

**Lado (`side`)** — paridad con el prop `side` de shadcn. Sin `side`, Craft prefiere
arriba. Como `avoidCollisions` de Radix, el lado pedido (o el automático) **se voltea al
opuesto solo si no cabe en pantalla y el opuesto sí** (FR-136; antes el chequeo de "arriba"
estaba invertido y cerca del borde superior `SetClampedToScreen` montaba el tooltip sobre el
ancla). Con `"left"`/`"right"` el tooltip se ancla al lateral del
ancla y la animación de entrada **desliza en horizontal** (el `_slide` guarda un `axis`; el
efecto aplica el offset en X o en Y según ese campo, siempre hacia el ancla, como
`slide-in-from-{side}` de shadcn v4). `"top"`/`"bottom"` piden la variante vertical
correspondiente.

**Escala del ancla (FR-136)** — como Menu/Popover/Select: el frame vive en `UIParent`, y en
cada `Show` calcula `TT._baseScale = ancla:GetEffectiveScale() / UIParent:GetEffectiveScale()`
(bajo `pcall` + `issecretvalue`; cualquier respuesta rara → 1). Mide a `SetScale(base)` y el
zoom de entrada multiplica sobre esa base (`base × lerp(motionZoomFrom, 1, alpha)`). Los
offsets (`OFFSET`, slide) están en unidades del propio tooltip, así que crecen con el ancla.
El chequeo de bordes trabaja en unidades de `UIParent` (bordes del ancla y tamaño del
tooltip × base). Sin opt-in: con un ancla a escala de la UI la base es 1 y nada cambia. La
base se recalcula en cada `Show`: un tooltip no hereda la escala del anterior.

El caso que lo motivó (FR-067): las filas de un `Craft.Menu` están apiladas, así que un
tooltip arriba o abajo taparía las filas vecinas; ancladas a la derecha caen fuera del panel.

**Delay con C_Timer**: El delay se gestiona con `C_Timer.After(delay / 1000, fn)`. La función `fn` verifica que el anchor todavía esté bajo el cursor antes de mostrar (`anchor:IsMouseOver()`). La referencia al timer se guarda en `Craft.Tooltip._pendingTimer` para poder cancelarlo en `Hide()` o en OnLeave. Cancelar con `_pendingTimer:Cancel()` si el timer aún no disparó.

```lua
-- Cancelar timer pendiente al salir del anchor antes del delay
frame:SetScript("OnLeave", function()
  if Craft.Tooltip._pendingTimer then
    Craft.Tooltip._pendingTimer:Cancel()
    Craft.Tooltip._pendingTimer = nil
  end
  Craft.Tooltip.Hide()
end)
```

**Attach no sobreescribe otros scripts**: Usar `HookScript` en lugar de `SetScript` para OnEnter y OnLeave, de modo que otros scripts existentes en el frame no se pierdan. Si el frame ya tiene un attachment previo de Craft.Tooltip, desregistrar los hooks anteriores antes de agregar nuevos — guardar las funciones de hook en una tabla indexada por frame (`Craft.Tooltip._hooks[frame]`).

**Tamaño del frame tras actualizar texto**: Después de llamar `_text:SetText(config.text)`, calcular el ancho resultante con `_text:GetStringWidth()`. El ancho del frame = `min(config.maxWidth, textWidth) + paddingH * 2 + (icon ? iconSize + gap : 0)`, donde `paddingH = 12` y `gap = 6`. La altura = `_text:GetStringHeight() + paddingV * 2`, donde `paddingV = 6`. Llamar `_frame:SetSize(w, h)` antes del SetPoint para que el clamping de pantalla use las dimensiones correctas.

**Ícono opcional**: Si `config.icon` es nil, `_icon:Hide()` y el texto ancla desde 12px del borde izquierdo. Si `config.icon` existe, `_icon:Show()`, posicionarlo con `SetPoint("LEFT", _frame, "LEFT", 12, 0)`, y el texto con `SetPoint("LEFT", _icon, "RIGHT", 6, 0)` (gap-1.5 = 6px).

**Flecha — omisión Craft (no "Lyra no tiene flecha"):** shadcn Lyra **sí** define
`.cn-tooltip-arrow` (`size-2.5 rotate-45 rounded-none`) y el tsx renderiza
`TooltipPrimitive.Arrow`. Craft **no** la implementa (omisión de alcance MVP — la rotación
de texturas en WoW es engorrosa). El tooltip aparece adyacente al anchor sin indicador.

**Sin animación de entrada — simplificación:** shadcn anima la entrada (fade/zoom/slide
según el lado); Craft hace `Show()` instantáneo. Omisión de alcance MVP.

**Borde 1px**: Usar `SetBackdrop` con `edgeFile = "Interface\\BUTTONS\\WHITE8X8"` y `edgeSize = 1`, o cuatro texturas de 1px. La textura de borde se colorea con `SetBackdropBorderColor(t.border.r, t.border.g, t.border.b, t.border.a)`. En dark mode, `t.border = {r=1, g=1, b=1, a=0.1}`.

**TOOLTIP strata**: garantiza visibilidad sobre casi todo. El único nivel superior en WoW es `UIParent` mismo. Los tooltips del juego (GameTooltip) también usan esta strata — no hay conflicto porque Craft.Tooltip se oculta antes de que GameTooltip aparezca en frames de items de inventario.

**Re-theme**: registrar `Craft.Theme.register` para actualizar los colores del `_frame` singleton cuando el tema cambia, igual que cualquier otro componente.
