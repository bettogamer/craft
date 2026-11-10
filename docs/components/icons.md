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
├── _densities (table) — un atlas por densidad, de menor a mayor (FR-137)
├── Get(name, size?, scale?)
├── Apply(texture, name, size?)
├── Refresh(root?, scaleMul?)   — FR-139
├── Has(name)
└── List()
```

`icons/Atlas.lua` declara la tabla `_atlas` con coordenadas de celda (col/row, base-0), `_aliases` y los divisores. Se carga antes que cualquier componente en `Craft.toc`. `Craft.Icons` construye los descriptores UV en runtime; `Get`/`Has`/`Apply` resuelven aliases deprecados al nombre canónico automáticamente.

### Rutas de los atlas (FR-137 — tres densidades)

| Archivo (vía `Craft.mediaPath`) | Resolución | Celda | Glyph | Gutter |
|---|---|---|---|---|
| `lucide-16.tga` | 512×1024 | 16px | 14px | 1px |
| `lucide-32.tga` | 1024×2048 | 32px | 28px | 2px |
| `lucide.tga` | 2048×4096 | 64px | 56px | 4px |

Los tres comparten la **misma rejilla** 32×64 (`_div`/`_rows`), así que `_atlas` (col/row) es
único: solo cambian la ruta y el tamaño de celda. Fórmula UV (col/row base-0):
`left = col/32 + G`, `right = (col+1)/32 − G` (ídem filas con `/64`), con
`G = gutter / (32·celda)` (`/64` en Y) — el recorte es **exactamente el gutter**.

> Historia: 512×512 (MVP) → 512×1024 (FR-022, catálogo curado) → 2048×4096 (ADR-0016, set
> Lucide completo) → **tres densidades (FR-137)**. Potencia-de-2 por lado (requisito de WoW).
> TGA con compresión **RLE** (sin pérdida): 1.0 + 2.5 + 5.3 MB en disco; en VRAM
> 2 + 8 + 32 MB (los dos nuevos suman el 31 % del original).

**Selección de densidad (FR-137)**: `Get`/`Apply` calculan los **píxeles físicos** que va a
ocupar el icono — `size × escala efectiva ÷ factor de píxel` (factor = `768 / alto físico`,
el mismo de `PixelUtil` y `Craft.Theme.px`) — y eligen el atlas **más pequeño cuyo glyph los
cubre**. Así la GPU solo reduce, y siempre por menos de 2×. Ejemplos: 12px a escala 1.0 en
pantalla de 768 → 12 físicos → atlas de 14; 12px a 0.64 en 1440p → 14.4 → atlas de 28.

Por qué: con un solo atlas de 56px, un icono de 10-14px se reducía 4-6× y los trazos de
Lucide salían rotos/pixelados (Coffer, FR-137): el muestreo bilineal se salta texels y la
cadena de mips no lo salvaba en la práctica. Y volver a lo de antes tampoco valía: los
antiguos atlas pixel-exactos de 16/24px se elegían por **unidades de UI**, y a casi cualquier
UIScale WoW los **ampliaba** → borrosos. Elegir por píxeles físicos evita las dos cosas.

`Apply` toma la escala efectiva de la textura (o de su padre) **en el momento de la
llamada**; los componentes re-aplican en `_applyTheme`. **Cambios de escala posteriores
(FR-139):** `Apply` registra cada textura (tabla débil `_applied`: nombre, tamaño, densidad,
ruta) y `Refresh(root?, scaleMul?)` vuelve a elegir la densidad de las registradas (todas o
las que cuelgan de `root`), cambiando solo archivo + UV de las que deban subir o bajar de
atlas. Craft lo llama en `UI_SCALE_CHANGED`/`DISPLAY_SIZE_CHANGED` (diferido un fotograma) y
desde `Window:SetBaseScale` (con `scaleMul = 1/zoom` para no elegir una densidad transitoria
a mitad del pop); un consumidor que escala un antecesor por su cuenta (`host:SetScale`) llama
`Craft.Icons.Refresh(host)` después. Nunca por fotograma. Una textura cuyo archivo ya no es
el que puso `Apply` (reutilizada, o `SetTexture(nil)`) sale del registro sin tocarse. `Get` sin `scale` usa la
de `UIParent` (lo correcto para `|T…|t` en tooltips y menús).

**Rasterizado**: cada icono se rasteriza UNA vez a 224px y se reduce por promedio de área
(box, factor entero 4/8/16) a 56/28/14px. Solo se reduce el alfa (cobertura); el RGB se
fuerza a blanco — promediar RGB recto metería el negro de los píxeles transparentes en los
bordes (halo oscuro al teñir).

**El UV recorta el gutter (FR-057)**: `Get()` no muestrea la celda entera sino el glyph;
si no, se dibujaría a `size × glyph/celda` (87.5 %). Desde FR-137 el recorte es el gutter
**exacto**, sin el medio texel extra de antes: el gutter es transparente, así que el bilineal
puede tocarlo; solo no debe llegar a la celda vecina, y con ≥1px de gutter no llega. Medio
texel extra en el glyph de 14px era un zoom del 7 % y rompía el mapeo 1:1. El footprint
(`SetSize(size)`) no cambia: ningún ancla ni gap se mueve.

**Filtrado `TRILINEAR` (mipmaps)**: `Apply()` pasa `SetTexture(path, "CLAMP", "CLAMP",
"TRILINEAR")` (archivos propios POT — bug #6). Las celdas caen en fronteras potencia-de-2,
así que un nivel de mip nunca mezcla dos celdas mientras la celda mida ≥1 texel, y con la
reducción < 2× que garantiza la selección se usan los mips 0-1. La página Icons del
Craft_Browser compara el atlas de 56 con `TRILINEAR` y con `LINEAR` para comprobar si el
cliente genera mips para un TGA de addon (si salen idénticos, no los genera).

### Formato del descriptor retornado por `Get()`

```lua
{
  path    = "Interface\\AddOns\\Craft\\media\\lucide-16.tga",  -- la densidad elegida
  size    = 12,       -- tamaño de DISPLAY pedido (siempre el pedido)
  density = 16,       -- celda del atlas elegido (16/32/64), informativo
  left    = 0.0020,   -- UV normalizadas [0–1], recortando el gutter
  right   = 0.0293,
  top     = 0.0010,
  bottom  = 0.0146,
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
| Íconos canónicos | 1748 (1746 de Lucide + 2 Craft-sintetizados: `disc`, `resize-corner`) |
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
| `resize-corner` | Grip de resize abajo-derecha (`Craft.Window`) | Lucide no tiene glifo de corner-grip: su familia `grip*` es la rejilla de puntos de *arrastrar para reordenar* (`Craft.DragList`) y `move-diagonal*` son flechas ↖↘ que se leen como "expandir/pantalla completa". Tres trazos de longitud decreciente paralelos a la esquina, perpendiculares al eje NW-SE del resize (convención de escritorio). `stroke-width="2"` en el viewBox 24×24 para heredar `ICON_STROKE_WIDTH` como el resto |

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
| `Craft.Icons.Get(name, size?, scale?)` | `(string, number?, number?) → table\|nil` | Descriptor UV o nil si no existe. `size` = tamaño de display del **glyph** en unidades de UI (default 16; el UV recorta el gutter, FR-057). `scale` = escala efectiva donde se va a pintar (default la de `UIParent`); solo elige la densidad del atlas (FR-137). |
| `Craft.Icons.Apply(tex, name, size?)` | `(Texture, string, number?) → void` | Aplica ícono a una Texture al tamaño de display, con la densidad que pide la escala efectiva de la textura (FR-137). No-op si name=nil o no existe. |
| `Craft.Icons.Refresh(root?, scaleMul?)` | `(Frame?, number?) → number` | FR-139: re-elige la densidad de los íconos aplicados con `Apply` (todos, o los que cuelgan de `root`) tras un cambio de escala; devuelve cuántos cambiaron de atlas. `scaleMul` multiplica la escala medida (Window pasa `1/zoom`). |
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
Craft.Icons.Apply(tex, "settings", 24)         -- display 24px (atlas elegido por px físicos)
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
-- Pasar la escala efectiva del destino para que elija bien la densidad (FR-137)
local icon = Craft.Icons.Get("circle-check", 16, tex:GetEffectiveScale())
if icon then
    tex:SetTexture(icon.path, "CLAMP", "CLAMP", "TRILINEAR")  -- mipmapped downscale
    tex:SetTexCoord(icon.left, icon.right, icon.top, icon.bottom)
    tex:SetSize(icon.size, icon.size)
end
```

---

## Implementación interna de `Apply`

```lua
function Craft.Icons.Apply(texture, name, size)
    if not name then return end
    size = size or 16
    local scale = effectiveScale(texture) or effectiveScale(texture:GetParent())  -- pcall + issecretvalue
    local desc = Craft.Icons.Get(name, size, scale)   -- elige densidad (FR-137)
    if not desc then return end
    texture:SetTexture(desc.path, "CLAMP", "CLAMP", "TRILINEAR")
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

**Un catálogo, tres densidades (FR-137)**: `_atlas` es la única tabla de coordenadas; el
`size` de `Get()`/`Apply()` es el tamaño de display, y junto con la escala efectiva elige
cuál de los tres TGA se muestrea (ver "Selección de densidad" arriba).

**Peso del trazo (`ICON_STROKE_WIDTH`)**: Lucide es `stroke-width="2"` en el viewBox 24.
El atlas se hornea un pelín más grueso (**2.25**) para compensar el adelgazamiento que el
filtrado con mipmaps (`TRILINEAR`, ver arriba) aplica al line-art fino al minificar → así un
ícono a 24px lee como un 2px sólido. Es una **decisión deliberada de legibilidad** (owner),
una pequeña desviación de la fidelidad shadcn 1:1; ajustar contra el display de 24px, o poner
`2` para Lucide pixel-exacto. Se aplica en `prepare_svg` reemplazando solo `stroke-width="2"`
(los glifos locales como `disc`, con `stroke-width="0"`, quedan intactos).

**SetTexCoord — orden WoW**: `SetTexCoord(left, right, top, bottom)`. No el orden CSS.

**Colorización**: `SetVertexColor(r, g, b, a)` después de `Apply()`. El módulo no aplica color.

**Performance**: `_atlas` se carga una sola vez. `Get()` es O(1). No cachear el descriptor
retornado (es una tabla nueva cada llamada) — si se necesita varias veces, guardar en local.

**Generación del atlas**: `scripts/export-icons.py` descarga el tarball del release
pinneado de Lucide (`LUCIDE_TAG`, un request de ~3 MB), enumera TODOS los SVGs, los
rasteriza a 224px, los reduce por área a cada densidad y los empaqueta centrados en tres
TGA de la misma rejilla — `lucide-16.tga`, `lucide-32.tga` y `lucide.tga` (RLE, sin pérdida;
`--no-rle` como plan B) + `icons/Atlas.lua` (con
`_aliases` desde la metadata JSON de upstream). No editar `Atlas.lua` manualmente — se
sobreescribe en cada release. CI lo genera con `cairosvg` (curvas reales); el fallback
local `pycairo` aproxima curvas con 64 segmentos (suficiente tras el downscale) y soporta
todos los elementos que usa el set (`path`, `circle`, `ellipse`, `rect` con `rx`/`ry`,
`line`, `polyline`, `polygon`). El spec `tests/icons_spec.lua` es el gate del output.

**Íconos del sistema**: los 8 íconos requeridos por componentes ocupan la fila 0 (col 0–7),
coordenadas UV predecibles.
