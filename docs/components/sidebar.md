# Component: Sidebar

> Referencia shadcn: `sidebar` — WoW frame base: `Frame` con ScrollFrame interno

## Propósito

Navegación vertical en dos niveles (secciones e items clickeables) con scroll interno para listas largas; usa exclusivamente los tokens `sidebar*` del tema.

## Jerarquía de frames WoW

```
sidebar.frame              (Frame)                      raíz, ancho fijo
├── sidebar._bg            (Texture)                    fondo completo
├── sidebar._border        (Texture, 1px ancho)         borde derecho
└── sidebar._scroll        (ScrollFrame)                área scrolleable
    └── sidebar._child     (Frame)                      contenido del scroll
        ├── sidebar._section[1]   (Frame, 32px alto)    header de sección 1
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
```

La sección (section header) es un Frame con un FontString, no es clickeable. Los items son Buttons con altura fija de 32px. El `_child` Frame del ScrollFrame debe tener su altura ajustada al total acumulado de secciones e items.

## Dimensiones

| Elemento | Valor |
|---|---|
| Width (default) | 220px |
| Width (compact) | 180px |
| Width (wide) | 260px |
| Item height | 32px |
| Item padding horizontal | 12px (`t.spacingMd`) |
| Icon size | 16px (`t.iconSizeSm`) |
| Gap icon → text | 8px (`t.spacingSm`) |
| Section header height | 32px |
| Section padding top extra | 8px (`t.spacingSm`) sobre los 32px base |
| Border derecho width | 1px |
| Font size (items) | 12px (`t.fontSize`) |
| Font size (section labels) | 11px (`t.fontSizeSm`) |

El `_child` height total = suma de alturas de todos los elementos (secciones e items, con el padding-top extra de cada sección).

## Variantes / Configuraciones

| Size | Width |
|---|---|
| `default` | 220px |
| `compact` | 180px |
| `wide` | 260px |

## Estados

| Elemento | Estado | Visual |
|---|---|---|
| Item | Default | `_bg` transparente, texto `t.sidebarForeground` |
| Item | Hover | `_bg` color `t.sidebarAccent`, texto `t.sidebarForeground` |
| Item | Active | `_bg` color `t.sidebarPrimary`, texto `t.sidebarPrimaryForeground` |
| Item | Disabled | Texto `t.mutedForeground` con a=0.5, `EnableMouse(false)` |
| Section header | Default | No clickeable, texto `t.mutedForeground`, uppercase |
| Sidebar | Default | Fondo `t.sidebar`, borde-right `t.sidebarBorder` |

## Mapa de tokens

| Elemento | Token |
|---|---|
| Fondo del sidebar | `t.sidebar` |
| Borde derecho | `t.sidebarBorder` |
| Texto de item | `t.sidebarForeground` |
| Fondo de item en hover | `t.sidebarAccent` |
| Fondo de item activo | `t.sidebarPrimary` |
| Texto de item activo | `t.sidebarPrimaryForeground` |
| Texto de item disabled | `t.mutedForeground` (a=0.5) |
| Texto de section header | `t.mutedForeground` |
| Fuente de item | `t.font`, `t.fontSize` (12px) |
| Fuente de section label | `t.font`, `t.fontSizeSm` (11px) |
| Item padding horizontal | `t.spacingMd` (12px) |
| Gap icon → text | `t.spacingSm` (8px) |
| Icon size | `t.iconSizeSm` (16px) |

> Nota: el Sidebar NUNCA usa `t.background`, `t.card`, `t.accent` ni otros tokens generales. Todos los colores provienen de los tokens `sidebar*`.

## Config — `Create(parent, config)`

| Parámetro | Tipo | Default | Descripción |
|---|---|---|---|
| `size` | string | `"default"` | Uno de: `"default"` (220px), `"compact"` (180px), `"wide"` (260px) |
| `items` | array | `{}` | Array de tablas de configuración de items (ver estructura abajo) |
| `items[i].id` | string | — | Identificador único del item |
| `items[i].label` | string | — | Texto visible del item |
| `items[i].icon` | string | nil | Nombre del ícono para `Craft.Icons.Get(name)`; nil = sin ícono |
| `items[i].section` | string | nil | Label de la sección a la que pertenece; nil = sin sección |
| `items[i].onClick` | function | nil | Callback invocado al hacer click en el item |
| `activeItem` | string | nil | Id del item activo al crear el componente |

## API pública

| Método | Retorno | Descripción |
|---|---|---|
| `GetFrame()` | Frame | Retorna `sidebar.frame` |
| `SetActiveItem(id)` | void | Marca el item como activo (bg `t.sidebarPrimary`, texto `t.sidebarPrimaryForeground`); desactiva el anterior |
| `GetActiveItem()` | string \| nil | Retorna el id del item actualmente activo |
| `AddItem(config)` | void | Agrega un item al final (o al final de su sección si `config.section` está definida); recalcula la altura del `_child` |
| `AddSection(label)` | void | Agrega un section header al final del listado; las secciones deben agregarse antes que sus items |

## Notas de implementación

**Tokens exclusivos:** el Sidebar usa `t.sidebar` (no `t.background`), `t.sidebarForeground`, `t.sidebarPrimary`, `t.sidebarPrimaryForeground`, `t.sidebarAccent`, `t.sidebarBorder`. Nunca mezclar con tokens generales.

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

**Item con ícono:**
```lua
local icon = Craft.Icons.Get(config.icon)  -- retorna Texture o nil
if icon then
    item._icon:SetTexture(icon)
    item._text:SetPoint("LEFT", item._icon, "RIGHT", spacingSm, 0)
else
    item._icon:Hide()
    item._text:SetPoint("LEFT", item, "LEFT", spacingMd, 0)
end
```
El ícono se posiciona a `spacingMd` (12px) del borde izquierdo del item.

**Item activo:** al llamar `SetActiveItem(id)`:
```lua
-- Desactivar el anterior
prevItem._bg:SetColorTexture(0, 0, 0, 0)  -- transparente
prevItem._text:SetTextColor(t.sidebarForeground.r, t.sidebarForeground.g, t.sidebarForeground.b)

-- Activar el nuevo
item._bg:SetColorTexture(t.sidebarPrimary.r, t.sidebarPrimary.g, t.sidebarPrimary.b, t.sidebarPrimary.a)
item._text:SetTextColor(t.sidebarPrimaryForeground.r, t.sidebarPrimaryForeground.g, t.sidebarPrimaryForeground.b)
```

**Section label uppercase:** WoW Lua no tiene `text-transform`. Aplicar `string.upper(label)` al asignar el texto de `_sectionLabel`.

**Section padding top extra:** el Frame de sección mide 32px, pero el `_sectionLabel` se ancla con un offset Y de `-spacingSm` (-8px) desde el top del Frame para simular el padding superior adicional. Esto mantiene la altura del frame fija en 32px mientras visualmente el texto queda más centrado en la mitad inferior.

**Radius = 0:** los fondos de hover y activo son Textures rectangulares sin redondeo, pintadas con `SetColorTexture`.
