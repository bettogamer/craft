# ADR-0016: Atlas Lucide completo — import total del set en vez de catálogo curado por FR

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0016 |
| Título | Atlas Lucide completo — import total del set en vez de catálogo curado por FR |
| Fecha | 16/07/2026 |
| Autor(es) | bettogamer |
| Estado | **Aceptada** |
| Alcance | `scripts/export-icons.py`, `Craft/icons/Atlas.lua`, `Craft/icons/Icons.lua`, `media/lucide.tga`, `docs/components/icons.md` |
| Supersede | ADR-0003 (parcial): reemplaza el modelo de catálogo curado (~50 íconos) por el set Lucide completo |
| Relacionado | ADR-0003 (Lucide first-class), ADR-0009 (CI genera el atlas), ADR-0010 (versioning), FR-031 (última petición de icono individual) |

---

### 1. Contexto

Desde el MVP, el atlas de íconos se pobló con un **catálogo curado**: 8 íconos de sistema
(requeridos por componentes) + un set de conveniencia + adiciones puntuales pedidas por
consumers vía FR (FR-004, FR-012, FR-013, FR-017, FR-022, FR-030, FR-031…). A julio 2026 el
atlas tiene 64 glyphs y **cada icono nuevo cuesta un ciclo completo**: FR en el consumidor →
priorización → edición del catálogo → regeneración → bump de build → release → re-vendoreo.
FR-031 (`brush-cleaning`, una celda) es el ejemplo terminal: un release entero para un icono.

Mientras tanto el consumidor trabaja con un fallback semánticamente incorrecto (p. ej. una
flecha de orden donde va una escoba), y la clase de FRs "añadir icono X" no tiene fin previsible:
Lucide tiene **1747 íconos** (release 1.24.0) y crece semanalmente.

Datos medidos (2026-07-16, sobre Lucide `main`/1.24.0):

- 1747 SVGs; todos usan solo `path`, `circle`, `rect`, `line`, `ellipse`, `polyline`, `polygon`.
- 238 íconos declaran **aliases deprecados** en su metadata JSON (`filter`→`funnel`,
  `bar-chart-3`→`chart-column`) — fuente recurrente de confusión en consumers.
- TGA-RLE (sin pérdida) medido sobre el atlas actual: **ratio 7.3%** (2 MB → 149 KB). El
  line-art sobre fondo transparente comprime extremadamente bien.

Las fuerzas en tensión:

- **Cadencia de releases** (un release por icono no escala) vs. **tamaño del asset** (el set
  completo multiplica el atlas ×16 en celdas).
- **Curaduría** (catálogo pequeño, documentable icono a icono) vs. **cobertura** (cualquier
  icono disponible sin fricción, como en la web con lucide npm).
- **VRAM/disco** (32 MB RGBA descomprimido en GPU; ~4–5 MB estimados en disco con RLE) vs.
  **coste de proceso** (FRs, releases, re-vendoreos, fallbacks temporales en consumers).

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras | Costo aproximado |
|-------------|------|---------|------------------|
| A. Import total en un atlas único 2048×4096 (elegida) | Elimina la clase entera de FRs de iconos; cualquier `Apply(name)` funciona; pipeline casi sin cambios (`Icons.lua` intacto en API); sync con upstream 1–2×/año | 32 MB VRAM residentes al primer uso; ~4–5 MB en disco (RLE) por copia vendoreada; requiere verificar TGA-RLE in-game | Bajo — cambios concentrados en `export-icons.py` |
| B. Import total multi-página (7×1024×1024, carga bajo demanda) | VRAM proporcional a páginas usadas | Complica `Icons.lua` (página en `_atlas`, N rutas); el ahorro es especulativo: el uso alfabético se dispersa entre páginas; más archivos en `media/` | Medio |
| C. Catálogo curado ampliado (~300 íconos "probables") | Atlas moderado (512×2048) | No resuelve el problema de raíz: el icono 301 vuelve a costar un release; curar 300 es arbitrario | Bajo, pero recurrente |
| D. Status quo (FR por icono) | Cero cambio | FR-031 y sucesores para siempre; fallbacks incorrectos en consumers entre releases | Cero hoy, alto acumulado |

---

### 3. Decisión

> **Elegimos la alternativa A: importar el set Lucide completo (release pinneado) en un único
> atlas supersampleado 2048×4096, generado desde el tarball oficial, con tabla de aliases.**

Concretamente:

1. **Catálogo = enumeración del tarball** de un release pinneado de Lucide
   (`github.com/lucide-icons/lucide/archive/refs/tags/<TAG>.tar.gz`), no una lista manual.
   La constante `LUCIDE_TAG` vive en `scripts/export-icons.py`; la versión pinneada se
   registra en `Atlas.lua` (header + `Craft.Icons._lucide`) y en `docs/components/icons.md`
   (cuyo hash es la key del cache de CI — el cache se invalida solo al bumpear el pin).
2. **Layout sin cambio de calidad**: celdas de 64 px (icono 56 px + gutter 4 px,
   supersampleado idéntico al actual) en un grid **32×64 = 2048 slots** (2048×4096 px,
   potencia-de-2 por lado). 1748 usados (1747 Lucide + `disc` sintetizado), ~300 libres para
   crecimiento de upstream. Los 8 íconos de sistema conservan la fila 0, cols 0–7; el resto
   va alfabético.
3. **TGA con compresión RLE** (sin pérdida, ratio medido 7.3%). Flag `--no-rle` como plan B
   si el cliente no la aceptara (ver §7 Validación).
4. **Tabla de aliases**: `Atlas.lua` genera `Craft.Icons._aliases` desde la metadata JSON de
   Lucide; `Icons.Get/Has/Apply` resuelven nombres deprecados al canónico. `List()` sigue
   devolviendo solo canónicos.
5. **Rasterizador**: CI sigue con cairosvg (curvas reales). El fallback local pycairo se
   extiende con `<ellipse>` (15 íconos) y `<rect rx=…>` redondeado (319 íconos), que el set
   completo sí usa y el catálogo curado no ejercitaba.

Los criterios decisivos:

1. **Coste de proceso > coste de bytes**: cada FR de icono cuesta release + re-vendoreo en
   N consumers; 30 MB de VRAM en un cliente de 2026 (WoW usa GBs en texturas) no justifica
   ese ciclo.
2. **La calidad no cambia**: la celda, el supersampling, el filtrado y el inset de medio
   texel son idénticos; solo hay más celdas. RLE es lossless.
3. **`Icons.lua` ya era paramétrico** (`_div`/`_rows` vienen de `Atlas.lua`): el import total
   no toca la API pública ni los componentes.
4. **Paridad con el ecosistema web**: quien usa shadcn+lucide en web espera poder usar
   cualquier nombre de Lucide; Craft ofrece lo mismo.

---

### 4. Consecuencias

#### 4.1 Positivas

- **Se elimina la clase entera de FRs "añadir icono"** — FR-031 se cierra con este ADR y no
  habrá FR-032 de iconos. El flujo pasa a ser: sync del pin con upstream 1–2 veces al año.
- Cualquier `Craft.Icons.Apply(tex, "<nombre-lucide>")` funciona, incluidos nombres
  deprecados vía aliases.
- El generador deja de tener una lista manual que mantener (la fuente de verdad es el tarball
  pinneado — reproducible bit a bit para un mismo tag).
- Los consumers ya no shippean fallbacks semánticos temporales.

#### 4.2 Negativas / costos

- **VRAM**: el atlas completo son 32 MB RGBA descomprimidos, residentes desde el primer
  `SetTexture`. Aceptado explícitamente (equivale a unas pocas texturas 2048² de mapas).
- **Disco**: ~4–5 MB (RLE) por copia vendoreada de Craft, frente a 149 KB equivalentes hoy.
  Sin RLE serían 32 MB — de ahí que la validación in-game de RLE sea bloqueante (§7).
- **Primer uso**: la carga de la textura es más pesada (una vez por sesión); WoW la hace
  async y no se ha observado hitch con texturas de este tamaño, pero se verifica in-game.
- Todas las coordenadas (col,row) existentes cambian (CPR pasa de 8 a 32). Irrelevante para
  consumers (la API es por nombre), pero **TGA + `Atlas.lua` deben viajar atómicos** con bump
  de build — el proceso existente ya lo garantiza (`_buildOwner`, lección FR-030: TGA
  cambiado = reinicio completo del cliente para verificar).
- La página de íconos de Craft_Browser lista ahora 1747 entradas → necesitará búsqueda/
  paginación (cosmético, tracked aparte; no bloquea este ADR).

#### 4.3 Neutras / observables

- `Atlas.lua` crece a ~1750 entradas + ~240 aliases (~80 KB de Lua, memoria despreciable;
  las copias embebidas perdedoras del registro versionado se descartan al GC como hoy).
- `docs/components/icons.md` deja de tablar icono por icono: documenta el modelo (set
  completo pinneado + aliases) y solo tabla los 8 de sistema.
- El historial de FRs de iconos (FR-004…FR-031) queda como registro de *por qué* existían
  esos íconos; deja de ser el mecanismo de entrada.

---

### 5. Impacto en el sistema

- **`scripts/export-icons.py`**: catálogo desde tarball pinneado (`LUCIDE_TAG`); atlas
  2048×4096 (CPR=32, ROWS=64); parser de aliases desde los JSON de metadata; fallback pycairo
  con `ellipse` + rounded-rect; save TGA con `compression="tga_rle"` (+ `--no-rle`).
- **`Craft/icons/Atlas.lua`** (generado): ~1750 entradas, `_aliases`, `_lucide` (tag pinneado),
  `_div=32`, `_rows=64`.
- **`Craft/icons/Icons.lua`**: resolución de aliases en `Get`/`Has` (fallback a `_aliases`);
  sin cambio de API pública. El cálculo de insets ya era paramétrico.
- **CI** (sin editar workflows): `pip install Pillow cairosvg` ya presente; el cache de
  `.icon-cache` se invalida vía el hash de `icons.md` al bumpear el pin. El tarball (2.9 MB)
  se descarga una vez por cache-miss.
- **Tests**: `tests/icons_spec.lua` nuevo — gate del output del generador (sistema en fila 0,
  UVs en [0,1], aliases resuelven, `List()` ≥ 1700, `Has` de nombres canónicos clave).
- **Consumers**: re-vendoreo normal tras el release; ningún cambio de código (los nombres ya
  en uso siguen funcionando, ahora también sus aliases).

---

### 6. Plan de reversión

- **Señales de problema**: el cliente no lee TGA-RLE (→ plan B inmediato: `--no-rle`, 32 MB
  en disco, evaluar BLP/DXT5 con verificación visual de trazos finos); hitch perceptible en
  el primer uso; presión de memoria reportada en clientes modestos.
- **Costo de revertir**: bajo — `export-icons.py` conserva la mecánica de catálogo; volver al
  modelo curado es recortar la enumeración a una lista y regenerar (los consumers que ya usen
  nombres fuera del catálogo curado deberían migrar, ese es el único lock-in).
- **Plan B intermedio**: alternativa B (multi-página) reutiliza todo el pipeline de este ADR;
  solo re-particiona el TGA y añade la página al descriptor.

---

### 7. Validación

- **Bloqueante pre-release**: in-game (12.0.x, cliente reiniciado): (1) el TGA-RLE renderiza
  (si no → `--no-rle`); (2) spot-check visual de íconos con `ellipse` (`database`), rounded
  rect (`image`) y trazos finos a 16 px; (3) sin hitch perceptible al primer icono.
- **Métrica**: `Craft.Icons.Has(name)` = true para los 1747 nombres canónicos del tag
  pinneado; `Get("filter")` ≡ `Get("funnel")`.
- **Tamaño**: `lucide.tga` ≤ 6 MB con RLE; `Craft.zip` ≤ 10 MB.
- **Responsable**: bettogamer.
- **Plazo**: próximo release MINOR tras este ADR.

---

### 8. Referencias

- Lucide 1.24.0 (pin inicial): `https://github.com/lucide-icons/lucide/releases/tag/1.24.0` (ISC License)
- Medición RLE y auditoría de elementos SVG: análisis 2026-07-16 (este ADR, §1)
- ADR-0003 (assets bundled), ADR-0009 (CI genera el atlas), ADR-0010 (versioning/build)
- FR-031 (`brush-cleaning`) — última petición individual; se cierra con este ADR
- `docs/components/icons.md` — spec del módulo (layout, API, aliases)

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 16/07/2026 | bettogamer | Versión inicial — import total del set Lucide (1747 íconos, tag 1.24.0), atlas 2048×4096, aliases, TGA-RLE |
