# Component: Dialog

> Referencia shadcn: `dialog` — WoW frame base: `Frame` con `SetMovable(true)`

## Propósito

Ventana flotante draggable que se eleva sobre el contenido de la UI para capturar la atención del usuario; contiene una barra de título (drag handle), área de contenido editable y zona de acciones opcional.

## Jerarquía de frames WoW

```
dialog.frame           (Frame, strata=HIGH)           raíz draggable
├── dialog._bg         (Texture, BACKGROUND)          fondo del dialog
├── dialog._border     (Texture, BACKGROUND -1)       borde perimetral 1px
├── dialog._titleBar   (Frame, 40px alto)             drag handle + título
│   ├── dialog._title  (FontString)                   texto del título
│   └── dialog._closeBtn (Frame, 24×24px)             botón de cierre "×"
│       ├── dialog._closeBg  (Texture)                fondo hover/press
│       └── dialog._closeX  (FontString)              símbolo "×"
├── dialog._separator  (Texture, 1px alto)            línea entre titleBar y content
├── dialog._content    (Frame)                        área editable por el dev
└── dialog._footer     (Frame, 56px alto, opcional)   zona de acciones
    └── dialog._footerBorder (Texture, 1px alto)      línea separadora top
```

## Dimensiones

| Elemento | Valor |
|---|---|
| TitleBar height | 40px |
| Separator height | 1px |
| Footer height | 56px |
| Footer borde-top | 1px |
| Content padding (todos los lados) | 16px (`t.spacingLg`) |
| TitleBar padding horizontal (título) | 16px (`t.spacingLg`) |
| Footer padding horizontal | 16px (`t.spacingLg`) |
| CloseBtn size | 24×24px |
| CloseBtn offset desde borde top-right | 8px (`t.spacingSm`) en X e Y |
| Min height total | 160px |
| Title font size | 14px (`t.fontSizeLg`) |
| CloseBtn "×" font size | 14px |
| Border width | 1px |

## Variantes / Configuraciones

| Size | Width |
|---|---|
| `sm` | 400px |
| `default` | 520px |
| `lg` | 640px |
| `xl` | 760px |

La altura es automática según el contenido de `_content`; mínimo 160px. Si se incluye `_footer`, sumar 57px (56px + 1px separador) al mínimo.

## Estados

| Elemento | Estado | Visual |
|---|---|---|
| Dialog | Default | Visible, strata HIGH, fondo `t.card`, borde `t.border` |
| Dialog | Oculto | `Hide()` — no consume input |
| CloseBtn | Default | Fondo transparente, "×" en `t.mutedForeground` |
| CloseBtn | Hover | Fondo `t.accent`, "×" en `t.foreground` |
| CloseBtn | Press | Fondo `t.accent` con `a=0.7` |
| TitleBar | Dragging | Cursor cambia — el frame se mueve con el mouse |

## Mapa de tokens

| Elemento | Token |
|---|---|
| Fondo del dialog | `t.card` |
| Borde perimetral | `t.border` |
| Separador (titleBar / content) | `t.border` |
| Borde-top del footer | `t.border` |
| Texto del título | `t.foreground` |
| Fuente del título | `t.fontBold`, `t.fontSizeLg` (14px) |
| CloseBtn "×" default | `t.mutedForeground` |
| CloseBtn "×" hover | `t.foreground` |
| CloseBtn fondo hover | `t.accent` |
| CloseBtn fondo press | `t.accent` (a=0.7) |
| Content padding | `t.spacingLg` (16px) |
| Footer padding horizontal | `t.spacingLg` (16px) |
| CloseBtn offset | `t.spacingSm` (8px) |

## Config — `Create(parent, config)`

| Parámetro | Tipo | Default | Descripción |
|---|---|---|---|
| `title` | string | `""` | Texto del título en la barra |
| `size` | string | `"default"` | Uno de: `"sm"`, `"default"`, `"lg"`, `"xl"` |
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
dialog.frame:SetFrameStrata("HIGH")
dialog.frame:SetMovable(true)
dialog.frame:SetClampedToScreen(true)
dialog.frame:RegisterForDrag("LeftButton")
```
`SetClampedToScreen(true)` impide que el usuario arrastre el dialog fuera del viewport.

**Drag desde la titleBar:**
```lua
dialog._titleBar:SetScript("OnMouseDown", function()
    dialog.frame:StartMoving()
end)
dialog._titleBar:SetScript("OnMouseUp", function()
    dialog.frame:StopMovingOrSizing()
end)
```
La titleBar debe tener `EnableMouse(true)` para recibir los eventos.

**Cierre con Escape (`closeOnEscape = true`):**
```lua
-- Registrar con nombre único por instancia
dialog.frame:SetName("Craft_Dialog_" .. instanceId)
table.insert(UISpecialFrames, dialog.frame:GetName())
```
`UISpecialFrames` es el mecanismo nativo de WoW para que Escape cierre frames.

**Botón de cierre:**
El `_closeBtn` es un Frame con `EnableMouse(true)`. Los scripts `OnEnter`/`OnLeave` cambian el color de `_closeBg`. En `OnMouseDown` invoca `onClose` si fue provisto y luego `Hide()`.

**Borde 1px:** misma técnica que Panel — `_border` cubre el frame completo, `_bg` insetado 1px:
```lua
dialog._bg:SetPoint("TOPLEFT",     dialog.frame, "TOPLEFT",     1, -1)
dialog._bg:SetPoint("BOTTOMRIGHT", dialog.frame, "BOTTOMRIGHT", -1,  1)
```

**Footer opcional:** si `config.footer` no se pasa, `_footer` no se crea y `_content` se extiende hasta el borde inferior (menos 1px de borde).

**Radius = 0:** sin esquinas redondeadas en ninguna textura.

**Centrado inicial:** para centrar el dialog al abrirlo la primera vez:
```lua
dialog.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
```
Tras ser movido por el usuario, la posición persiste hasta que se llame explícitamente a re-centrar.
