# Component: Icons

> Referencia shadcn: lucide-react (icon library) — Módulo Lua puro — retorna descriptores de textura

## Propósito

Resuelve el nombre de un ícono Lucide al descriptor de textura (ruta TGA + coordenadas UV del atlas) para que los componentes apliquen la textura directamente, sin manipular rutas o coordenadas UV manualmente.

## Arquitectura del módulo

Icons **no crea frames**. Es una tabla de resolución de nombres con helpers de aplicación.

```
Craft.Icons                   (tabla módulo — punto de entrada público)
├── _atlas16   (table)        — mapa nombre→{col, row} para el atlas de 16px (cargado de icons/Atlas.lua)
├── _atlas24   (table)        — mapa nombre→{col, row} para el atlas de 24px
├── Get(name, size?)          — retorna descriptor completo o nil
├── Apply(texture, name, size?) — aplica el ícono a una Texture existente
├── Has(name)                 — bool
└── List()                    — array de todos los nombres disponibles
```

El archivo `icons/Atlas.lua` declara las dos tablas de coordenadas de celda (col/row, base-0) y se carga antes que cualquier componente en `Craft.toc`. `Craft.Icons` construye los descriptores UV en runtime desde esas coordenadas.

### Rutas de los atlas

| Tamaño | Ruta                                                         |
|--------|--------------------------------------------------------------|
| 16px   | `"Interface\\AddOns\\Craft\\media\\lucide-16.tga"`           |
| 24px   | `"Interface\\AddOns\\Craft\\media\\lucide-24.tga"`           |

### Layout del atlas

| Atlas  | Resolución TGA | Grid        | Celda  | Fórmula UV (col/row base-0)                                    |
|--------|----------------|-------------|--------|----------------------------------------------------------------|
| 16px   | 512 × 512 px   | 32 × 32     | 16px   | `left=col/32, right=(col+1)/32, top=row/32, bottom=(row+1)/32` |
| 24px   | 512 × 512 px   | 21 × 21     | 24px   | `left=col/21, right=(col+1)/21, top=row/21, bottom=(row+1)/21` |

El atlas 24px deja ~8px de píxeles sobrantes al final de cada fila/columna (512 mod 24 = 8) — no contienen datos y nunca se mapean.

### Formato del descriptor retornado por `Get()`

```lua
{
  path   = "Interface\\AddOns\\Craft\\media\\lucide-16.tga",
  size   = 16,       -- 16 o 24 según el parámetro size
  left   = 0.0,      -- UV coords normalizadas [0.0–1.0]
  right  = 0.0625,   -- 1/16 para atlas 16px (col=0)
  top    = 0.0,
  bottom = 0.0625,
}
```

## Catálogo de íconos — Atlas MVP

Los íconos necesarios para los 16 componentes de la librería. Ordenados por fila en el atlas (row=0 a N):

| Nombre Lucide      | Uso en Craft                                     |
|--------------------|--------------------------------------------------|
| `check`            | Checkbox checked, estado success                 |
| `minus`            | Checkbox indeterminate                           |
| `square`           | Checkbox unchecked (borde)                       |
| `square-check`     | Checkbox checked visual alternativo              |
| `chevron-down`     | Select trigger, Accordion, ComboBox              |
| `chevron-up`       | Invertido para estado abierto                    |
| `chevron-right`    | Sidebar item con hijos, breadcrumb separator     |
| `chevron-left`     | Navegación atrás, paginación                     |
| `x`                | Cerrar Dialog, limpiar Input, Badge dismiss      |
| `search`           | Input de búsqueda, CommandPalette                |
| `eye`              | Toggle visibilidad en Input password             |
| `eye-off`          | Estado oculto en Input password                  |
| `info`             | Toast informativo, Tooltip icon                  |
| `alert-triangle`   | Toast warning, estado warning                    |
| `alert-circle`     | Toast error, estado destructivo                  |
| `check-circle`     | Toast success, estado success                    |
| `loader`           | Spinner en Button cargando, estado pending       |
| `plus`             | Botones de añadir, CommandItem                   |
| `settings`         | Ícono genérico de configuración                  |
| `user`             | Avatar fallback, perfil                          |
| `menu`             | Hamburger, Sidebar toggle                        |
| `panel-left`       | Toggle Sidebar                                   |
| `grip-vertical`    | Handle de resize / drag en paneles               |
| `arrow-left`       | Navegación, Breadcrumb                           |
| `arrow-right`      | Navegación, Breadcrumb, acción forward           |

## API pública

| Función                              | Firma                                  | Descripción                                                                                      |
|--------------------------------------|----------------------------------------|--------------------------------------------------------------------------------------------------|
| `Craft.Icons.Get(name, size?)`       | `(string, number?) → table\|nil`       | Retorna el descriptor UV o `nil` si el ícono no existe en el atlas. `size` = 16 (default) o 24. |
| `Craft.Icons.Apply(tex, name, size?)` | `(Texture, string, number?) → void`   | Aplica el ícono a una Texture existente. No-op si `name` es nil o no existe en el atlas.         |
| `Craft.Icons.Has(name)`              | `(string) → bool`                      | Retorna `true` si el nombre existe en `_atlas16`. Útil para validación antes de Apply.           |
| `Craft.Icons.List()`                 | `() → string[]`                        | Array de todos los nombres de ícono disponibles en el atlas 16px, en orden alfabético.           |

## Ejemplos de uso

### Aplicar un ícono a una Texture ya existente (uso más común)

```lua
-- Forma recomendada — Apply es el helper estándar
local tex = frame:CreateTexture(nil, "ARTWORK")
tex:SetSize(16, 16)
tex:SetPoint("LEFT", frame, "LEFT", 8, 0)

Craft.Icons.Apply(tex, "chevron-right")        -- 16px por defecto
Craft.Icons.Apply(tex, "settings", 24)         -- forzar atlas 24px
```

### Usar el descriptor directamente (casos avanzados)

```lua
local icon = Craft.Icons.Get("chevron-right")
if icon then
  tex:SetTexture(icon.path)
  tex:SetTexCoord(icon.left, icon.right, icon.top, icon.bottom)
  tex:SetSize(icon.size, icon.size)
end
```

### Verificar existencia antes de aplicar

```lua
local iconName = config.icon
if iconName and Craft.Icons.Has(iconName) then
  iconTex:Show()
  Craft.Icons.Apply(iconTex, iconName)
else
  iconTex:Hide()
end
```

### Listar íconos disponibles (útil en herramientas de desarrollo)

```lua
local all = Craft.Icons.List()
for _, name in ipairs(all) do
  print(name)
end
```

### Implementación interna de Apply

```lua
function Craft.Icons.Apply(texture, name, size)
  if not name then return end
  local desc = Craft.Icons.Get(name, size or 16)
  if not desc then return end
  texture:SetTexture(desc.path)
  texture:SetTexCoord(desc.left, desc.right, desc.top, desc.bottom)
  texture:SetSize(desc.size, desc.size)
end
```

## Notas de implementación

**nil silencioso, no error**: `Get()` retorna nil para nombres desconocidos — nunca hace `error()`. Los componentes que reciben un `config.icon` desconocido simplemente ocultan la textura de ícono con `iconTex:Hide()`. Esto evita que un typo en el nombre de ícono rompa todo el componente.

**Dos tablas de atlas separadas**: `_atlas16` y `_atlas24` son tablas distintas cargadas desde `icons/Atlas.lua`. `Get(name, 16)` busca en `_atlas16`; `Get(name, 24)` busca en `_atlas24`. Un ícono puede existir en 16px pero no en 24px (el atlas 24px es un subconjunto más pequeño para los casos que necesitan iconos estándar de 24px como `iconSizeMd`).

**Coordenadas UV normalizadas**: WoW espera coordenadas en `[0.0, 1.0]`. La fórmula para atlas 16px: `left = col / 32`, `right = (col + 1) / 32`, `top = row / 32`, `bottom = (row + 1) / 32`. Para atlas 24px: dividir entre 21 en lugar de 32.

**SetTexCoord — orden de argumentos**: WoW usa `SetTexCoord(left, right, top, bottom)` — no el orden CSS estándar. Asegurarse de pasar los cuatro valores en este orden exacto al llamar la API nativa.

**Atlas generado en release**: El archivo `lucide-16.tga` y `lucide-24.tga` se generan con `scripts/export-icons.py` que toma los SVGs de lucide-icons, los rasteriza a 16px/24px, y los empaqueta en el grid. `icons/Atlas.lua` se genera en el mismo proceso con el mapa de coordenadas. No editar `Atlas.lua` a mano.

**Colorización de íconos**: WoW permite colorizar una textura con `tex:SetVertexColor(r, g, b, a)`. Los componentes usan esto para adaptar el color del ícono al estado (e.g., `t.mutedForeground` para íconos deshabilitados, `t.foreground` para íconos activos). `Apply()` no aplica color — el componente es responsable de llamar `SetVertexColor` después.

**Performance**: `_atlas16` y `_atlas24` se cargan una sola vez al inicio. `Get()` es una simple lookup de tabla — O(1), sin costo notable. No cachear los descriptores retornados por `Get()` ya que son tablas nuevas en cada llamada — si el componente necesita el descriptor varias veces, guardarlo en una variable local.
