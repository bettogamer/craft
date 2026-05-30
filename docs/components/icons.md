# Component: Icons

> Referencia: [lucide.dev](https://lucide.dev) — Módulo Lua puro — retorna descriptores de textura
> WoW frame base: N/A — no crea frames

## Propósito

Resuelve el nombre de un ícono Lucide al descriptor de textura (ruta TGA + coordenadas UV del atlas) para que los componentes apliquen la textura directamente, sin manipular rutas o coordenadas UV manualmente.

---

## Arquitectura del módulo

Icons **no crea frames**. Es una tabla de resolución de nombres.

```
Craft.Icons
├── _atlas16  (table)  — mapa nombre→{col,row} para el atlas 16px (de icons/Atlas.lua)
├── _atlas24  (table)  — mapa nombre→{col,row} para el atlas 24px
├── Get(name, size?)
├── Apply(texture, name, size?)
├── Has(name)
└── List()
```

`icons/Atlas.lua` declara las dos tablas con coordenadas de celda (col/row, base-0). Se carga antes que cualquier componente en `Craft.toc`. `Craft.Icons` construye los descriptores UV en runtime.

### Rutas de los atlas

| Tamaño | Ruta |
|--------|------|
| 16px | `"Interface\\AddOns\\Craft\\media\\lucide-16.tga"` |
| 24px | `"Interface\\AddOns\\Craft\\media\\lucide-24.tga"` |

### Layout del atlas

| Atlas | Resolución TGA | Grid | Celda | Fórmula UV (col/row base-0) |
|-------|---------------|------|-------|----------------------------|
| 16px | 512×512 px | 32×32 | 16px | `left=col/32, right=(col+1)/32, top=row/32, bottom=(row+1)/32` |
| 24px | 512×512 px | 21×21 | 24px | `left=col/21, right=(col+1)/21, top=row/21, bottom=(row+1)/21` |

El atlas 24px deja 8px sobrantes al final de cada fila (512 mod 24 = 8) — nunca se mapean.

### Formato del descriptor retornado por `Get()`

```lua
{
  path   = "Interface\\AddOns\\Craft\\media\\lucide-16.tga",
  size   = 16,       -- 16 o 24
  left   = 0.0,      -- UV coords normalizadas [0.0–1.0]
  right  = 0.0625,   -- 1/32 para atlas 16px (col=0)
  top    = 0.0,
  bottom = 0.0625,
}
```

---

## Catálogo de íconos

> **Todos los nombres son los canónicos de Lucide.** Los íconos renombrados en versiones
> recientes ya aparecen con su nombre nuevo (`triangle-alert`, no `alert-triangle`, etc.).
> El script `scripts/export-icons.py` usa estos nombres exactos para generar el atlas TGA.

### Sistema — usados por Craft internamente

Estos íconos son requeridos por los propios componentes de la librería. Sin ellos, algunos
componentes no renderizan correctamente.

| # | Nombre Lucide | Componente que lo usa | Rol |
|---|---|---|---|
| 1 | `check` | Checkbox (checked), Select (item selected indicator) | Checkmark |
| 2 | `minus` | Checkbox (indeterminate) | Guión horizontal |
| 3 | `chevron-down` | Select trigger | Caret dropdown |
| 4 | `chevron-right` | Sidebar (sub-item indicator) | Flecha derecha |
| 5 | `chevron-up` | Select (scroll up button) | Flecha arriba |
| 6 | `x` | Dialog (close button) | X de cierre |
| 7 | `eye` | Input (password show) | Ojo abierto |
| 8 | `eye-off` | Input (password hide) | Ojo cerrado |

### Conveniencia — para addons que usan Craft

Estos íconos no son requeridos por ningún componente de la librería, pero son los más
usados en addons WoW y se incluyen en el atlas para que los devs los tengan disponibles.

| # | Nombre Lucide | Uso típico en addons WoW |
|---|---|---|
| 9 | `info` | Tooltip informativo, Alert info |
| 10 | `circle-check` | Feedback de éxito (¹) |
| 11 | `circle-alert` | Feedback de error (¹) |
| 12 | `triangle-alert` | Feedback de warning (¹) |
| 13 | `loader-circle` | Spinner en Button loading, estado pending |
| 14 | `search` | Input de búsqueda |
| 15 | `plus` | Botones de agregar |
| 16 | `chevron-left` | Navegación atrás, paginación |
| 17 | `arrow-left` | Navegación, breadcrumb |
| 18 | `arrow-right` | Navegación, breadcrumb, forward |
| 19 | `settings` | Configuración general |
| 20 | `user` | Avatar fallback, perfil |
| 21 | `menu` | Hamburger, sidebar toggle |
| 22 | `panel-left` | Toggle sidebar |
| 23 | `grip-vertical` | Handle de drag/resize |
| 24 | `square-check` | Checkbox alternativo visual |

> (¹) Nombres canónicos actuales en Lucide. Los nombres anteriores (`check-circle`,
> `alert-circle`, `alert-triangle`) son aliases deprecados — no usar en Atlas.lua.

**Total**: 24 íconos. Caben en 1 fila del atlas 16px (32 celdas por fila) y en 2 filas del
atlas 24px (21 celdas × 2 = 42 > 24).

---

## API pública

| Función | Firma | Descripción |
|---------|-------|-------------|
| `Craft.Icons.Get(name, size?)` | `(string, number?) → table\|nil` | Descriptor UV o nil si no existe. `size`=16 (default) o 24. |
| `Craft.Icons.Apply(tex, name, size?)` | `(Texture, string, number?) → void` | Aplica ícono a una Texture. No-op si name=nil o no existe. |
| `Craft.Icons.Has(name)` | `(string) → bool` | true si el nombre existe en `_atlas16`. |
| `Craft.Icons.List()` | `() → string[]` | Array de todos los nombres disponibles, orden alfabético. |

---

## Ejemplos de uso

### Forma recomendada — `Apply`

```lua
local tex = frame:CreateTexture(nil, "ARTWORK")
tex:SetSize(16, 16)
tex:SetPoint("LEFT", frame, "LEFT", 8, 0)
Craft.Icons.Apply(tex, "chevron-right")        -- 16px por defecto
Craft.Icons.Apply(tex, "settings", 24)         -- atlas 24px
```

### Con validación previa

```lua
local iconName = config.icon
if iconName and Craft.Icons.Has(iconName) then
    iconTex:Show()
    Craft.Icons.Apply(iconTex, iconName)
else
    iconTex:Hide()
end
```

### Colorizar el ícono según estado

```lua
-- Apply no aplica color — el componente es responsable
Craft.Icons.Apply(iconTex, "info")
local t = Craft.Theme.get()
iconTex:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)
-- Hover: restaurar a foreground
iconTex:SetVertexColor(t.foreground.r, t.foreground.g, t.foreground.b, 1)
```

### Descriptor directo (casos avanzados)

```lua
local icon = Craft.Icons.Get("circle-check")
if icon then
    tex:SetTexture(icon.path)
    tex:SetTexCoord(icon.left, icon.right, icon.top, icon.bottom)
    tex:SetSize(icon.size, icon.size)
end
```

---

## Implementación interna de `Apply`

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

---

## Notas de implementación

**Nombres canónicos Lucide — cambios recientes importantes:**

| Nombre antiguo (deprecado) | Nombre canónico actual |
|---|---|
| `alert-triangle` | `triangle-alert` |
| `alert-circle` | `circle-alert` |
| `check-circle` | `circle-check` |
| `loader` (ícono diferente) | `loader-circle` (spinner circular) |

Usar siempre los nombres canónicos en `Atlas.lua` y en los argumentos de `Apply()`/`Get()`.

**nil silencioso, no error**: `Get()` retorna nil para nombres desconocidos. Los componentes que reciben un `config.icon` desconocido ocultan la textura con `iconTex:Hide()`.

**Dos atlas separados**: `_atlas16` y `_atlas24` son tablas independientes. Un ícono puede existir en 16px pero no en 24px — el atlas 24px es un subconjunto.

**SetTexCoord — orden WoW**: `SetTexCoord(left, right, top, bottom)`. No el orden CSS.

**Colorización**: `SetVertexColor(r, g, b, a)` después de `Apply()`. El módulo no aplica color.

**Performance**: `_atlas16` y `_atlas24` se cargan una sola vez. `Get()` es O(1). No cachear el descriptor retornado (es una tabla nueva cada llamada) — si se necesita varias veces, guardar en variable local.

**Generación del atlas**: `scripts/export-icons.py` toma los SVGs de Lucide por nombre canónico, los rasteriza a 16px/24px y genera el TGA + `icons/Atlas.lua`. No editar `Atlas.lua` manualmente — se sobreescribe en cada release.

**Fila de íconos del sistema en el atlas**: se recomienda colocar los 8 íconos de sistema en la primera fila (posiciones 0–7) del atlas 16px para que sus coordenadas UV sean predecibles y fáciles de hardcodear si fuera necesario.
