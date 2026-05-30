# Component: Flex

> Referencia shadcn: N/A (motor de layout CSS Flexbox adaptado a WoW) — Módulo Lua puro — opera sobre frames existentes

## Propósito

Motor de layout que calcula y aplica posiciones (`SetPoint`) a frames hijos de un contenedor siguiendo el modelo CSS Flexbox, incluyendo dirección, wrap, justify-content, align-items y propiedades por item (grow, shrink, basis, order).

## Arquitectura del módulo

Flex **no crea frames visuales propios**. Actúa como un calculador de geometría: recibe un frame contenedor y una lista de frames hijos, y aplica `SetPoint` / `SetSize` en ellos. El módulo expone una API de instancia para mantener el estado del layout entre relayouts.

```
Craft.Flex                  (tabla módulo — punto de entrada público)
└── Craft.Flex.new(...)     → flex_instance

flex_instance               (tabla — estado de un layout concreto)
├── _container  (Frame)     — frame contenedor de referencia para dimensiones
├── _config     (table)     — propiedades del contenedor (direction, wrap, justify, align, gap, …)
├── _items      (table)     — array de {frame, itemConfig} en orden de inserción
└── _sorted     (table)     — array de items ordenado por itemConfig.order (recalculado en Layout)
```

Cada elemento en `_items`:
```lua
{
  frame      = <Frame>,     -- el frame WoW hijo
  grow       = 0,           -- número ≥ 0
  shrink     = 1,           -- número ≥ 0
  basis      = "auto",      -- número en px, o "auto"
  alignSelf  = "auto",      -- override de align-items para este item
  order      = 0,           -- entero, menor order = antes en el layout
}
```

## Dimensiones / Comportamiento

El layout se calcula con las dimensiones actuales del contenedor en el momento de llamar `flex:Layout()`. No hay observación reactiva de cambios — el developer es responsable de llamar `Layout()` cuando el contenedor o los hijos cambian de tamaño.

| Propiedad del contenedor | Valores válidos                                                          | Default        |
|--------------------------|--------------------------------------------------------------------------|----------------|
| `direction`              | `"row"`, `"row-reverse"`, `"column"`, `"column-reverse"`                 | `"row"`        |
| `wrap`                   | `"nowrap"`, `"wrap"`, `"wrap-reverse"`                                   | `"nowrap"`     |
| `justify`                | `"flex-start"`, `"flex-end"`, `"center"`, `"space-between"`, `"space-around"`, `"space-evenly"` | `"flex-start"` |
| `align`                  | `"flex-start"`, `"flex-end"`, `"center"`, `"stretch"`, `"baseline"`      | `"stretch"`    |
| `gap`                    | número (px) — aplicado entre items en el main axis (y entre líneas si wrap) | `0`          |
| `paddingH`               | número (px) — padding izquierdo y derecho del contenedor                 | `0`            |
| `paddingV`               | número (px) — padding superior e inferior del contenedor                 | `0`            |

| Propiedad por item   | Tipo             | Default    | Descripción                                              |
|----------------------|------------------|------------|----------------------------------------------------------|
| `grow`               | número ≥ 0       | `0`        | Factor de crecimiento proporcional en free space > 0     |
| `shrink`             | número ≥ 0       | `1`        | Factor de contracción proporcional en free space < 0     |
| `basis`              | número\|`"auto"` | `"auto"`   | Tamaño base en el main axis. `"auto"` = dimensión actual del frame |
| `alignSelf`          | string           | `"auto"`   | Sobreescribe `align` del contenedor para este item       |
| `order`              | entero           | `0`        | Orden visual — no altera `_items`, solo `_sorted`        |

## API pública

| Función                         | Firma                              | Descripción                                                                                      |
|---------------------------------|------------------------------------|--------------------------------------------------------------------------------------------------|
| `Craft.Flex.new(container, cfg)` | `(Frame, table?) → flex_instance` | Crea una instancia flex para `container`. `cfg` es opcional — se pueden aplicar defaults.        |
| `flex:Add(frame, itemConfig)`   | `(Frame, table?) → item_ref`       | Agrega un frame como item. `itemConfig` es opcional. Retorna la tabla item para modificación posterior. No llama Layout() automáticamente. |
| `flex:Remove(frame)`            | `(Frame) → void`                   | Elimina el item con ese frame de `_items`. No llama Layout().                                    |
| `flex:Layout()`                 | `() → void`                        | Calcula y aplica `SetPoint` (y `SetSize` para `stretch`) a todos los items. Llama siempre que cambie el contenido o las dimensiones. |
| `flex:SetConfig(cfg)`           | `(table) → void`                   | Merge de `cfg` sobre `_config` y llama `Layout()` automáticamente.                              |
| `flex:Clear()`                  | `() → void`                        | Vacía `_items`. No oculta ni destruye los frames — solo los desregistra del layout.              |
| `flex:GetItems()`               | `() → table`                       | Retorna `_items` (read-only por convención).                                                     |

## Algoritmo de Layout

Descripción paso a paso de `flex:Layout()`:

```
1. Ordenar _items por item.order ASC → _sorted
2. Determinar main axis y cross axis según direction:
     row / row-reverse  → main = width,  cross = height
     column / column-reverse → main = height, cross = width
3. Calcular dimensión main disponible:
     mainAvail = container[main] - paddingH*2 (o paddingV*2) - gap*(n-1)
   (con row-reverse / column-reverse: invertir el orden de _sorted)
4. Resolver flex-basis de cada item:
     basis = "auto" → item.frame:GetWidth() o GetHeight() según main axis
     basis = número → usar ese número directamente
5. Sumar bases → totalBasis
6. freeSpace = mainAvail - totalBasis
7. Si freeSpace > 0 y algún item tiene grow > 0:
     totalGrow = sum(item.grow para items con grow > 0)
     extra_i = freeSpace * (item.grow / totalGrow)
     size_i = basis_i + extra_i
8. Si freeSpace < 0 y algún item tiene shrink > 0:
     totalShrink = sum(item.shrink * basis_i)  -- ponderado
     deficit_i = |freeSpace| * (item.shrink * basis_i / totalShrink)
     size_i = basis_i - deficit_i  (mínimo 0)
9. Si freeSpace == 0 o no hay grow/shrink aplicable:
     size_i = basis_i
10. Si wrap != "nowrap":
     Agrupar items en líneas: abrir nueva línea cuando
     sum(size_i + gap) > mainAvail
     Si wrap-reverse: invertir el orden de las líneas
11. Para cada línea, calcular posición main axis con justify:
     flex-start   → acumular desde padding
     flex-end     → acumular desde (mainAvail - totalSize)
     center       → offset = (mainAvail - totalSize) / 2
     space-between→ gap = freeSpace / (n-1)  (n=items en la línea)
     space-around → gap = freeSpace / n, half-gap en extremos
     space-evenly → gap = freeSpace / (n+1)
12. Para cada item, resolver cross axis con alignSelf (o align si alignSelf="auto"):
     flex-start → pos_cross = paddingV (o paddingH)
     flex-end   → pos_cross = container[cross] - paddingV - item_cross_size
     center     → pos_cross = (container[cross] - item_cross_size) / 2
     stretch    → SetWidth/SetHeight del item = línea_cross_size - paddingV*2 (o paddingH*2)
     baseline   → tratar como flex-start (WoW no tiene baseline real)
13. Traducir (main_pos, cross_pos) a coordenadas WoW:
     direction=row          → SetPoint("TOPLEFT", container, "TOPLEFT", paddingH + main_pos, -(paddingV + cross_pos))
     direction=column       → SetPoint("TOPLEFT", container, "TOPLEFT", paddingH + cross_pos, -(paddingV + main_pos))
     direction=row-reverse  → anclar desde TOPRIGHT
     direction=column-reverse → anclar desde BOTTOMLEFT
14. Limpiar puntos previos de cada frame: frame:ClearAllPoints() antes del SetPoint nuevo
```

## Ejemplos de uso

### Row básico con gap

```lua
local container = CreateFrame("Frame", nil, UIParent)
container:SetSize(400, 48)
container:SetPoint("CENTER")

local flex = Craft.Flex.new(container, {
  direction = "row",
  align     = "center",
  gap       = 8,         -- spacingSm
  paddingH  = 12,        -- spacingMd
  paddingV  = 8,
})

local btnA = Craft.Button.Create(container, { text = "Cancel", variant = "outline" })
local btnB = Craft.Button.Create(container, { text = "Confirm", variant = "default" })

flex:Add(btnA:GetFrame())
flex:Add(btnB:GetFrame())
flex:Layout()
```

### Grow para que un item ocupe el espacio restante

```lua
local flex = Craft.Flex.new(container, {
  direction = "row",
  align     = "center",
  gap       = 8,
})

local icon  = CreateFrame("Frame", nil, container)
icon:SetSize(24, 24)

local label = CreateFrame("Frame", nil, container)
label:SetSize(100, 20)  -- tamaño inicial, crecerá

local badge = CreateFrame("Frame", nil, container)
badge:SetSize(48, 20)

flex:Add(icon)
flex:Add(label, { grow = 1 })   -- ocupa todo el espacio libre
flex:Add(badge)
flex:Layout()
```

### Auto-relayout al resize del contenedor

```lua
container:HookScript("OnSizeChanged", function()
  flex:Layout()
end)
```

### Column con justify space-between

```lua
local flex = Craft.Flex.new(sidebar, {
  direction = "column",
  justify   = "space-between",
  paddingV  = 16,
})

for _, item in ipairs(navItems) do
  flex:Add(item:GetFrame())
end
flex:Layout()
```

## Notas de implementación

**ClearAllPoints antes de SetPoint**: Cada vez que `Layout()` aplica posiciones, debe llamar `frame:ClearAllPoints()` en cada item para evitar conflictos de anclaje múltiple. WoW no permite SetPoint si el frame ya tiene puntos que crean un ciclo de dependencia.

**Stretch en cross axis**: Para `align = "stretch"` o `alignSelf = "stretch"`, Flex debe llamar `frame:SetWidth()` o `frame:SetHeight()` en el item para forzar que ocupe toda la cross-axis de su línea. Esto modifica las dimensiones del frame hijo directamente — documentar este comportamiento para que el developer lo espere.

**Dimensiones del contenedor**: `container:GetWidth()` / `container:GetHeight()` retornan 0 si el frame no tiene dimensiones definidas aún. Si el contenedor usa `SetAllPoints` o tiene su tamaño determinado por anchors, las dimensiones pueden estar disponibles solo después del primer frame draw. Para evitar layout en tamaño cero, añadir una guarda: `if container:GetWidth() == 0 then return end`.

**Order no reordena _items**: La propiedad `order` solo afecta `_sorted` (recalculado en cada `Layout()`). `_items` mantiene el orden de inserción para que `Remove()` funcione correctamente.

**Wrap y múltiples líneas**: En modo `wrap`, cada línea tiene su propia dimensión cross-axis (la del item más alto/ancho en esa línea). El `align-content` entre líneas no está implementado en MVP — las líneas simplemente se colocan en secuencia desde el inicio del cross axis con el gap entre ellas.

**gap entre líneas (wrap)**: El mismo valor `gap` aplica tanto entre items en una línea (main axis) como entre líneas (cross axis). No hay `rowGap`/`columnGap` separados en esta versión.

**Baseline**: WoW no provee acceso al baseline tipográfico de los FontStrings. `align = "baseline"` se implementa como `"flex-start"` — documentar esta limitación explícitamente.
