# Component: Panel

> Referencia shadcn: `card` — WoW frame base: `Frame`

## CSS real de Lyra (referencia)

```css
.cn-card {
  @apply ring-foreground/10 bg-card text-card-foreground gap-4 overflow-hidden
         rounded-none py-4 text-xs/relaxed ring-1;
}
.cn-card-header {
  @apply gap-1 px-4;
}
.cn-card-title {
  @apply text-sm font-medium;
}
.cn-card-description {
  @apply text-muted-foreground text-xs/relaxed;
}
.cn-card-content {
  @apply px-4;
}
.cn-card-footer {
  @apply border-t p-4;
}
```

## Propósito

Contenedor estático con fondo y borde que agrupa contenido relacionado en secciones opcionales: header (título + descripción), content (área principal) y footer (acciones).

## Jerarquía de frames WoW

```
panel.frame          (Frame, strata=MEDIUM, level=BACKGROUND -1)
├── panel._bg        (Texture, BACKGROUND -2)   fondo sólido
├── panel._ring      (Frame, 1px outward)        ring perimetral 1px (ADR-0011)
├── panel._header    (Frame, opcional)           zona superior
│   ├── panel._title   (FontString)             título principal
│   ├── panel._desc    (FontString, opcional)   descripción secundaria
│   └── panel._action  (Frame, opcional)         slot CardAction, esquina sup-derecha (FR-039)
├── panel._content   (Frame)                    área editable por el dev
└── panel._footer    (Frame, opcional)           zona inferior de acciones
    └── panel._footerBorder (Frame, 1px alto)   línea separadora top (ADR-0011)
```

**Notas de stacking:** `_ring` es un Frame hijo que cubre el `panel.frame` completo (outward 0px en todos los lados), pintado con `t.foreground` a=0.10 (Lyra `ring-foreground/10`; {r=0.980,g=0.980,b=0.980,a=0.10}). `_bg` ocupa el área interna completa del frame. El ring se dibuja sobre el fondo sin afectar el layout.

### Patrón ring-1 ring-foreground/10 (ADR-0011)

En CSS, `ring-1` es un `box-shadow` outline de 1px que **no afecta el layout**. En WoW no existe box-shadow, por lo que se implementa como un Frame hijo de 1px de grosor que cubre el panel por fuera. Se usan `Craft.Theme.SetPixelHeight` / `Craft.Theme.SetPixelWidth` para garantizar exactamente 1px independientemente del DPI:

```lua
-- Ring perimetral 1px outward
panel._ring = CreateFrame("Frame", nil, panel.frame)
panel._ring:SetPoint("TOPLEFT",     panel.frame, "TOPLEFT",     0,  0)
panel._ring:SetPoint("BOTTOMRIGHT", panel.frame, "BOTTOMRIGHT", 0,  0)
panel._ring._tex = panel._ring:CreateTexture(nil, "BACKGROUND")
panel._ring._tex:SetAllPoints(panel._ring)
panel._ring._tex:SetColorTexture(0.980, 0.980, 0.980, 0.10)
-- El ring en sí no tiene grosor propio; actúa como overlay transparente
-- con el borde siendo la diferencia visual entre _ring y _bg
```

> En la práctica, la técnica más sencilla es dibujar `_ring` como una textura de color sobre el frame exterior y dejar `_bg` insetado 1px, de forma que el ring sea visible como un borde de 1px.

```lua
panel._bg:SetPoint("TOPLEFT",     panel.frame, "TOPLEFT",      1, -1)
panel._bg:SetPoint("BOTTOMRIGHT", panel.frame, "BOTTOMRIGHT", -1,  1)
```

## Dimensiones

| Elemento | Valor | Origen CSS |
|---|---|---|
| Ring perimetral | 1px (todos los lados) | `ring-1` |
| Padding vertical del panel | 16px (`t.spacingLg`) | `py-4` |
| Gap entre secciones (header/content/footer) | 16px (`t.spacingLg`) | `gap-4` |
| Header padding horizontal | 16px (`t.spacingLg`) | `px-4` |
| Gap título → descripción | 4px (`t.spacingXs`) | `gap-1` |
| Title font size | 14px (`t.fontSizeLg`) | `text-sm` |
| Description font size | 12px (`t.fontSize`) | `text-xs` |
| Description line-height | `leading-relaxed` 1.625 → `SetSpacing ≈ size*0.625` (8px @12px) | `text-xs/relaxed` |
| Content padding horizontal | 16px (`t.spacingLg`), override `padding` | `px-4` |
| Content padding vertical | 16px (`t.spacingLg`), override `paddingY`/`flush` (FR-046) | `py-4` |
| Footer padding (todos los lados) | 16px (`t.spacingLg`) | `p-4` |
| Footer borde-top | 1px | `border-t` (ADR-0011) |

> **Nota:** `text-sm` = 14px y `text-xs` = 12px en Tailwind/Lyra. El título usa `text-sm font-medium` (14px, no 12px).

## Variantes / Configuraciones

| Variante | Descripción |
|---|---|
| Solo content | Sin header ni footer — `_content` ocupa todo el frame |
| Con header | `_content` empieza bajo el header |
| Con footer | `_content` termina sobre el footer; `_footer` tiene borde-top 1px |
| Completo | Header + content + footer |

### CardAction — slot de acción en el header (FR-039)

shadcn Card ofrece el slot **`CardAction`** — un área en la esquina superior derecha
del header para acciones/badges/iconos complementarios (típicamente un ✕ de cerrar).
Craft.Panel lo implementa vía `config.action` / `SetHeaderAction()` (FR-039).

Cuando hay una acción, el header se maqueta como una rejilla `[1fr auto]` con
**`Craft.Grid`** (en vez del layout de ancla única): la columna `1fr` apila
título + descripción, y la columna `auto` lleva la acción anclada arriba-derecha
(`justify-self:end`, `self-start`, `row-span` completo) — el mapeo directo de
`CardAction = col-start-2 row-span-2 self-start justify-self-end` del `card.tsx`.
El título pasa a una sola línea (`SetWordWrap(false)`, `truncate`) porque su ancho
queda acotado a la columna `1fr`. Sin acción, el header conserva el layout histórico
sin cambios. El caller instancia su propio widget (p. ej. `Craft.Button` variant
`ghost` size `icon` con el icono `x`), igual que con el footer.

## Estados

| Estado | Comportamiento visual |
|---|---|
| Default | Fondo `t.card`, ring `t.border` 1px |
| Sin interacción | Panel es estático — no tiene estados hover ni focus propios |
| Contenido deshabilitado | Los hijos gestionan su propio estado disabled |

> **Focus rings:** NO implementar (WoW es mouse-only — ADR-0011).

## Mapa de tokens

| Elemento | Token | Valor dark mode |
|---|---|---|
| Fondo del panel | `t.card` | {r=0.091, g=0.091, b=0.091} |
| Ring perimetral | `t.foreground` a=0.10 (`ring-foreground/10`) | {r=0.980, g=0.980, b=0.980, a=0.10} |
| Separador footer-top | `t.border` | {r=1, g=1, b=1, a=0.10} |
| Texto del título | `t.cardForeground` | {r=0.980, g=0.980, b=0.980} |
| Fuente del título | `t.fontHeading or t.fontMedium`, `t.fontSizeLg` (14px) — Lyra NO usa bold/semibold (`text-sm font-medium`) | — |
| Texto de descripción | `t.mutedForeground` | {r=0.630, g=0.630, b=0.630} |
| Fuente de descripción | `t.font`, `t.fontSize` (12px); line-height `leading-relaxed` 1.625 (`SetSpacing ≈ size*0.625` = 8px @12px, `text-xs/relaxed`) | — |
| Padding content / header / footer | `t.spacingLg` (16px) | — |

## Config — `Create(parent, config)`

| Parámetro | Tipo | Default | Descripción |
|---|---|---|---|
| `width` | number | nil | Ancho total en px. Si nil, el dev lo fija con anchors/`SetWidth` |
| `height` | number | nil | Alto total en px. Si nil, el dev lo fija con anchors/`SetHeight` — el Panel **no** auto-crece con el contenido (es dev-sized, a diferencia de Dialog) |
| `title` | string | nil | Texto del título en el header; omitir oculta el header |
| `description` | string | nil | Texto de descripción bajo el título |
| `footer` | Frame | nil | Frame a insertar en la zona footer; omitir oculta el footer |
| `action` | Frame | nil | Widget de acción del header (CardAction, FR-039); reparentado y anclado arriba-derecha. Fuerza el layout de header con `Craft.Grid` `[1fr auto]` |
| `padding` | number | 16 | Override del padding **horizontal** de content (`px-4`) |
| `paddingY` | number | nil (=`lg`, 16) | Override del padding **vertical** de content (`py-4`). **Solo** aplica a la rama sin header y sin footer (con header el gap es `header:BOTTOM − lg`, con footer `footer:TOP + lg`; no se tocan). `paddingY=0` → content pegado arriba/abajo (FR-046) |
| `flush` | boolean | false | Full-bleed: azúcar que fuerza `padding=0` **y** `paddingY=0` — el hijo cuelga del ring por los 4 lados (Card como marco: sidebar, imagen, tabla, mapa). FR-046 |

## API pública

> **Corrección post-testing en WoW:** `SetSize()` fue eliminado del API público. El tamaño del Panel se controla directamente via `GetFrame():SetSize(w, h)` o anchors WoW, igual que cualquier frame nativo.

| Método | Retorno | Descripción |
|---|---|---|
| `GetFrame()` | Frame | Retorna `panel.frame` — el contenedor raíz |
| `GetContent()` | Frame | Retorna `panel._content` — aquí se agregan frames hijos |
| `GetHeader()` | Frame \| nil | Retorna `panel._header` o nil si no existe |
| `GetFooter()` | Frame \| nil | Retorna `panel._footer` o nil si no existe |
| `GetHeaderAction()` | Frame \| nil | Retorna el widget de acción del header (FR-039) o nil |
| `SetHeaderAction(frame)` | void | Setea/reemplaza la acción del header; `nil` la limpia. Re-maqueta el header como grid `[1fr auto]` |
| `SetTitle(text)` | void | Actualiza el texto de `panel._title`; crea el header si no existía |
| `SetDescription(text)` | void | Actualiza `panel._desc`; expande el header si es necesario |

## Notas de implementación

**Ring 1px perimetral (ADR-0011):** el Panel usa `ring-1 ring-foreground/10` en Lyra, que es un outline de 1px que no afecta el layout. En WoW se implementa pintando el frame exterior con el color del ring y dejando `_bg` insetado 1px. Usar `Craft.Theme.SetPixelHeight` / `Craft.Theme.SetPixelWidth` para el frame de footerBorder:

```lua
-- Footer border top (1px)
panel._footerBorder = CreateFrame("Frame", nil, panel._footer)
Craft.Theme.SetPixelHeight(panel._footerBorder, 1)
panel._footerBorder:SetPoint("TOPLEFT",  panel._footer, "TOPLEFT",  0, 0)
panel._footerBorder:SetPoint("TOPRIGHT", panel._footer, "TOPRIGHT", 0, 0)
panel._footerBorder._tex = panel._footerBorder:CreateTexture(nil, "BACKGROUND")
panel._footerBorder._tex:SetAllPoints(panel._footerBorder)
panel._footerBorder._tex:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)
```

**Ring perimetral:** el bg se inseta 1px para que el ring sea visible:
```lua
panel._bg:SetPoint("TOPLEFT",     panel.frame, "TOPLEFT",      1, -1)
panel._bg:SetPoint("BOTTOMRIGHT", panel.frame, "BOTTOMRIGHT", -1,  1)
panel._bg:SetColorTexture(t.card.r, t.card.g, t.card.b)
```
El frame exterior (`panel.frame`) se pinta con el color del ring:
```lua
panel._ringTex = panel.frame:CreateTexture(nil, "BACKGROUND", nil, -1)
panel._ringTex:SetAllPoints(panel.frame)
panel._ringTex:SetColorTexture(t.foreground.r, t.foreground.g, t.foreground.b, 0.10)
```

**Scroll:** el Panel no scrollea por sí mismo. Para contenido largo, el dev debe agregar un `Craft.Scroll` dentro de `GetContent()`.

**Dev-sized (sin auto-grow):** el Panel **no** calcula su altura desde el contenido (a diferencia de Dialog). Si `config.height` es nil, el dev fija el tamaño con `GetFrame():SetHeight()` o anchors. El contenido se estira entre header y footer dentro de ese tamaño; el dev es responsable de que sea suficiente.

**overflow-hidden:** el frame usa `SetClipsChildren(true)` (`.cn-card overflow-hidden`) — el contenido que exceda los límites del panel se recorta. Los popovers (p.ej. el panel de `Craft.Select`) van en UIParent, no como hijos del panel, así que no se recortan.

**Footer externo:** `config.footer` es un Frame ya construido que se reparenta a `panel._footer`. El dev es responsable de dimensionarlo; el footer lo inseta con `p-4` (16px en los 4 lados, `.cn-card-footer p-4`) sobre el separador `border-t`.

**Header con ancla única (bug #2, CLAUDE.md):** el título usa ancla única `TOPLEFT` para que WoW auto-dimensione el string desde su contenido — nunca doble ancla horizontal (deriva el ancho del padre y deja el texto invisible hasta `/reload` si el header tiene width=0 al anclar). La descripción usa `TOPLEFT` único + `SetWidth` explícito (ancho del panel − `2·lg`) dentro de `_applyTheme` para que `SetWordWrap(true)` reparta el texto en varias líneas. El gap header→content es un único `gap-4` (16px): el alto del header NO incluye padding inferior; el espaciado lo aporta el `-lg` del ancla del content.

**Header con acción — grid `[1fr auto]` (FR-039):** cuando hay `action`, el header usa
`Craft.Grid` en lugar del layout de ancla única. Filas en **px** (`titleH`/`descH`) — no
`auto` — para no depender del alto natural de un FontString (aún no medido cuando `Grid:Add`
cachea `_naturalH`); replica el supuesto de descripción de una línea del path manual. La
instancia de Grid se recrea en cada `_layoutFrames` (Grid no retiene frames y el nº de filas
depende de si hay descripción). El alto del header es `lg + max(bloque de texto, alto de la
acción)`: con `self-start`, una acción más alta que título+descripción deja el hueco debajo.

**Re-layout en resize (`OnSizeChanged`):** el Panel engancha `OnSizeChanged` de `panel.frame`
para recomputar el header (grid + ancho de word-wrap de la descripción) si el frame se
dimensiona **después** de `Create()` — el `Grid:Layout()` hace `return` temprano si el header
tiene ancho 0 (mismo guard que Flex). Es idempotente: recomputa geometría idéntica cuando el
tamaño no cambia.

**Radius = 0:** ninguna textura usa `SetTexCoord` para esquinas redondeadas. Todas las texturas son rectangulares sin modificación (`rounded-none` en Lyra).
