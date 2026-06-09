# Component: Sidebar

> Referencia shadcn: `sidebar` — WoW frame base: `Frame` con ScrollFrame interno

## CSS real de Lyra (referencia)

```css
.cn-sidebar-header { @apply gap-2 p-2; }
.cn-sidebar-footer { @apply gap-2 p-2; }
.cn-sidebar-inner { @apply bg-sidebar; }
.cn-sidebar-group-label {
  @apply text-sidebar-foreground/70 h-8 rounded-none px-2 text-xs;
}
.cn-sidebar-menu-button {
  @apply hover:bg-sidebar-accent hover:text-sidebar-accent-foreground
         active:bg-sidebar-accent active:text-sidebar-accent-foreground
         data-active:bg-sidebar-accent data-active:text-sidebar-accent-foreground
         gap-2 rounded-none p-2 text-left text-xs;
}
.cn-sidebar-menu-button-size-default { @apply h-8 text-xs; }
.cn-sidebar-menu-button-size-sm      { @apply h-7 text-xs; }
.cn-sidebar-menu-button-size-lg      { @apply h-12 text-xs; }
.cn-sidebar-menu-sub-button {
  @apply text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground
         data-active:bg-sidebar-accent data-active:text-sidebar-accent-foreground
         h-7 gap-2 rounded-none px-2 text-xs;
}
.cn-sidebar-group { @apply p-2; }
.cn-sidebar-menu { @apply gap-0; }
.cn-sidebar-separator { @apply bg-sidebar-border mx-2; }
.cn-sidebar-rail { @apply hover:after:bg-sidebar-border; }
```

## Propósito

Navegación vertical en dos niveles (secciones e items clickeables) con scroll interno para listas largas; usa exclusivamente los tokens `sidebar*` del tema.

## Jerarquía de frames WoW

```
sidebar.frame              (Frame)                      raíz, ancho fijo
├── sidebar._bg            (Texture)                    fondo completo
├── sidebar._border        (Texture, 1px ancho)         borde derecho
├── sidebar._header        (Frame)                      SidebarHeader — oculto por defecto
├── sidebar._scroll        (ScrollFrame)                SidebarContent — área scrolleable
│   └── sidebar._child     (Frame)                      contenido del scroll
        ├── sidebar._section[1]   (Frame, 32px alto)    group label 1
        │   └── sidebar._sectionLabel[1] (FontString)   etiqueta de sección
        ├── sidebar._item[1]      (Button, 32px alto)   item 1
        │   ├── sidebar._item[1]._bg   (Texture)        fondo hover/active
        │   ├── sidebar._item[1]._icon (Texture, 16px)  ícono opcional
        │   └── sidebar._item[1]._text (FontString)     etiqueta del item
        ├── sidebar._section[2]   (Frame, 32px alto)    header de sección 2
        │   └── ...
        ├── sidebar._item[2]      (Button, 32px alto)   item 2
        │   └── ...
        └── ...
├── sidebar._footer        (Frame)                      SidebarFooter — oculto por defecto
├── ~~sidebar._rail~~      *(eliminado — ver nota de corrección)*
└── sidebar._sbarFrame     (Frame, 4px ancho)           scrollbar custom, borde derecho del scroll
    ├── sidebar._sbarTrack (Texture)                    fondo, t.sidebarForeground a=0.08
    └── sidebar._sbarThumb (Button)                     thumb arrastrable
```

> **Corrección post-testing en WoW:** El rail fue eliminado tras testing. La funcionalidad de colapso no se implementa en la versión actual. El espacio del rail (6px en el borde derecho) fue reemplazado por un scrollbar custom de 4px.

**`_header` y `_footer`:** Creados siempre, ocultos por defecto (height=0). El dev los activa
llamando `GetHeader()` o `GetFooter()`, setea su altura con `SetHeight(N)`, agrega contenido y
llama `RefreshLayout()`. El `_scroll` se re-ancla automáticamente entre header y footer.

La sección (section header) es un Frame con un FontString, no es clickeable. Los items son Buttons con altura fija según la variante de tamaño. El `_child` Frame del ScrollFrame debe tener su altura ajustada al total acumulado de secciones e items.

## Dimensiones

| Elemento | Valor | Origen CSS |
|---|---|---|
| Width (default) | 220px | — |
| Width (compact) | 180px | — |
| Width (wide) | 260px | — |
| Item height (default) | 32px | `h-8` |
| Item height (sm) | 28px | `h-7` |
| Item height (lg) | 48px | `h-12` |
| Item padding (todos los lados) | 8px (`t.spacingSm`) | `p-2` |
| Gap icon → text | 8px (`t.spacingSm`) | `gap-2` |
| Icon size | 16px (`t.iconSizeSm`) | — |
| Section header height | 32px | `h-8` |
| Section group padding | 8px (`t.spacingSm`) | `p-2` (cn-sidebar-group) |
| Section label padding horizontal | 8px (`t.spacingSm`) | `px-2` |
| Sub-button height | 28px | `h-7` |
| Sub-button padding horizontal | 8px (`t.spacingSm`) | `px-2` |
| Header padding | 8px todos los lados | `gap-2 p-2` (.cn-sidebar-header) |
| Footer padding | 8px todos los lados | `gap-2 p-2` (.cn-sidebar-footer) |
| Border derecho width | 1px | — |
| ~~SidebarRail width~~ | ~~6px~~ | *(eliminado)* |
| Scrollbar custom width | 4px | — |
| Font size (items y labels) | 12px (`t.fontSize`) | `text-xs` |

El `_child` height total = suma de alturas de todos los elementos (secciones e items, con el group padding de cada sección).

## Variantes / Configuraciones

| Size | Width |
|---|---|
| `default` | 220px |
| `compact` | 180px |
| `wide` | 260px |

### Tamaños de item

| Size | Height | Origen CSS |
|---|---|---|
| `sm` | 28px | `cn-sidebar-menu-button-size-sm` |
| `default` | 32px | `cn-sidebar-menu-button-size-default` |
| `lg` | 48px | `cn-sidebar-menu-button-size-lg` |

### Diferencias conocidas vs shadcn (fuera de MVP)

Craft.Sidebar es una implementación **simplificada** deliberada. shadcn ofrece una
API mucho más amplia que Craft **no** implementa (decisión de alcance MVP, no bug —
ver `docs/design-reference.md` §9.1):
- **Variantes de layout**: `floating`, `inset` (Craft solo tiene la barra fija).
- **Collapse modes**: `offcanvas`, `icon` (colapso a solo-íconos), `none`.
- **Sub-componentes**: `SidebarTrigger`, `SidebarRail`, sub-menús
  (`SidebarMenuSub*`), slots de acción/badge (`SidebarMenuAction`, `SidebarMenuBadge`),
  `SidebarMenuSkeleton`.

Si se decide ampliar, requiere aprobación del maintainer (cambio de API / arquitectura).

## Estados

| Elemento | Estado | Visual | Origen CSS |
|---|---|---|---|
| Item | Default | `_bg` transparente, texto `t.sidebarForeground` | — |
| Item | Hover | `_bg` color `t.sidebarAccent`, texto `t.sidebarAccentForeground` | `hover:bg-sidebar-accent` |
| Item | Active | `_bg` color `t.sidebarAccent`, texto `t.sidebarAccentForeground` | `data-active:bg-sidebar-accent` |
| Item | Disabled | Texto `t.mutedForeground` con a=0.5, `EnableMouse(false)` | — |
| Sub-button | Default | Texto `t.sidebarForeground` | — |
| Sub-button | Hover | `_bg` color `t.sidebarAccent`, texto `t.sidebarAccentForeground` | `hover:bg-sidebar-accent` |
| Sub-button | Active | `_bg` color `t.sidebarAccent`, texto `t.sidebarAccentForeground` | `data-active:bg-sidebar-accent` |
| Section header | Default | No clickeable, texto `t.sidebarForeground` a=0.7 | `text-sidebar-foreground/70` |
| Sidebar | Default | Fondo `t.sidebar`, borde-right `t.sidebarBorder` | `bg-sidebar` |

> **Corrección crítica:** el item activo usa `t.sidebarAccent` ({r=0.153,g=0.153,b=0.165}), NO `t.sidebarPrimary`. En Lyra, `data-active:bg-sidebar-accent` aplica el mismo fondo que el hover. `t.sidebarPrimary` (emerald-500) NO se usa como fondo de item activo en el sidebar menu button.

## Mapa de tokens

| Elemento | Token | Valor dark mode |
|---|---|---|
| Fondo del sidebar | `t.sidebar` | {r=0.094, g=0.094, b=0.106} |
| Borde derecho | `t.sidebarBorder` | {r=1, g=1, b=1, a=0.10} |
| Texto de item (default) | `t.sidebarForeground` | {r=0.980, g=0.980, b=0.980} |
| Fondo de item en hover | `t.sidebarAccent` | {r=0.153, g=0.153, b=0.165} |
| Fondo de item activo | `t.sidebarAccent` | {r=0.153, g=0.153, b=0.165} |
| Texto de item hover/activo | `t.sidebarAccentForeground` | — |
| Texto de item disabled | `t.mutedForeground` (a=0.5) | {r=0.631, g=0.631, b=0.667} |
| Texto de section label | `t.sidebarForeground` (a=0.7) | {r=0.980, g=0.980, b=0.980, a=0.70} |
| Fuente de items y labels | `t.font`, `t.fontSize` (12px) | — |
| Item padding | `t.spacingSm` (8px) | — |
| Gap icon → text | `t.spacingSm` (8px) | — |
| Icon size | `t.iconSizeSm` (16px) | — |

> Nota: el Sidebar NUNCA usa `t.background`, `t.card`, `t.accent` ni otros tokens generales. Todos los colores provienen de los tokens `sidebar*`. `t.sidebarPrimary` ({r=0.063,g=0.725,b=0.506}, emerald-500) y `t.sidebarPrimaryForeground` ({r=0.008,g=0.173,b=0.133}) están disponibles en el tema pero NO se usan en los estados del menu button.

## Config — `Create(parent, config)`

| Parámetro | Tipo | Default | Descripción |
|---|---|---|---|
| `size` | string | `"default"` | Uno de: `"default"` (220px), `"compact"` (180px), `"wide"` (260px) |
| `itemSize` | string | `"default"` | Uno de: `"sm"` (28px), `"default"` (32px), `"lg"` (48px) |
| `items` | array | `{}` | Array de tablas de configuración de items (ver estructura abajo) |
| `items[i].id` | string | — | Identificador único del item |
| `items[i].label` | string | — | Texto visible del item |
| `items[i].icon` | string | nil | Nombre del ícono para `Craft.Icons.Get(name)`; nil = sin ícono |
| `items[i].section` | string | nil | Label de la sección a la que pertenece; nil = sin sección |
| `items[i].onClick` | function | nil | Callback invocado al hacer click en el item |
| `activeItem` | string | nil | Id del item activo al crear el componente |

> `_header` y `_footer` no tienen parámetros de config — se obtienen vía `GetHeader()`/`GetFooter()` y el dev los configura directamente.

## API pública

| Método | Retorno | Descripción |
|---|---|---|
| `GetFrame()` | Frame | Retorna `sidebar.frame` |
| `SetActiveItem(id)` | void | Marca el item como activo (bg `t.sidebarAccent`, texto `t.sidebarAccentForeground`); desactiva el anterior |
| `GetActiveItem()` | string \| nil | Retorna el id del item actualmente activo |
| `AddItem(config)` | void | Agrega un item al final (o al final de su sección si `config.section` está definida); recalcula la altura del `_child` |
| `AddSection(label)` | void | Agrega un section header al final del listado; las secciones deben agregarse antes que sus items |
| `GetHeader()` | Frame | Retorna `_header` Frame (SidebarHeader). El dev llama `SetHeight(N)` y agrega contenido, luego `RefreshLayout()` |
| `GetFooter()` | Frame | Retorna `_footer` Frame (SidebarFooter). Mismo patrón que GetHeader() |
| `RefreshLayout()` | void | Reancla `_scroll` entre `_header` y `_footer` según sus alturas actuales. Llamar después de modificar header/footer |

> **Corrección post-testing en WoW:** `GetRail()` y `SetCollapsible(bool)` fueron eliminados del API público junto con el rail. La funcionalidad de colapso no se implementa en la versión actual.

## Notas de implementación

**Tokens exclusivos:** el Sidebar usa `t.sidebar`, `t.sidebarForeground`, `t.sidebarAccent`, `t.sidebarAccentForeground`, `t.sidebarBorder`. Nunca mezclar con tokens generales.

**Borde derecho:**
```lua
sidebar._border:SetPoint("TOPRIGHT",    sidebar.frame, "TOPRIGHT",    0,  0)
sidebar._border:SetPoint("BOTTOMRIGHT", sidebar.frame, "BOTTOMRIGHT", 0,  0)
sidebar._border:SetWidth(1)
sidebar._border:SetColorTexture(t.sidebarBorder.r, t.sidebarBorder.g, t.sidebarBorder.b, t.sidebarBorder.a)
```

**ScrollFrame setup:**
```lua
sidebar._scroll:SetPoint("TOPLEFT",     sidebar.frame, "TOPLEFT",     0,  0)
sidebar._scroll:SetPoint("BOTTOMRIGHT", sidebar.frame, "BOTTOMRIGHT", -1, 0) -- -1 para el borde
sidebar._scroll:SetScrollChild(sidebar._child)
```
El `_child` Frame debe tener su ancho igual al ancho del scroll y su altura igual al total acumulado.

**Construcción de items:** los items se crean en orden (secciones primero, luego sus items). Cada elemento se posiciona con `SetPoint("TOPLEFT", prevElement, "BOTTOMLEFT", 0, 0)`. Al agregar o remover items, recalcular `_child:SetHeight(totalHeight)`.

**Item activo (corrección — usa sidebarAccent, no sidebarPrimary):**
```lua
-- Desactivar el anterior
prevItem._bg:SetColorTexture(0, 0, 0, 0)  -- transparente
prevItem._text:SetTextColor(t.sidebarForeground.r, t.sidebarForeground.g, t.sidebarForeground.b)

-- Activar el nuevo (igual que hover — usa sidebarAccent)
item._bg:SetColorTexture(t.sidebarAccent.r, t.sidebarAccent.g, t.sidebarAccent.b)
item._text:SetTextColor(t.sidebarAccentForeground.r, t.sidebarAccentForeground.g, t.sidebarAccentForeground.b)
```

**Item con ícono:**
```lua
local icon = Craft.Icons.Get(config.icon)  -- retorna Texture o nil
if icon then
    item._icon:SetTexture(icon)
    item._text:SetPoint("LEFT", item._icon, "RIGHT", spacingSm, 0)
else
    item._icon:Hide()
    item._text:SetPoint("LEFT", item, "LEFT", spacingSm, 0)
end
```
El ícono se posiciona a `spacingSm` (8px) del borde izquierdo del item (padding `p-2`).

**Section label foreground/70:** WoW Lua no tiene modificadores de opacidad en colores de texto directamente. Usar los valores RGBA del token con alpha 0.7:
```lua
sectionLabel:SetTextColor(t.sidebarForeground.r, t.sidebarForeground.g, t.sidebarForeground.b, 0.70)
```

**Section label uppercase:** WoW Lua no tiene `text-transform`. Aplicar `string.upper(label)` al asignar el texto de `_sectionLabel`.

**Group padding:** cada grupo (sección + sus items) se inserta con 8px de padding (`p-2`). El Frame de group envuelve la sección y sus items con ese margen respecto a los bordes del sidebar.

**Radius = 0:** los fondos de hover y activo son Textures rectangulares sin redondeo (`rounded-none` en Lyra), pintadas con `SetColorTexture`.

~~**SidebarRail:**~~ *(eliminado — ver nota abajo)*

> **Corrección post-testing en WoW:** El rail fue eliminado tras testing. La funcionalidad de colapso no se implementa en la versión actual. El espacio del rail (6px en el borde derecho) fue reemplazado por un scrollbar custom de 4px.

**Scrollbar custom (reemplaza al rail):**

El sidebar incluye un scrollbar custom de 4px en el borde derecho del scroll. Solo es visible cuando `childH > viewH`.

- `_sbarFrame`: Frame de 4px de ancho, anclado al borde derecho del scroll.
- `_sbarTrack`: Texture background con color `t.sidebarForeground` a=0.08 — indica visualmente la zona scrollable.
- `_sbarThumb`: Button con drag support. Colores:
  - Normal: `t.sidebarForeground` a=0.35
  - Hover: `t.sidebarForeground` a=0.60
  - Drag activo: `t.sidebarPrimary` a=0.80
- `_updateSbar()`: método interno que reposiciona el thumb según el scroll actual del `_scroll` ScrollFrame.
- Drag usa `select(2, GetCursorPosition()) / frame:GetEffectiveScale()` (ADR-0011).

```lua
-- Visibilidad del scrollbar
if childH > viewH then
    self._sbarFrame:Show()
    self:_updateSbar()
else
    self._sbarFrame:Hide()
end
```

> **Corrección post-testing en WoW:** scrollbar custom añadido para dar feedback visual del contenido scrollable.
