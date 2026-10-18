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
- **Sub-componentes**: `SidebarTrigger`, `SidebarRail`, slot de badge
  (`SidebarMenuBadge`), `SidebarMenuSkeleton`. (`SidebarMenuAction` sí: `items[i].action`, FR-109.)

> **Implementado (FR-008):** el **árbol colapsable** (sub-menús anidados) sí existe vía
> `items[i].children` + `collapsible`. Ver "Árbol colapsable" abajo.

Si se decide ampliar lo demás, requiere aprobación del maintainer (cambio de API).

## Árbol colapsable (FR-008)

Los items admiten anidamiento y colapso. Un item con `children` (o `collapsible=true`)
es una **rama** que expande/colapsa; las hojas seleccionan.

- **Indent** por nivel (`INDENT`=20px) + **línea guía** vertical de 1px por nivel
  anidado (`border-l` en `t.sidebarBorder`, como `SidebarMenuSub` de shadcn).
- **Sub-items** (depth>0) usan **h-7** (28px), más bajos que el top (`h-8`).
- **Chevron al final** de la fila (`chevron-down` abierto / `chevron-right` cerrado;
  swap de íconos, no rotación — WoW). Hit-region dividida: click en el chevron =
  toggle (un sub-Button de mayor frame-level lo consume); click en el resto = select.
- `SetActiveItem`/`Select` **auto-expande los ancestros** colapsados del item.

### Preservación de expansión en refrescos (FR-010)

Cuando un consumer edita el árbol en vivo (CRUD) y llama `SetItems` para refrescar, el
estado abierto/cerrado de cada rama **se conserva por `id`** sin trabajo extra:

```lua
sidebar:SetItems(tree)                              -- preserva por defecto (ids repetidos)
sidebar:SetItems(tree, { preserveExpansion = false })  -- resetea a defaultOpen

local snap = sidebar:GetExpandedState()  -- { ["pack1"]=true, ["panels"]=false, ... }
sidebar:SetExpandedState(snap)           -- reaplica un snapshot explícito
sidebar:IsExpanded("pack1")              -- → true/false
```

Las ramas con `id` nuevo (no presentes antes del refresco) usan su `defaultOpen`.

```lua
items = {
  { id="pack1", label="Manaforge", icon="folder", collapsible=true, defaultOpen=true,
    children = {
      { id="aura1", label="Shadow Crash", icon="star" },
      { id="panels", label="Paneles", icon="layers", collapsible=true, children={ ... } },
    } },
}
```

## Estados

| Elemento | Estado | Visual | Origen CSS |
|---|---|---|---|
| Item | Default | `_bg` transparente, texto `t.sidebarForeground` | — |
| Item | Hover | `_bg` color `t.sidebarAccent`, texto `t.sidebarAccentForeground` | `hover:bg-sidebar-accent` |
| Item | Active | `_bg` `t.sidebarAccent`, texto `t.sidebarAccentForeground`, **fuente `t.fontMedium`** | `data-active:bg-sidebar-accent data-active:font-medium` |
| Item | Disabled | Texto e ícono `t.mutedForeground` con a=0.5, `EnableMouse(false)` (sin hover/click) | `disabled:pointer-events-none disabled:opacity-50` |
| Item | Disabled + `tooltip` | Igual que Disabled, pero con ratón activo **solo** para el hover del tooltip (FR-089): sin recolorear y sin clic | — |
| Sub-button | Default | Texto `t.sidebarForeground` | — |
| Sub-button | Hover | `_bg` color `t.sidebarAccent`, texto `t.sidebarAccentForeground` | `hover:bg-sidebar-accent` |
| Sub-button | Active | `_bg` color `t.sidebarAccent`, texto `t.sidebarAccentForeground` | `data-active:bg-sidebar-accent` |
| Section header | Default | No clickeable, texto `t.sidebarForeground` a=0.7 | `text-sidebar-foreground/70` |
| Sidebar | Default | Fondo `t.sidebar`, borde-right `t.sidebarBorder` | `bg-sidebar` |

> **Corrección crítica:** el item activo usa `t.sidebarAccent` ({r=0.153,g=0.153,b=0.165}), NO `t.sidebarPrimary`. En Lyra, `data-active:bg-sidebar-accent` aplica el mismo fondo que el hover. `t.sidebarPrimary` (emerald-500) NO se usa como fondo de item activo en el sidebar menu button.

## Mapa de tokens

| Elemento | Token | Valor dark mode |
|---|---|---|
| Fondo del sidebar | `t.sidebar` | {r=0.091, g=0.091, b=0.091} |
| Borde derecho | `t.sidebarBorder` | {r=1, g=1, b=1, a=0.10} |
| Texto de item (default) | `t.sidebarForeground` | {r=0.980, g=0.980, b=0.980} |
| Fondo de item en hover | `t.sidebarAccent` | {r=0.149, g=0.149, b=0.149} |
| Fondo de item activo | `t.sidebarAccent` (+ fuente `t.fontMedium`) | {r=0.149, g=0.149, b=0.149} |
| Texto de item hover/activo | `t.sidebarAccentForeground` | — |
| Texto de item disabled | `t.mutedForeground` (a=0.5) | {r=0.630, g=0.630, b=0.630} |
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
| `items[i].avatar` | table | nil | (FR-095) Un `Craft.Avatar` en el hueco del icono, como el `<Avatar>` que shadcn compone dentro de `SidebarMenuButton` (NavUser). La tabla es el config del Avatar (`unit` \| `creatureDisplayID` \| `atlas` \| `image`, `fallback`, `size`, `crop`, `texCoord`, `desaturated`) y se copia. `size` por defecto 16 (el hueco `size-4`); el label se corre a `size + 8`. Gana a `icon`. El hover/active **no lo tiñe**; `disabled` lo baja al 50 % (`opacity-50` del botón entero). `SetItems`/`Destroy` lo destruyen |
| `items[i].texture` | table | nil | (FR-114) Textura **cuadrada** sin máscara en el hueco del icono (16px): `{ image \| atlas, crop?, texCoord? }`. Es el `<img>` dentro de `SidebarMenuButton`, sin el redondeo del Avatar — pensado para iconos de hechizo (`crop = 0.08` recorta su borde horneado). `image` va por `SetTexture` **sin** `filterMode` (crash #132); un `atlas` desconocido cae a `icon`. Por debajo de `avatar`, por encima de `icon`. Hover/active no la tiñen; `disabled` la baja al 50 % |
| `items[i].section` | string | nil | (grupos planos, depth 0) Label de la sección; nil = sin sección |
| `items[i].onClick` | function | nil | Callback `fn(id, itemConfig)` al hacer click en el item |
| `items[i].onDoubleClick` | function | nil | (FR-098) Callback `fn(id, itemConfig)` en el segundo clic de un doble clic. No en ramas ni filas `disabled` |
| `items[i].onContextMenu` | function | nil | (FR-107) Callback `fn(id, anchor, itemConfig)` al clic derecho sobre la fila (`anchor` = el frame de la fila). Como el `onContextMenu` global |
| `items[i].children` | array | nil | (árbol) Sub-items anidados — hace al item una rama colapsable |
| `items[i].collapsible` | boolean | auto | true si tiene `children`; fuerza rama colapsable |
| `items[i].selectable` | boolean | true | (FR-108) Solo ramas. `false` = cabecera de sección: el clic en la fila **pliega/despliega** (en shadcn el `SidebarMenuButton` es el `CollapsibleTrigger`) en vez de volverla activa; dispara `onToggle` e `itemConfig.onClick`, **no** `onSelect`, y la selección actual no cambia |
| `items[i].defaultOpen` | boolean | true | Estado inicial expandido de la rama |
| `items[i].disabled` | boolean | false | (FR-048) Item deshabilitado: sin hover/click (`EnableMouse(false)`, chevron incluido), texto e ícono `t.mutedForeground` con a=0.5 |
| `items[i].tooltip` | string | nil | (FR-089) Etiqueta al hover de la fila, mismo nombre y forma que en `Craft.Button` (FR-020) y `Craft.Menu` (FR-084). Vale también —y sobre todo— en filas `disabled`. Un valor que no sea string se ignora |
| `items[i].action` | table | nil | (FR-109) Botón de acción al borde derecho de la fila = `SidebarMenuAction` de shadcn: `{ icon, onClick, tooltip, hover, active }`. Cuadrado `w-5` (20px) a `right-1` (4px), icono `size-4`, `top-1.5` en `h-8` / `top-1` en `h-7` (centrado) / `top-2.5` en `lg`; en una rama va a la izquierda del chevrón. Es **hermano** del botón de la fila: `onClick(id, itemConfig)` con clic izquierdo **no selecciona** ni dispara `onSelect`/`onContextMenu`; el clic derecho sobre él es el de la fila (como el chevrón). Hover propio `bg-sidebar-accent`; el hover de la fila (`peer-hover`) pasa el icono a `sidebarAccentForeground`. `hover = true` = `showOnHover`: `opacity-0` hasta que se pasa el ratón por la fila o la acción, **sigue siendo clicable** invisible (como el CSS). `active = false` pinta el icono en `mutedForeground` (petición de SMRT: «ojo apagado»; en shadcn el consumidor solo cambiaría el icono). No se desactiva con `disabled` de la fila (es otro elemento). `SetItems` lo repinta; `icon` debe ser string o no hay acción |
| `activeItem` | string | nil | Id del item activo al crear el componente (= `selection = { activeItem }`) |
| `selection` | array | nil | (FR-116) Ids seleccionados al crear (gana a `activeItem`) |
| `onClick` | function | nil | (FR-116) `fn(id, mods)` con `mods = { ctrl, shift, alt }` leídos en el clic. **Si existe, el Sidebar no cambia la selección por su cuenta** (ni dispara `onSelect`): el consumidor decide y llama `SetSelection`. Sin él, el clic selecciona como siempre. `items[i].onClick` se sigue llamando. Las cabeceras `selectable = false` pliegan igual |
| `onDrop` | function | nil | (FR-117) `fn(ids, targetId, zone)` al soltar sobre un destino válido. **Activa el arrastre**: sin él no se arma nada. Mientras dura, las filas que viajan se atenúan en su sitio y un fantasma sigue al cursor; una rama plegada se abre tras 0,6 s de hover si acepta `"inside"` |
| `draggable` | function | nil | (FR-117) `fn(id) -> bool`: qué filas se pueden arrastrar (por defecto todas las que tienen `id` y no son `disabled`) |
| `onDragStart` | function | nil | (FR-117) `fn(id) -> ids, label?`: las filas que viajan (p. ej. la selección, o el grupo con su árbol) y un texto opcional para el fantasma que sigue al cursor («3 auras»). `nil` cancela. Sin él viaja `{ id }` |
| `dropZones` | function | nil | (FR-117) `fn(id) -> "split" \| "thirds" \| "inside" \| nil`: mitades antes/después, tercios con «dentro» en el centro, toda la fila = dentro, o no es destino. Por defecto `"thirds"` en ramas y `"split"` en hojas |
| `canDrop` | function | nil | (FR-117) `fn(ids, targetId, zone) -> bool`. Falso = sin indicador y soltar ahí cancela. Por defecto todo vale |
| `onDragCancel` | function | nil | (FR-117) `fn()` al soltar fuera / sobre un destino no válido, con ESC o con `CancelDrag()` |
| `onSelect` | function | nil | Callback `fn(id)` al seleccionar cualquier item |
| `onDoubleClick` | function | nil | (FR-098) Callback `fn(id)` al hacer doble clic en un item hoja. Es el `OnDoubleClick` del cliente: el primer clic ya disparó `onSelect` (la fila está seleccionada) y el segundo llega aquí **en vez de** como `OnClick`. Ramas (`collapsible`) y `disabled` no lo disparan. El script solo se registra si hay algún `onDoubleClick` (global o del item): sin él, el segundo clic sigue siendo un `OnClick` como antes |

| `onContextMenu` | function | nil | (FR-107) Callback `fn(id, anchor, itemConfig)` al clic derecho sobre una fila (hojas y ramas; no `disabled`). **No selecciona**: si el consumidor quiere el patrón WA (seleccionar y luego menú) llama `SetActiveItem(id)` dentro. `anchor` es el frame de la fila → `Craft.Menu:Open(anchor, …)` u `OpenAtCursor()`. El botón derecho solo se registra (`RegisterForClicks("LeftButtonUp", "RightButtonUp")`) si hay algún `onContextMenu` (global o del item); el chevrón de una rama reenvía el clic derecho a la fila |
| `onToggle` | function | nil | (FR-108) Callback `fn(id, open)` tras plegar/desplegar una rama con `id`: chevrón, clic en cabecera `selectable = false`, `ToggleNode`/`Expand`/`Collapse`, y `SetActiveItem` cuando abre ancestros plegados. **No** desde `SetItems` ni `SetExpandedState` (restaurar estado no es un gesto). Pensado para persistir el plegado sin adivinar cuándo leer `GetExpandedState()` |

> `_header` y `_footer` no tienen parámetros de config — se obtienen vía `GetHeader()`/`GetFooter()` y el dev los configura directamente.

> **Prop reactiva (ADR-0013):** `items` acepta señal/computed además del array literal. Al
> cambiar la señal, el árbol se re-renderiza vía `SetItems` (one-way; preserva la expansión
> por id, como el `SetItems` manual). `Destroy()` corta el bind (`disposeAll`).

## API pública

| Método | Retorno | Descripción |
|---|---|---|
| `GetFrame()` | Frame | Retorna `sidebar.frame` |
| `SetActiveItem(id)` | void | = `SetSelection({ id })` y además abre sus ancestros plegados. Activo = bg `t.sidebarAccent`, texto `t.sidebarAccentForeground` |
| `GetActiveItem()` | string \| nil | El último id de la selección (el activo) |
| `SetSelection(ids)` / `GetSelection()` / `IsSelected(id)` | void / array / boolean | (FR-116) Varias filas con el mismo estado `data-active`. `SetSelection` no abre ancestros; `nil`/`{}` vacía. `GetSelection` devuelve una copia en el orden dado |
| `GetScroll()` / `SetScroll(y)` | number / void | (FR-118) Desplazamiento vertical en px; `SetScroll` lo acota al contenido y cancela un `ScrollToItem` animado |
| `ScrollToItem(id, animate?)` | boolean | (FR-118) Desplaza lo mínimo para que la fila quede **entera** a la vista; abre sus ancestros plegados (avisa por `onToggle`). `animate` = deslizamiento `motionBase`. `false` si el id no existe; si la vista aún no tiene alto, la petición se aplica cuando lo tenga |
| `IsDragging()` / `CancelDrag()` | boolean / boolean | (FR-117) `CancelDrag` devuelve las filas a su sitio y dispara `onDragCancel`; `false` si no había arrastre |
| `Select(id)` | void | Alias de `SetActiveItem` |
| `AddItem(config)` | void | Agrega un item al final; recalcula la altura del `_child` |
| `AddSection(label)` | void | Agrega un section header (grupo plano) al final del listado |
| `SetItems(tree, opts?)` | void | Reemplaza todos los items/secciones por un nuevo árbol (posiblemente anidado) **reutilizando las filas** (FR-080). **Por defecto preserva** el estado de expansión de las ramas cuyo `id` exista antes y después (FR-010); las nuevas usan su `defaultOpen`. `opts.preserveExpansion = false` resetea todo a `defaultOpen`. Conserva la selección por id y descarta los ids que existían y desaparecen (FR-116). Las filas que cambian de sitio **se deslizan** a su hueco nuevo (`motionFast`, FR-117); `opts.animate = false` salta. Cancela un arrastre en curso |
| `Expand(id)` / `Collapse(id)` / `ToggleNode(id)` | void | Expande/colapsa/alterna una rama colapsable por id |
| `GetExpandedState()` | table | Snapshot `{ [id] = bool }` del estado abierto/cerrado de cada rama colapsable (FR-010) |
| `SetExpandedState(map)` | void | Aplica un mapa `{ [id] = bool }` a las ramas colapsables; ignora ids inexistentes o no colapsables (FR-010) |
| `IsExpanded(id)` | boolean | `true` si la rama `id` está expandida; `false` para hojas, ids desconocidos o no colapsables (FR-010) |
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

**Section label tal cual (sin uppercase):** shadcn Lyra muestra el label del grupo sin transformar. Asignar el texto directamente (no aplicar `string.upper`).

**Group padding (`p-2`):** `_rebuildLayout` insetea **todos** los elementos 8px a izquierda y derecha (`SetPoint` TOPLEFT +8 / TOPRIGHT −8), de modo que el contenido cae a 16px (8 group + 8 padding interno) y los resaltados hover/activo quedan inset. Verticalmente: 8px arriba del primer bloque, 16px entre secciones consecutivas (cierre + apertura de grupo), 8px abajo del último. Un **separador** (`AddSeparator`) cierra el grupo anterior: 8px arriba y 8px abajo del separador — el bloque siguiente abre con un solo padding de 8px, no 16 (FR-050, como Lyra: grupo `p-2` + separador + grupo `p-2`). No se usa un Frame contenedor de grupo — el inset se aplica por elemento.

**Item activo en negrita:** `data-active:font-medium` → el label del item activo (solo nivel raíz) usa `t.fontMedium`; los inactivos usan `t.font` (regular). Los sub-items (`data-active` en `sidebar-menu-sub-button`) NO llevan `font-medium` en Lyra — mantienen `t.font` incluso activos (ver [FR-047](../requests/FR-047-sidebar-subitem-no-bold.md)).

**Tooltip por entrada (FR-089):** `Craft.Tooltip.Show(row, { text = tooltip, side = "right" })` tras
300 ms de hover, desde el `OnEnter`/`OnLeave` propios de la fila. Ancla a la DERECHA para que el tip
caiga fuera de la barra en vez de tapar las filas vecinas (la misma elección que `Craft.Menu`,
FR-067). **No usa `Craft.Tooltip.Attach`** desde FR-080: `Attach` engancha el frame para siempre
(FR-081) y una fila del pool cambia de item. Un token cancela el show diferido en cuanto acaba el
hover, y `SetItems`/`Destroy` lo cancelan también.

> **Separa los dos "pointer events" de una fila disabled.** Una fila gris sin explicación se lee
> como una fila **rota**; la diferencia entre «esto no funciona» y «esto todavía no existe» es una
> línea al hover, y solo el componente puede dársela — un consumidor que construye la barra con
> `SetItems` no tiene acceso soportado al frame de la fila, y aunque lo tuviera la fila disabled no
> tiene ratón. Con `tooltip`, la fila disabled pasa a `EnableMouse(true)` **solo** para recibir
> `OnEnter`/`OnLeave`: el clic no hace nada y no recolorea (los scripts de la fila salen en cuanto
> ven `disabled`), así que la garantía de FR-048 no se toca. Sin `tooltip` el comportamiento es idéntico al
> de antes: `EnableMouse(false)`. Misma política que `Craft.Button` (FR-020) y `Craft.Menu` (FR-084).

**Item disabled (FR-048):** `disabled:pointer-events-none disabled:opacity-50` → `itemFrame:EnableMouse(false)` (los scripts de la fila pooleada existen pero no actúan sobre una entrada `disabled`; en ramas también se apaga el Button del chevron) y foreground `t.mutedForeground` con a=0.5 en label, ícono y chevron. El estado disabled tiene precedencia visual sobre activo/hover en `_colorItem`.

**Pool de filas (FR-080):** `SetItems` ya no abandona frames. Las filas viven en
`_pool.item/section/separator` (un pool por tipo: no se mezclan tipos entre generaciones) y cada
generación las toma en orden; las sobrantes se ocultan, se desanclan y pierden su `entry`. Los
scripts de una fila se instalan **una vez** al crearla y despachan por `row.entry` (la entrada de
la generación actual), así que una fila reciclada nunca dispara los callbacks del item anterior.
Al reutilizar se reajustan chevrón, guías, acción (FR-109, también pooleada), clics derechos,
`OnDoubleClick` y ratón. Los `Craft.Avatar` de fila (FR-095) se destruyen y se crean por uso.

**Selección múltiple (FR-116):** shadcn tiene un único estado `data-active`; una selección
múltiple es varias filas en ese estado (mismo fondo, texto y `font-medium` en raíz). La lógica de
qué entra (Ctrl suma, Shift rango, solo hojas…) es del consumidor vía `onClick(id, mods)` +
`SetSelection`: el Sidebar solo pinta y avisa. `activeItem` es el último id de la lista.

**Arrastrar y soltar (FR-117)** — shadcn no tiene sidebar ordenable; esto es de Craft, con el
vocabulario de WeakAuras:
- Pulsar y recorrer 4px = arrastre (antes es un clic). El soltar que acaba un arrastre no es clic.
- Patrón dnd-kit (el del ecosistema shadcn): las filas que viajan —los `ids` y todo lo que cuelga
  de una rama que viaja— **se quedan en su sitio al 50 %** (`opacity-50`) y un **fantasma** de la
  fila pulsada (icono/textura + label, o el `label` de `onDragStart`; fondo `sidebarAccent`, alpha
  0.9) sigue al cursor. Nada se reordena hasta soltar. Las filas que viajan nunca son destino.
- **Apertura por hover (spring-loading):** 0,6 s sobre una rama plegada que acepte `"inside"`
  (`canDrop(ids, rama, "inside")`) la abre para poder soltar entre sus hijos. Queda abierta y se
  avisa por `onToggle`.
- **«Después» de una rama abierta = primer hijo:** esa línea se dibuja entre la rama y su primer
  hijo, así que el destino pasa a «antes del primer hijo» (como VS Code/Finder). Si el consumidor
  lo rechaza (un grupo no entra en un grupo) queda «después de la rama»; sin hijos válidos, «dentro».
- **Cancelar (ESC, soltar fuera o en destino no válido)**: el fantasma vuelve volando a su fila
  (`motionBase`) y las filas se iluminan al llegar. Tras un drop válido se iluminan al instante.
- Indicador: línea de 2px `sidebarPrimary` sobre/bajo la fila, desde la sangría de su contenido
  (antes/después), o lavado `sidebarPrimary` a 0.15 sobre la fila (dentro); fundido `motionFast`.
- Autodesplazamiento en una franja de 24px arriba/abajo, más rápido cuanto más al borde.
- ESC se captura **solo durante el arrastre** (`EnableKeyboard` + `SetPropagateKeyboardInput`:
  todo lo que no es ESC se propaga, la ventana no se cierra). En combate no se captura: allí
  `SetPropagateKeyboardInput` está protegida y un frame con teclado se comería todas las teclas.
- Deslizamiento: cada fila del pool lleva un `Weave.tween` de desplazamiento que se `snap`ea a
  «hueco viejo − hueco nuevo» y vuelve a 0 (`motionFast`, `motionEasing`). La posición vieja se
  mide en pantalla (hueco + desplazamiento en curso), con clave por id (secciones por texto,
  separadores por orden), así que un `SetItems` dentro de `onDrop` desliza desde donde se ve.

**API de scroll (FR-118):** `ScrollToItem` usa la geometría de la última maquetación (`_y`, `_h`
de cada fila); con `animate`, un `Weave.tween` (`motionBase`) mueve el `ScrollFrame` mientras nada
más lo toque — rueda, thumb, autodesplazamiento y `SetScroll` lo cancelan. Como FR-113 en
`Craft.Scroll`, cada maquetación acota el desplazamiento si el contenido encogió.

**Clic en una rama seleccionable** (patrón de los árboles editables: VS Code, capas de Figma;
shadcn no fija uno): clic en una rama **no seleccionada** la selecciona y, si está plegada, la
abre (nunca la pliega); clic en la rama **ya seleccionada** la pliega/despliega. Ctrl/Shift+clic
solo seleccionan. Vale también con `onClick` (lo decide el estado de selección antes del clic).
El chevrón siempre pliega/despliega; `selectable = false` sigue siendo «la fila entera pliega».

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
