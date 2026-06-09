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
├── _atlas  (table)   — mapa nombre→{col,row} (de icons/Atlas.lua)
├── _div    (number)  — celdas por fila/columna del grid (de icons/Atlas.lua)
├── Get(name, size?)
├── Apply(texture, name, size?)
├── Has(name)
└── List()
```

`icons/Atlas.lua` declara la tabla `_atlas` con coordenadas de celda (col/row, base-0) y `_div`. Se carga antes que cualquier componente en `Craft.toc`. `Craft.Icons` construye los descriptores UV en runtime.

### Ruta del atlas

| Ruta |
|------|
| `"Interface\\AddOns\\Craft\\media\\lucide.tga"` (vía `Craft.mediaPath`) |

### Layout del atlas (supersampled — un solo atlas)

| Resolución TGA | Grid | Celda | Icono renderizado | Gutter | Fórmula UV (col/row base-0) |
|---|---|---|---|---|---|
| 512×512 px | 8×8 (64 slots) | 64px | 56px centrado | 4px transparente | `left=col/8, right=(col+1)/8, top=row/8, bottom=(row+1)/8` |

**Supersampling**: cada ícono se rasteriza a 56px y se centra en una celda de 64px con
4px de gutter transparente. WoW lo reduce al tamaño de display (16/24/…) en runtime. Como
WoW nunca muestra texturas 1:1 (la UI escala con UIScale/DPI), una sola fuente de alta
resolución se ve nítida a cualquier escala — donde los atlas pixel-exactos de 16/24px se
veían borrosos/pixelados. El gutter + un inset de medio texel en `Get()` evitan que el
filtrado bilineal "sangre" celdas vecinas al reducir.

### Formato del descriptor retornado por `Get()`

```lua
{
  path   = "Interface\\AddOns\\Craft\\media\\lucide.tga",
  size   = 16,       -- tamaño de DISPLAY pedido (16, 24, … — el atlas es agnóstico)
  left   = 0.0012,   -- UV normalizadas [0–1], con inset de medio texel
  right  = 0.1238,   -- ≈ 1/8 para col=0
  top    = 0.0012,
  bottom = 0.1238,
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

**Total**: 24 íconos. Ocupan 3 filas del grid 8×8 (24 de 64 slots disponibles).

---

## API pública

| Función | Firma | Descripción |
|---------|-------|-------------|
| `Craft.Icons.Get(name, size?)` | `(string, number?) → table\|nil` | Descriptor UV o nil si no existe. `size` = tamaño de display en px (default 16); el atlas es agnóstico al tamaño. |
| `Craft.Icons.Apply(tex, name, size?)` | `(Texture, string, number?) → void` | Aplica ícono a una Texture al tamaño de display. No-op si name=nil o no existe. |
| `Craft.Icons.Has(name)` | `(string) → bool` | true si el nombre existe en `_atlas`. |
| `Craft.Icons.List()` | `() → string[]` | Array de todos los nombres disponibles, orden alfabético. |

---

## Ejemplos de uso

### Forma recomendada — `Apply`

```lua
local tex = frame:CreateTexture(nil, "ARTWORK")
tex:SetSize(16, 16)
tex:SetPoint("LEFT", frame, "LEFT", 8, 0)
Craft.Icons.Apply(tex, "chevron-right")        -- display 16px por defecto
Craft.Icons.Apply(tex, "settings", 24)         -- display 24px (misma fuente supersampled)
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

**Un solo atlas supersampled**: `_atlas` es la única tabla. El `size` de `Get()`/`Apply()`
es el tamaño de display — no selecciona un atlas distinto. La misma fuente de 64px sirve
cualquier tamaño porque WoW la reduce con filtrado bilineal.

**Por qué supersampling**: WoW escala la UI con UIScale/DPI, así que una textura "de 16px"
casi nunca se muestra a 16 píxeles físicos. Un atlas pixel-exacto se magnifica → blur/pixelado
y los trazos finos de Lucide (stroke 2 en viewBox 24) se ven delgados a 16px. Renderizar a
alta resolución y dejar que WoW reduzca mantiene el ícono nítido a cualquier escala.

**SetTexCoord — orden WoW**: `SetTexCoord(left, right, top, bottom)`. No el orden CSS.

**Colorización**: `SetVertexColor(r, g, b, a)` después de `Apply()`. El módulo no aplica color.

**Performance**: `_atlas` se carga una sola vez. `Get()` es O(1). No cachear el descriptor
retornado (es una tabla nueva cada llamada) — si se necesita varias veces, guardar en local.

**Generación del atlas**: `scripts/export-icons.py` toma los SVGs de Lucide por nombre
canónico, los rasteriza a 56px y los empaqueta centrados en celdas de 64px (gutter de 4px) en
un solo TGA `lucide.tga` + `icons/Atlas.lua`. No editar `Atlas.lua` manualmente — se
sobreescribe en cada release. CI lo genera con `cairosvg` (curvas reales); el fallback local
`pycairo` aproxima curvas con 64 segmentos (suficiente tras el downscale).

**Íconos del sistema**: los 8 íconos requeridos por componentes ocupan la fila 0 (col 0–7),
coordenadas UV predecibles.
