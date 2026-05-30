# Component: Panel

> Referencia shadcn: `card` — WoW frame base: `Frame`

## Propósito

Contenedor estático con fondo y borde que agrupa contenido relacionado en secciones opcionales: header (título + descripción), content (área principal) y footer (acciones).

## Jerarquía de frames WoW

```
panel.frame          (Frame, strata=MEDIUM, level=BACKGROUND -1)
├── panel._bg        (Texture, BACKGROUND -2)   fondo sólido
├── panel._border    (Texture, BACKGROUND -3)   borde perimetral 1px
├── panel._header    (Frame, opcional)           zona superior
│   ├── panel._title   (FontString)             título principal
│   └── panel._desc    (FontString, opcional)   descripción secundaria
├── panel._content   (Frame)                    área editable por el dev
└── panel._footer    (Frame, opcional)           zona inferior de acciones
    └── panel._footerBorder (Texture)           línea separadora top
```

**Notas de stacking:** `_border` usa el frame externo pintado con `t.border`; `_bg` se inseta 1px hacia adentro para que el borde quede visible. Alternativamente, `_bg` cubre todo y `_border` es un Frame-wrapper 1px mayor que `_bg`, pintado con `t.border`, posicionado detrás.

## Dimensiones

| Elemento | Valor |
|---|---|
| Border width | 1px (todos los lados) |
| Header height (título solo) | 48px |
| Header height (título + descripción) | 64px |
| Footer height | 48px |
| Content padding (todos los lados) | 16px (`t.spacingLg`) |
| Header padding horizontal | 16px (`t.spacingLg`) |
| Footer padding horizontal | 16px (`t.spacingLg`) |
| Title font size | 14px (`t.fontSizeLg`) |
| Description font size | 11px (`t.fontSizeSm`) |
| Gap título → descripción | 4px (`t.spacingXs`) |

## Variantes / Configuraciones

| Variante | Descripción |
|---|---|
| Solo content | Sin header ni footer — `_content` ocupa todo el frame |
| Con header | `_content` empieza bajo el header; `_header` tiene borde-bottom 1px |
| Con footer | `_content` termina sobre el footer; `_footer` tiene borde-top 1px |
| Completo | Header + content + footer |

## Estados

| Estado | Comportamiento visual |
|---|---|
| Default | Fondo `t.card`, borde `t.border` 1px |
| Sin interacción | Panel es estático — no tiene estados hover ni focus propios |
| Contenido deshabilitado | Los hijos gestionan su propio estado disabled |

## Mapa de tokens

| Elemento | Token |
|---|---|
| Fondo del panel | `t.card` |
| Borde perimetral | `t.border` |
| Separador header-bottom | `t.border` |
| Separador footer-top | `t.border` |
| Texto del título | `t.foreground` |
| Fuente del título | `t.fontBold`, `t.fontSizeLg` (14px) |
| Texto de descripción | `t.mutedForeground` |
| Fuente de descripción | `t.font`, `t.fontSizeSm` (11px) |
| Padding content / header / footer | `t.spacingLg` (16px) |

## Config — `Create(parent, config)`

| Parámetro | Tipo | Default | Descripción |
|---|---|---|---|
| `width` | number | 320 | Ancho total del panel en px |
| `height` | number | nil | Alto total; si nil, el panel crece con el contenido |
| `title` | string | nil | Texto del título en el header; omitir oculta el header |
| `description` | string | nil | Texto de descripción bajo el título |
| `footer` | Frame | nil | Frame a insertar en la zona footer; omitir oculta el footer |
| `padding` | number | 16 | Override del padding de content (todos los lados) |

## API pública

| Método | Retorno | Descripción |
|---|---|---|
| `GetFrame()` | Frame | Retorna `panel.frame` — el contenedor raíz |
| `GetContent()` | Frame | Retorna `panel._content` — aquí se agregan frames hijos |
| `GetHeader()` | Frame \| nil | Retorna `panel._header` o nil si no existe |
| `GetFooter()` | Frame \| nil | Retorna `panel._footer` o nil si no existe |
| `SetTitle(text)` | void | Actualiza el texto de `panel._title`; crea el header si no existía |
| `SetDescription(text)` | void | Actualiza `panel._desc`; expande el header a 64px si es necesario |

## Notas de implementación

**Borde 1px perimetral:** la técnica recomendada en WoW Lua es crear `_border` como un Frame pintado con `t.border` y `_bg` insetado 1px en todos los lados:
```lua
panel._border:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", 0, 0)
panel._border:SetPoint("BOTTOMRIGHT", panel.frame, "BOTTOMRIGHT", 0, 0)
panel._bg:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", 1, -1)
panel._bg:SetPoint("BOTTOMRIGHT", panel.frame, "BOTTOMRIGHT", -1, 1)
```

**Separadores internos:** el borde-bottom del header y borde-top del footer son Textures de 1px de alto/ancho estiradas horizontalmente, pintadas con `t.border`.

**Scroll:** el Panel no scrollea por sí mismo. Para contenido largo, el dev debe agregar un `Craft.Scroll` dentro de `GetContent()`.

**Height automático:** si `config.height` es nil, el frame no tiene alto fijo y el dev debe gestionar el tamaño con `SetHeight` después de poblar `_content`, o usar el sistema de layout de Craft si está disponible.

**Footer externo:** `config.footer` es un Frame ya construido que se reparenta a `panel._footer`. El dev es responsable de dimensionarlo; el footer lo ancla con padding H de 16px y centra verticalmente.

**Radius = 0:** ninguna textura usa `SetTexCoord` para esquinas redondeadas. Todas las texturas son rectangulares sin modificación.
