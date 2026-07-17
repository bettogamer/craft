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
├── _atlas   (table)   — mapa nombre→{col,row} (de icons/Atlas.lua)
├── _aliases (table)   — nombres Lucide deprecados → canónico (de icons/Atlas.lua)
├── _div     (number)  — columnas del grid (de icons/Atlas.lua)
├── _rows    (number)  — filas del grid (de icons/Atlas.lua — atlas no cuadrado)
├── _lucide  (string)  — release de Lucide pinneado del que se generó el atlas
├── Get(name, size?)
├── Apply(texture, name, size?)
├── Has(name)
└── List()
```

`icons/Atlas.lua` declara la tabla `_atlas` con coordenadas de celda (col/row, base-0), `_aliases` y los divisores. Se carga antes que cualquier componente en `Craft.toc`. `Craft.Icons` construye los descriptores UV en runtime; `Get`/`Has`/`Apply` resuelven aliases deprecados al nombre canónico automáticamente.

### Ruta del atlas

| Ruta |
|------|
| `"Interface\\AddOns\\Craft\\media\\lucide.tga"` (vía `Craft.mediaPath`) |

### Layout del atlas (supersampled — un solo atlas, set Lucide completo)

| Resolución TGA | Grid | Celda | Icono renderizado | Gutter | Fórmula UV (col/row base-0) |
|---|---|---|---|---|---|
| 2048×4096 px | 32×64 (2048 slots) | 64px | 56px centrado | 4px transparente | `left=col/32, right=(col+1)/32, top=row/64, bottom=(row+1)/64` |

> Historia: 512×512 (MVP) → 512×1024 (FR-022, catálogo curado) → **2048×4096 (ADR-0016,
> set Lucide completo)**. Potencia-de-2 por lado (requisito de WoW); los divisores UV por
> eje viven en `Atlas.lua` (`_div`/`_rows`). La celda, el supersampling y el gutter no
> cambiaron en ningún salto — la calidad por icono es idéntica, solo hay más celdas.
> El TGA se guarda con compresión **RLE** (sin pérdida, ~4.2 MB vs 32 MB sin comprimir).

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
  left   = 0.0002,   -- UV normalizadas [0–1], con inset de medio texel
  right  = 0.0310,   -- ≈ 1/32 para col=0 (eje X divide entre 32 columnas)
  top    = 0.0001,
  bottom = 0.0155,   -- ≈ 1/64 para row=0 (eje Y divide entre 64 filas — atlas no cuadrado)
}
```

---

## Catálogo de íconos — set Lucide completo (ADR-0016)

> Desde **ADR-0016** el atlas contiene **todo el set de Lucide** de un release pinneado, no
> un catálogo curado por FR. Cualquier nombre canónico de [lucide.dev](https://lucide.dev)
> funciona en `Get`/`Apply`/`Has` — y los nombres deprecados resuelven vía aliases. Los FRs
> de iconos (FR-004, FR-012, FR-013, FR-017, FR-022, FR-030, FR-031) quedan como registro
> histórico de por qué existía cada icono del catálogo curado; dejan de ser el mecanismo de
> entrada.

| | |
|---|---|
| **Release pinneado** | **Lucide 1.24.0** — constante `LUCIDE_TAG` en `scripts/export-icons.py` |
| Íconos canónicos | 1747 (1746 de Lucide + 1 Craft-sintetizado: `disc`) |
| Aliases deprecados | 249 (`filter`→`funnel`, `bar-chart-3`→`chart-column`, …) |
| Slots libres | ~300 de 2048 (crecimiento de upstream sin cambiar el layout) |

> **Bump del pin** (sync con upstream, 1–2×/año): editar `LUCIDE_TAG` en
> `scripts/export-icons.py`, regenerar, y actualizar la versión en la tabla de arriba —
> el hash de ESTE archivo es la key del cache `.icon-cache` en CI, así el cache se
> invalida solo cuando cambia el pin documentado.

### Sistema — usados por Craft internamente (fila 0, cols 0–7)

Estos íconos son requeridos por los propios componentes de la librería y conservan
posición fija en la fila 0 del grid. Sin ellos, algunos componentes no renderizan
correctamente (el spec `tests/icons_spec.lua` lo garantiza).

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

El resto del set va **alfabético** a partir de la col 8 de la fila 0. Las coordenadas
concretas no son contrato — la API es por nombre; `Atlas.lua` se regenera entero en
cada release.

### Glyphs Craft-sintetizados (no Lucide)

| Nombre | Uso | Por qué no es Lucide |
|---|---|---|
| `disc` | Círculo relleno para controles redondos (RadioGroup) | Lucide es stroke-only, sin formas rellenas. Definido inline en `scripts/export-icons.py` (`LOCAL_SVGS`) y rasterizado por el mismo pipeline supersampleado |

### Aliases deprecados

Lucide renombra íconos entre releases (`filter`→`funnel`, `alert-triangle`→`triangle-alert`,
`bar-chart-3`→`chart-column`…). El generador emite `Craft.Icons._aliases` desde la metadata
JSON de upstream y `Get`/`Has`/`Apply` resuelven el alias al canónico automáticamente:
`Apply(tex, "filter")` pinta `funnel`. `List()` devuelve **solo canónicos**. En código nuevo
usar siempre el nombre canónico; los aliases existen para no romper consumers cuando
upstream renombra.

---

## API pública

| Función | Firma | Descripción |
|---------|-------|-------------|
| `Craft.Icons.Get(name, size?)` | `(string, number?) → table\|nil` | Descriptor UV o nil si no existe. `size` = tamaño de display en px (default 16); el atlas es agnóstico al tamaño. |
| `Craft.Icons.Apply(tex, name, size?)` | `(Texture, string, number?) → void` | Aplica ícono a una Texture al tamaño de display. No-op si name=nil o no existe. |
| `Craft.Icons.Has(name)` | `(string) → bool` | true si el nombre existe en `_atlas` o resuelve vía `_aliases`. |
| `Craft.Icons.List()` | `() → string[]` | Array de todos los nombres canónicos (sin aliases), orden alfabético. |

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

**Nombres canónicos vs. aliases**: los nombres deprecados de Lucide (`alert-triangle`,
`check-circle`, `filter`, `bar-chart-3`, …) resuelven automáticamente vía `_aliases`
(ADR-0016) — pero en código nuevo usar siempre el canónico actual de lucide.dev.

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

**Generación del atlas**: `scripts/export-icons.py` descarga el tarball del release
pinneado de Lucide (`LUCIDE_TAG`, un request de ~3 MB), enumera TODOS los SVGs, los
rasteriza a 56px y los empaqueta centrados en celdas de 64px (gutter de 4px) en un solo
TGA `lucide.tga` (RLE, sin pérdida; `--no-rle` como plan B) + `icons/Atlas.lua` (con
`_aliases` desde la metadata JSON de upstream). No editar `Atlas.lua` manualmente — se
sobreescribe en cada release. CI lo genera con `cairosvg` (curvas reales); el fallback
local `pycairo` aproxima curvas con 64 segmentos (suficiente tras el downscale) y soporta
todos los elementos que usa el set (`path`, `circle`, `ellipse`, `rect` con `rx`/`ry`,
`line`, `polyline`, `polygon`). El spec `tests/icons_spec.lua` es el gate del output.

**Íconos del sistema**: los 8 íconos requeridos por componentes ocupan la fila 0 (col 0–7),
coordenadas UV predecibles.
