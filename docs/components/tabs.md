# Component: Tabs

> Referencia shadcn: `tabs` — WoW frame base: `Frame` con Button hijos por tab

## CSS de referencia (Lyra)

```css
.cn-tabs-list {
  @apply rounded-none p-[3px] group-data-horizontal/tabs:h-8;
}
.cn-tabs-trigger {
  @apply gap-1.5 rounded-none border border-transparent px-1.5 py-0.5 text-xs font-medium
         [&_svg:not([class*='size-'])]:size-4 has-data-[icon=inline-end]:pr-1 has-data-[icon=inline-start]:pl-1;
}
.cn-tabs-content {
  @apply text-xs/relaxed;
}
```

## Propósito

Organiza contenido en paneles exclusivos (solo uno visible a la vez) seleccionables mediante una barra de pestañas horizontal con indicador activo.

## Jerarquía de frames WoW

```
tabs.frame              (Frame)                        raíz del componente
├── tabs._list          (Frame, 32px alto)             barra de tabs
│   ├── tabs._listBg    (Texture)                      fondo de la barra (muted)
│   ├── tabs._tab[1]    (Button)                       pestaña 1
│   │   └── tabs._tab[1]._text      (FontString)       etiqueta de la tab
│   ├── tabs._tab[2]    (Button)                       pestaña 2
│   │   └── ...
│   └── ...
├── tabs._listBorder    (Texture, 1px alto)            línea completa bajo la barra
└── tabs._content       (Frame)                        área de contenido
    ├── content_frame_1  (Frame del dev)               panel de la tab 1
    ├── content_frame_2  (Frame del dev)               panel de la tab 2
    └── ...
```

Los content frames son los frames que el dev pasa en `config.tabs[i].content_frame`; se reparentan a `tabs._content` y se muestran u ocultan según la tab activa.

**Sin indicador de línea activa**: Lyra tabs NO tienen el indicador de 2px bajo la tab activa (ese patrón corresponde a new-york/default variant, no a Lyra). El estado activo se expresa mediante fondo diferente de la tab activa vs inactiva.

## Dimensiones

| Elemento | Valor |
|---|---|
| TabList height | 32px (`h-8`) — único tamaño |
| TabList padding interno | 3px en todos los lados (`p-[3px]`) |
| Tab inner height efectiva | 32 − 3×2 = 26px |
| Tab padding horizontal | 6px (`px-1.5`) |
| Tab padding vertical | 2px (`py-0.5`) |
| Tab padding H con ícono | 4px (`pr-1` o `pl-1` según lado) |
| Tab gap con ícono | 6px (`gap-1.5`) |
| Tab min width | automático según texto |
| Tab height | igual a inner height del TabList (26px efectivo) |
| ListBorder height | 1px — usar `Craft.Theme.SetPixelHeight(border, 1)` |
| ListBorder posición | BOTTOM de `_list`, cubre todo el ancho |
| Content padding | 16px (`t.spacingLg`) |
| Tab font size | 12px (`text-xs`) |

## Variantes / Configuraciones

Solo hay un tamaño de TabList: `h-8` = 32px. No existe variante `sm` separada en Lyra tabs.

## Estados

| Elemento | Estado | Visual |
|---|---|---|
| Tab | Inactive | Texto `t.mutedForeground`, fondo transparente, borde transparente |
| Tab | Hover | Fondo `t.accent`, texto `t.mutedForeground` |
| Tab | Active | Texto `t.foreground`, fondo diferenciado del list (ver nota), borde transparente |
| Tab | Disabled | Texto `t.mutedForeground` con a=0.5, mouse deshabilitado (`EnableMouse(false)`) |
| TabList | Default | Fondo `t.muted` |
| Content | Visible | Frame activo mostrado con `Show()` |
| Content | Oculto | Frames inactivos ocultos con `Hide()` |

**Nota sobre el estado activo**: Lyra tabs no tienen indicador de línea. El trigger siempre lleva `border border-transparent` — la diferenciación visual de la tab activa se expresa mediante el fondo del botón activo contrastando con el fondo muted del tablist. Implementar la tab activa con un fondo ligeramente más claro o más oscuro que `t.muted` (por ejemplo `t.background` o `t.card`). Si el diseño no especifica el color exacto del fondo activo, usar transparente con un borde visible.

## Mapa de tokens

| Elemento | Token |
|---|---|
| Fondo de la barra (TabList) | `t.muted` |
| Separador bajo la barra | `t.border` (1px, pixel-perfect) |
| Texto de tab inactiva | `t.mutedForeground` |
| Texto de tab activa | `t.foreground` |
| Fondo de tab en hover | `t.accent` |
| Texto de tab disabled | `t.mutedForeground` (a=0.5) |
| Padding de tab horizontal | 6px (`px-1.5`) |
| Padding del área de content | `t.spacingLg` (16px) |
| Fuente de tab | `t.font`, `t.fontSize` (12px) |

**Eliminado**: `Indicador de tab activa` con `t.primary` — Lyra tabs no tienen indicador de línea.

## Config — `Create(parent, config)`

| Parámetro | Tipo | Default | Descripción |
|---|---|---|---|
| `tabs` | array | `{}` | Array de tablas `{id, label, content_frame}` que definen las pestañas iniciales |
| `tabs[i].id` | string | — | Identificador único de la tab |
| `tabs[i].label` | string | — | Texto visible en el Button de la tab |
| `tabs[i].content_frame` | Frame | — | Frame ya construido a mostrar cuando la tab está activa |
| `defaultTab` | string | primer id | Id de la tab activa al crear el componente |
| `onTabChange` | function | nil | Callback `function(newId, oldId)` invocado al cambiar de tab |

No hay parámetro `size` — el TabList tiene un único tamaño (32px `h-8`).

## API pública

| Método | Retorno | Descripción |
|---|---|---|
| `GetFrame()` | Frame | Retorna `tabs.frame` |
| `GetContent()` | Frame | Retorna `tabs._content` — frame padre de todos los content panels |
| `SetActiveTab(id)` | void | Activa la tab con el id indicado; oculta las demás; dispara `onTabChange` |
| `GetActiveTab()` | string | Retorna el id de la tab actualmente activa |
| `AddTab(id, label, frame)` | void | Agrega una nueva tab al final de la barra y redistribuye los buttons |

## Notas de implementación

**Auto-width de cada tab:**
```lua
local textWidth = tab._text:GetStringWidth()
local tabWidth = textWidth + 6 * 2  -- px-1.5 = 6px cada lado
tab:SetWidth(tabWidth)
```
Los buttons se posicionan en secuencia horizontal con `SetPoint("LEFT", prevTab, "RIGHT", 0, 0)`.

**Sin indicador activo**: no crear `_indicator` texture. El estado activo se expresa solo con color de texto (`t.foreground` vs `t.mutedForeground`) y fondo diferenciado de la tab activa.

**Show/Hide de content frames:**
Los content frames se reparentan a `tabs._content` al ser registrados. Al cambiar de tab activa:
```lua
for _, tab in ipairs(self._tabs) do
    if tab.id == newId then
        tab.content_frame:Show()
    else
        tab.content_frame:Hide()
    end
end
```

**Redistribución al agregar tabs dinámicamente (`AddTab`):**
Recalcular el ancho de todos los buttons y reposicionarlos desde el primer tab. Si el ancho total supera el ancho del componente, considerar scroll horizontal o truncar etiquetas.

**Tab disabled:**
```lua
tab:EnableMouse(false)
tab._text:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 0.5)
```

**Separator (`_listBorder`):**
Texture de 1px de alto anclada al borde inferior de `_list`, `SetPoint("TOPLEFT", _list, "BOTTOMLEFT", 0, 0)` y `SetPoint("TOPRIGHT", _list, "BOTTOMRIGHT", 0, 0)`, pintada con `t.border`. Usar `Craft.Theme.SetPixelHeight(_listBorder, 1)` (ADR-0011).

**Radius = 0:** sin esquinas redondeadas (`rounded-none`).
