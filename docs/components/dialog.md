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

## Jerarquía de frames WoW

```
dialog._overlay        (Frame, strata=HIGH, UIParent)  backdrop modal black/10, bloquea clics
dialog.frame           (Frame, strata=DIALOG)          raíz draggable (sobre el overlay)
├── dialog._bg         (Texture, BACKGROUND)          fondo del dialog
├── dialog._header     (Frame, opcional)              zona de título — drag handle
│   ├── dialog._title  (FontString)                   texto del título (text-sm)
│   ├── dialog._desc   (FontString, opcional)         descripción (text-xs)
│   └── dialog._closeBtn (Frame, 24×24px)             botón de cierre "×"
│       ├── dialog._closeBg  (Texture)                fondo hover/press
│       └── dialog._closeX  (FontString)              símbolo "×"
├── dialog._content    (Frame)                        área editable por el dev
└── dialog._footer     (Frame, opcional)              zona de acciones
    └── dialog._footerBorder (Frame, 1px alto)        línea separadora top (ADR-0011)
```

**Overlay modal (`.cn-dialog-overlay`):** un Frame full-screen en UIParent, strata HIGH
(el dialog está en DIALOG, por encima), con fondo negro `a=0.10` (`bg-black/10`) y
`EnableMouse(true)` para bloquear clics a la UI de abajo → el dialog es modal. WoW no tiene
`backdrop-blur`, así que es solo el relleno plano (sutil). Su visibilidad se sincroniza con
el dialog vía hooks `OnShow`/`OnHide` (cubre cierre por X, Escape, `Hide()` y `Toggle()`).

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
| Dialog | Default | Visible, strata HIGH, fondo `t.popover`, ring `t.border` 1px |
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

## Notas de implementación

**Strata y clamp:**
```lua
dialog.frame:SetFrameStrata("DIALOG")  -- por encima del overlay (HIGH)
dialog.frame:SetMovable(true)
dialog.frame:SetClampedToScreen(true)
dialog.frame:RegisterForDrag("LeftButton")
```
`SetClampedToScreen(true)` impide que el usuario arrastre el dialog fuera del viewport.
El `_overlay` (HIGH) queda por debajo del dialog (DIALOG) y por encima de la UI normal.

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
El `_closeBtn` es un Frame con `EnableMouse(true)`, posicionado a 8px (`t.spacingSm`) del borde top-right. Los scripts `OnEnter`/`OnLeave` cambian el color de `_closeBg`. En `OnMouseDown` invoca `onClose` si fue provisto y luego `Hide()`.

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

**Footer opcional:** si `config.footer` no se pasa, `_footer` no se crea y `_content` se extiende hasta el borde inferior (menos el padding exterior).

**Radius = 0:** sin esquinas redondeadas en ninguna textura (`rounded-none` en Lyra).

**Centrado inicial:** para centrar el dialog al abrirlo la primera vez:
```lua
dialog.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
```
Tras ser movido por el usuario, la posición persiste hasta que se llame explícitamente a re-centrar.
