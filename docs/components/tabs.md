# Component: Tabs

> Referencia shadcn: `tabs` — WoW frame base: `Frame` con Button hijos por tab

## Propósito

Organiza contenido en paneles exclusivos (solo uno visible a la vez) seleccionables mediante una barra de pestañas horizontal con indicador activo.

## Jerarquía de frames WoW

```
tabs.frame              (Frame)                        raíz del componente
├── tabs._list          (Frame, 36px alto)             barra de tabs
│   ├── tabs._listBg    (Texture)                      fondo de la barra (muted)
│   ├── tabs._tab[1]    (Button)                       pestaña 1
│   │   ├── tabs._tab[1]._text      (FontString)       etiqueta de la tab
│   │   └── tabs._tab[1]._indicator (Texture, 2px)     línea activa inferior
│   ├── tabs._tab[2]    (Button)                       pestaña 2
│   │   ├── ...
│   └── ...
├── tabs._listBorder    (Texture, 1px alto)            línea completa bajo la barra
└── tabs._content       (Frame)                        área de contenido
    ├── content_frame_1  (Frame del dev)               panel de la tab 1
    ├── content_frame_2  (Frame del dev)               panel de la tab 2
    └── ...
```

Los content frames son los frames que el dev pasa en `config.tabs[i].content_frame`; se reparentan a `tabs._content` y se muestran u ocultan según la tab activa.

## Dimensiones

| Elemento | Valor |
|---|---|
| TabList height (default) | 36px |
| TabList height (sm) | 32px |
| Tab padding horizontal | 12px (`t.spacingMd`) |
| Tab min width | 64px |
| Tab height | igual a TabList height (36px o 32px) |
| Active indicator height | 2px |
| Active indicator width | igual al ancho del Button de la tab |
| Active indicator posición | BOTTOM del Button, offset Y=0 |
| ListBorder height | 1px |
| ListBorder posición | BOTTOM de `_list`, cubre todo el ancho |
| Content padding | 16px (`t.spacingLg`) |
| Tab font size | 12px (`t.fontSize`) |

## Variantes / Configuraciones

| Size | TabList height |
|---|---|
| `default` | 36px |
| `sm` | 32px |

## Estados

| Elemento | Estado | Visual |
|---|---|---|
| Tab | Inactive | Texto `t.mutedForeground`, fondo transparente, indicator oculto |
| Tab | Hover | Fondo `t.accent`, texto `t.mutedForeground` |
| Tab | Active | Texto `t.foreground`, indicator visible color `t.primary`, fondo transparente |
| Tab | Disabled | Texto `t.mutedForeground` con a=0.5, mouse deshabilitado (`EnableMouse(false)`) |
| TabList | Default | Fondo `t.muted` |
| Content | Visible | Frame activo mostrado con `Show()` |
| Content | Oculto | Frames inactivos ocultos con `Hide()` |

## Mapa de tokens

| Elemento | Token |
|---|---|
| Fondo de la barra (TabList) | `t.muted` |
| Separador bajo la barra | `t.border` |
| Texto de tab inactiva | `t.mutedForeground` |
| Texto de tab activa | `t.foreground` |
| Fondo de tab en hover | `t.accent` |
| Indicador de tab activa | `t.primary` |
| Texto de tab disabled | `t.mutedForeground` (a=0.5) |
| Padding de tab horizontal | `t.spacingMd` (12px) |
| Padding del área de content | `t.spacingLg` (16px) |
| Fuente de tab | `t.font`, `t.fontSize` (12px) |

## Config — `Create(parent, config)`

| Parámetro | Tipo | Default | Descripción |
|---|---|---|---|
| `tabs` | array | `{}` | Array de tablas `{id, label, content_frame}` que definen las pestañas iniciales |
| `tabs[i].id` | string | — | Identificador único de la tab |
| `tabs[i].label` | string | — | Texto visible en el Button de la tab |
| `tabs[i].content_frame` | Frame | — | Frame ya construido a mostrar cuando la tab está activa |
| `defaultTab` | string | primer id | Id de la tab activa al crear el componente |
| `size` | string | `"default"` | Altura de la barra: `"default"` (36px) o `"sm"` (32px) |
| `onTabChange` | function | nil | Callback `function(newId, oldId)` invocado al cambiar de tab |

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
local tabWidth = math.max(64, textWidth + spacingMd * 2)
tab:SetWidth(tabWidth)
```
Los buttons se posicionan en secuencia horizontal con `SetPoint("LEFT", prevTab, "RIGHT", 0, 0)`.

**Indicador activo:**
```lua
-- Posicionar en el borde inferior del button, ancho igual al button
tab._indicator:SetPoint("BOTTOMLEFT",  tab, "BOTTOMLEFT",  0, 0)
tab._indicator:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
tab._indicator:SetHeight(2)
tab._indicator:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, t.primary.a)
```
Visible solo en la tab activa; oculto en las demás con `tab._indicator:Hide()`.

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
Texture de 1px de alto anclada al borde inferior de `_list`, `SetPoint("TOPLEFT", _list, "BOTTOMLEFT", 0, 0)` y `SetPoint("TOPRIGHT", _list, "BOTTOMRIGHT", 0, 0)`, pintada con `t.border`.

**Radius = 0:** sin esquinas redondeadas. El indicador activo es una Texture rectangular plana.
