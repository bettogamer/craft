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

**Sin indicador de línea activa (solo `variant="default"`)**: en la variante **default**, Lyra tabs NO tienen el indicador de 2px bajo la tab activa; el estado activo se expresa mediante fondo diferente de la tab activa vs inactiva. La variante **`line`** (FR-042) **sí** dibuja el subrayado de 2px — ver [Variante `line`](#variante-line-fr-042).

## Dimensiones

| Elemento | Valor |
|---|---|
| TabList height | 32px (`h-8`) base — crece en múltiplos de fila si los tabs hacen wrap |
| TabList padding interno | 3px en todos los lados (`p-[3px]`) |
| Tab inner height efectiva | 32 − 3×2 = 26px |
| Tab padding horizontal | 6px (`px-1.5`) |
| Tab padding vertical | 2px (`py-0.5`) |
| Tab padding H con ícono | 4px (`pr-1` o `pl-1` según lado) |
| Tab gap con ícono | 6px (`gap-1.5`) |
| Tab width | automático según texto + padding horizontal (no se estira). Con `fill=true`: igual ancho, reparto del ancho útil de la lista (FR-043) |
| Tab height | igual a inner height del TabList (26px efectivo) |
| ListBorder height | 1px — usar `Craft.Theme.SetPixelHeight(border, 1)` |
| ListBorder posición | BOTTOM de `_list`, cubre todo el ancho |
| Content padding | 16px (`t.spacingLg`) |
| Tab font size | 12px (`text-xs`) |

## Variantes / Configuraciones

Solo hay un tamaño de TabList: `h-8` = 32px. No existe variante `sm` separada en Lyra tabs.

### Variante `line` (FR-042)

`Create(parent, { variant = "line" })` (`data-[variant=line]`). Barra **transparente**
con la línea inferior completa (`border-b`, la misma `_listBorder` que la default) y la
tab activa marcada con un **subrayado de 2px** en `t.foreground` en vez de fondo. El
modelo de layout, wrap, show/hide de content, icon slots y la API pública **no cambian**.

| Aspecto | `default` | `line` |
|---|---|---|
| Fondo de la barra (`_listBg`) | `t.muted` | transparente (a=0) |
| Línea inferior (`_listBorder`) | 1px `t.border` | 1px `t.border` (se conserva) |
| Padding interno de la barra | `p-[3px]` | sin padding (triggers pegados al borde) |
| Separación entre triggers | 0 (wrap Flex) | `gap-1` = 4px |
| Estado activo | fondo diferenciado | **subrayado 2px** `t.foreground`, sin fondo |
| Estado inactivo | texto `t.mutedForeground` | texto `t.mutedForeground`, subrayado oculto |
| Hover | fondo `t.accent` | texto → `t.foreground` (sin fondo) |

El subrayado es una textura `_underline` por trigger, de 2px pixel-perfect
(`Craft.Theme.SetPixelHeight(_, 2)`, ADR-0011), anclada al borde inferior del trigger
(`BOTTOMLEFT`+`BOTTOMRIGHT`) para que coincida con `_listBorder` y siga al trigger activo
incluso si los triggers hacen wrap a otra fila. Visible solo bajo la tab activa.

### `fill` — barra full-width, triggers de igual ancho (FR-043)

`Create(parent, { fill = true })` reproduce el patrón shadcn `TabsList w-full` +
trigger `flex-1`: la barra ocupa el ancho del frame (ya lo hace: `_list` ancla
`TOPLEFT`/`TOPRIGHT`) y los triggers **dejan de ser ancho-contenido** para
repartirse el ancho en **columnas iguales** (segmented control). El label se
**centra** en su celda.

| Aspecto | `fill=false` (default) | `fill=true` |
|---|---|---|
| Flex del trigger | `grow=0, shrink=0, basis="auto"` | `grow=1, shrink=1, basis=0` (`flex-1`) |
| Ancho de cada trigger | contenido (texto + padding) | `(ancho útil de la lista) / n` iguales |
| Alineación del label | centrado en su celda de contenido | centrado en su celda (igual ancho) |
| Overflow | wrap a filas nuevas | 1 fila (con pocos tabs siempre caben) |

Solo cambia el reparto horizontal del Flex; **el resto del motor no cambia**
(show/hide, icon slots, subrayado de `line`, theming, API). Compone con `variant`:
en `line` + `fill` los triggers reparten igual pero la barra sigue transparente
con `border-b` y el subrayado sigue al trigger activo (ancho real de la celda).

> **`basis=0` en Lua:** `0` es *truthy*, así que `Craft.Flex.Add` lo respeta
> (`itemConfig.basis or "auto"` no lo pisa). Con `basis=0 + grow=1` el motor reparte
> el `freeSpace` en partes iguales (`freeSpace/n`).

### Diferencias conocidas vs shadcn (fuera de MVP)

shadcn ofrece esta feature que Craft **aún no** implementa (omisión de alcance,
no bug — ver `docs/design-reference.md` §9.1):
- **Orientación vertical** (`group-data-vertical/tabs`): TabList en columna a un lado
  del contenido.

Si se decide implementar, requiere aprobación del maintainer (cambio de API).

**Implementado:** icon slots (`has-data-[icon=inline-start]`) — ícono Lucide antes
del label vía `AddTab(id, label, { icon = "<name>" })` o `tabs[i].icon`. Variante
`line` (FR-042, ver arriba).

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
| `tabs` | array | `{}` | Array de tablas `{id, label, icon?}` que definen las pestañas iniciales |
| `tabs[i].id` | string | — | Identificador único de la tab |
| `tabs[i].label` | string | — | Texto visible en el Button de la tab |
| `tabs[i].icon` | string | nil | Nombre de ícono Lucide opcional, mostrado antes del label |
| `defaultTab` | string | primer id | Id de la tab activa al crear el componente |
| `onTabChange` | function | nil | Callback `function(newId, oldId)` invocado al cambiar de tab |
| `variant` | string | `"default"` | `"default"` (barra `bg-muted`) o `"line"` (barra transparente + subrayado activo, FR-042) |
| `fill` | bool | `false` | `true` = barra full-width con triggers de **igual ancho** (`flex-1`, segmented control, FR-043). `false` (default) = triggers ancho-contenido con wrap |

No hay parámetro `size` — el TabList tiene un único tamaño (32px `h-8`).

## API pública

| Método | Retorno | Descripción |
|---|---|---|
| `GetFrame()` | Frame | Retorna `tabs.frame` |
| `GetContent()` | Frame | Retorna `tabs._content` — frame padre de todos los content panels |
| `SetActiveTab(id)` | void | Activa la tab con el id indicado; oculta las demás; dispara `onTabChange` |
| `GetActiveTab()` | string | Retorna el id de la tab actualmente activa |
| `AddTab(id, label, opts?)` | void | Agrega una tab al final y reflowea la barra. `opts.icon` = ícono Lucide opcional antes del label |
| `RemoveTab(id)` | void | Quita la tab y su content frame, y reflowea. Si era la activa, activa la primera restante (o ninguna) |
| `GetContentFrame(id)` | Frame | Frame de contenido de esa tab — el dev añade aquí sus hijos |
| `SetTabEnabled(id, enabled)` | void | Habilita/deshabilita el trigger (deshabilitado: a=0.5, sin mouse) |

## Notas de implementación

**Modelo de dimensionamiento y overflow (decisión de diseño):**
> ⚠️ **Divergencia deliberada de shadcn.** shadcn **no** hace wrap de los
> triggers. Este wrap es una decisión Craft registrada en
> `docs/design-reference.md` §9. **No revertir hacia shadcn en un
> `/update-design-tokens` sin aprobación del maintainer.**

Cada trigger es **ancho-contenido** (texto + padding horizontal), **alineado a la
izquierda**, **sin estiramiento**. Se distribuyen con `Craft.Flex`
(`direction="row"`, `wrap="wrap"`, `justify="flex-start"`, `align="stretch"`,
items con `grow=0, shrink=0, basis="auto"`). Cuando los triggers ya no caben en
una fila, **hacen wrap a filas adicionales** y la barra crece en alto. Es fiel a
shadcn (los triggers se dimensionan al contenido) y degrada bien con pocos o
muchos tabs. Se evaluaron scroll horizontal y fill con piso de ancho; se eligió
wrap **por defecto** por simplicidad (Flex ya lo soporta) y consistencia visual.
El **fill a ancho igual** existe como opt-in explícito (`fill=true`, FR-043) para
el caso segmented-control con pocos tabs — ver [`fill`](#fill--barra-full-width-triggers-de-igual-ancho-fr-043).

**Auto-width de cada tab:**
```lua
local textWidth = tab._text:GetStringWidth()
local tabWidth = textWidth + 6 * 2  -- px-1.5 = 6px cada lado
tab:SetWidth(tabWidth)
```

**Crecimiento de la barra al hacer wrap:**
Tras cada `Flex:Layout()`, leer `Flex:GetContentCross()` (alto total consumido,
padding incluido) y aplicarlo con `_list:SetHeight()`. Re-ejecutar en `OnShow` y
`OnSizeChanged` del `_list` (un cambio de ancho puede añadir/quitar filas). Usar
un guard de reentrancia porque `SetHeight` re-dispara `OnSizeChanged`.

**Sin indicador activo (variante `default`)**: no crear `_indicator` texture. El estado activo se expresa solo con color de texto (`t.foreground` vs `t.mutedForeground`) y fondo diferenciado de la tab activa. La variante `line` **sí** crea un `_underline` de 2px por trigger (ver [Variante `line`](#variante-line-fr-042)).

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
`AddTab` fija el ancho del nuevo button según su texto, lo agrega al Flex y llama
`_relayout()`. El Flex reposiciona todos los triggers y hace wrap si el total
excede el ancho disponible; la barra crece en alto para acomodar las filas.

**Tab disabled:**
```lua
tab:EnableMouse(false)
tab._text:SetTextColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 0.5)
```

**Separator (`_listBorder`):**
Texture de 1px de alto anclada al borde inferior de `_list`, `SetPoint("TOPLEFT", _list, "BOTTOMLEFT", 0, 0)` y `SetPoint("TOPRIGHT", _list, "BOTTOMRIGHT", 0, 0)`, pintada con `t.border`. Usar `Craft.Theme.SetPixelHeight(_listBorder, 1)` (ADR-0011).

**Radius = 0:** sin esquinas redondeadas (`rounded-none`).
