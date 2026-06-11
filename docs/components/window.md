# Component: Window

> Referencia shadcn: **ninguna** — shadcn es web (el SO da el chrome de ventana).
> Componente Craft-original (FR-005). WoW frame base: `Frame` movible + redimensionable.

## Propósito

El **main frame** de una ventana de addon: title bar (drag + título/descripción + botón
de cierre), área de contenido, handle de resize abajo-derecha, min/max size, clamp a
pantalla y cierre con Escape. El dev mete su UI (p. ej. un `Craft.Sidebar` + `Craft.Panel`)
dentro de `GetContent()`. Modela el main frame de Craft_Browser.

## Por qué un componente aparte (no Panel/Dialog)

Una ventana top-level tiene necesidades que Panel (contenedor embebido) y Dialog (modal
efímero) no cubren: arrastre por el title bar, **resize** con handle + bounds, persistencia
de posición/tamaño (`onMoved`/`onResized`), strata DIALOG, clamp, Escape. Se aísla en
`Craft.Window`.

## Jerarquía de frames WoW

```
window.frame          (Frame, strata=DIALOG, movable + resizable + clamped)
├── _ringTex          (Texture BACKGROUND -1)   ring 1px foreground/10
├── _bg               (Texture BACKGROUND -2)   fondo t.popover (inset 1px)
├── _titleBar         (Frame)                    drag handle; alto = según contenido
│   ├── _titleBarBg   (Texture)                  fondo (popover +0.03, más claro)
│   ├── _titleBarSep  (Texture BORDER, 1px)      borde inferior t.border
│   ├── _title        (FontString)               fontBold, fontSizeLg, t.foreground
│   ├── _desc         (FontString, opcional)     font, fontSize, t.mutedForeground
│   └── _closeBtn     (Frame 24×24, opcional)    "x" — hover accent
├── _content          (Frame)                    GetContent() — el dev añade su UI
└── _resize           (Button 16×16, opcional)   grip abajo-derecha → StartSizing
```

El `_content` se ancla `TOPLEFT`→`_titleBar.BOTTOMLEFT` y `BOTTOMRIGHT`→frame, así
**crece automáticamente** al redimensionar la ventana.

## Comportamiento

- **movable** (default true): drag del title bar → `StartMoving`/`StopMovingOrSizing`;
  `onMoved(self, x, y)` al soltar.
- **resizable** (default true): `SetResizable(true)` + `SetResizeBounds(minW, minH, maxW, maxH)`
  (fallback legacy `SetMinResize`/`SetMaxResize`); handle abajo-derecha → `StartSizing("BOTTOMRIGHT")`;
  `onResized(self, w, h)` al soltar.
- **closable** (default true): botón "x" → `Close()` (dispara `onClose`, luego oculta).
- **closeOnEscape** (default true): registra el frame en `UISpecialFrames` (Escape lo oculta).
- Creada **oculta**; el caller llama `Show()`/`Toggle()`. Centrada al crear.

## Dimensiones / tokens

| Elemento | Valor / Token |
|---|---|
| Fondo | `t.popover` |
| Ring perimetral | `t.foreground` a=0.10 (1px) |
| Title bar fondo | `t.popover` + 0.03 (más claro) |
| Title bar borde-inferior | `t.border` (1px) |
| Título | `t.fontBold`, `t.fontSizeLg` (14px), `t.foreground` |
| Descripción | `t.font`, `t.fontSize` (12px), `t.mutedForeground` |
| Close "x" | `t.mutedForeground` → `t.foreground` en hover (+ `t.accent` bg) |
| Resize grip | ícono `grip-vertical`, `t.mutedForeground` a=0.8 |
| Padding title bar | `t.spacingLg` (16px) |

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|---|---|---|---|
| `title` | string | `""` | Título en el title bar |
| `description` | string | nil | Subtítulo bajo el título |
| `width` / `height` | number | 640 / 420 | Tamaño inicial |
| `minWidth` / `minHeight` | number | 360 / 240 | Límite mínimo de resize |
| `maxWidth` / `maxHeight` | number | nil | Límite máximo (opcional) |
| `movable` | boolean | true | Permite arrastrar por el title bar |
| `resizable` | boolean | true | Muestra el handle de resize |
| `closable` | boolean | true | Muestra el botón "x" |
| `closeOnEscape` | boolean | true | Escape cierra la ventana (`UISpecialFrames`) |
| `onMoved` | function | nil | `fn(self, x, y)` al terminar de arrastrar |
| `onResized` | function | nil | `fn(self, w, h)` al terminar de redimensionar |
| `onClose` | function | nil | `fn(self)` al cerrar (botón "x" o `Close()`) |

## API pública

| Método | Descripción |
|---|---|
| `GetFrame()` | Frame raíz |
| `GetContent()` | Frame de contenido — el dev añade aquí su UI |
| `GetTitleBar()` | Frame del title bar |
| `SetTitle(text)` / `SetDescription(text)` | Actualizan el título / descripción |
| `Show()` / `Hide()` / `Toggle()` / `IsShown()` | Visibilidad |
| `Close()` | Dispara `onClose` y oculta (igual que el botón "x") |
| `Center()` | Re-centra en la pantalla |

## Notas de implementación

- **Resize**: `frame:SetResizeBounds(minW, minH, maxW, maxH)` (10.0+) con fallback a
  `SetMinResize`/`SetMaxResize`. El handle hace `StartSizing("BOTTOMRIGHT")` y al soltar
  `StopMovingOrSizing()` + `onResized`. El `_content` sigue por anchors (no re-layout manual).
- **Persistencia**: el componente NO guarda posición/tamaño; el dev lo hace en `onMoved`/
  `onResized` (p. ej. `frame:GetLeft()`/`GetTop()`, `GetWidth()`/`GetHeight()` en su DB).
- **Escape vs onClose**: el botón "x" y `Close()` disparan `onClose`. Escape (vía
  `UISpecialFrames`) solo oculta — para persistir estado, usar `onMoved`/`onResized` en vivo.
- **EnableMouse(true)** en el frame raíz para no dejar pasar clics al mundo del juego.
- **Radius = 0** y ring 1px: mismo patrón de superficie que Panel/Dialog.
