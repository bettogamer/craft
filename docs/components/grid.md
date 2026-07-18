# Component: Grid

> Referencia shadcn: N/A (motor de layout CSS Grid adaptado a WoW, `display:grid`) — Módulo Lua puro — opera sobre frames existentes. Hermano de [Flex](flex.md).

## Propósito

Motor de layout **2D** que calcula y aplica posiciones (`SetPoint` / `SetSize`) a frames hijos de un contenedor siguiendo un subconjunto del modelo CSS Grid: tracks de columnas/filas (`fr` / `auto` / px), colocación por celda (`col`/`row`) con span (`colSpan`/`rowSpan`) y alineación por ítem (`justifySelf`/`alignSelf`).

Donde `Craft.Flex` resuelve un eje, `Craft.Grid` resuelve los dos a la vez — necesario para casos como el `CardHeader` de shadcn (`grid-cols-[1fr_auto]` con la acción abarcando dos filas) que **no** se expresa en un flex de un solo eje.

## Arquitectura del módulo

Grid **no crea frames visuales propios**. Es un calculador de geometría: recibe un frame contenedor y frames hijos, y aplica `SetPoint`/`SetSize` sobre ellos. Expone una API de instancia para mantener el estado del layout entre relayouts.

```
Craft.Grid                  (tabla módulo — punto de entrada público)
└── Craft.Grid.new(...)     → grid_instance

grid_instance               (tabla — estado de una rejilla concreta)
├── _container  (Frame)     — frame contenedor de referencia para dimensiones
├── _cfg        (table)     — columns, rows, gap, rowGap, colGap, paddingH, paddingV
└── _items      (table)     — array de ítems en orden de inserción
```

Cada elemento en `_items`:
```lua
{
  frame       = <Frame>,     -- el frame WoW hijo
  col         = 1,           -- columna (1-indexado)
  row         = 1,           -- fila (1-indexado)
  colSpan     = 1,           -- nº de columnas que abarca
  rowSpan     = 1,           -- nº de filas que abarca
  justifySelf = "stretch",   -- alineación horizontal en la celda
  alignSelf   = "stretch",   -- alineación vertical en la celda
  _naturalW   = <px|nil>,    -- ancho natural cacheado en Add() (estabilidad en resize)
  _naturalH   = <px|nil>,    -- alto natural cacheado en Add()
}
```

## Dimensiones / Comportamiento

El layout se calcula con las dimensiones actuales del contenedor en el momento de llamar `grid:Layout()`. No hay observación reactiva — el developer llama `Layout()` cuando el contenedor o los hijos cambian de tamaño (idéntico a Flex).

### Unidades de track (`columns` / `rows`)

| Unidad        | Ejemplo   | Significado                                                        |
|---------------|-----------|--------------------------------------------------------------------|
| `"<n>fr"`     | `"1fr"`, `"2fr"`, `"1.5fr"` | Fracción del espacio libre tras restar tracks fijos/auto. |
| `"auto"`      | `"auto"`  | Tamaño natural del contenido (max de los ítems de span 1 en ese track). |
| `<número>`    | `120`     | Tamaño fijo en px.                                                 |

### Config del contenedor

| Propiedad  | Valores válidos                        | Default    |
|------------|----------------------------------------|------------|
| `columns`  | array de tracks (fr / auto / px)       | `{ "1fr" }` |
| `rows`     | array de tracks (fr / auto / px)       | `{ "auto" }` |
| `gap`      | número (px) — gap uniforme entre tracks | `0`        |
| `rowGap`   | número (px) — override del gap entre filas    | `nil` (usa `gap`) |
| `colGap`   | número (px) — override del gap entre columnas | `nil` (usa `gap`) |
| `paddingH` | número (px) — padding izquierdo y derecho | `0`     |
| `paddingV` | número (px) — padding superior e inferior | `0`     |

### Config por ítem

| Propiedad     | Tipo     | Default     | Descripción                                                    |
|---------------|----------|-------------|----------------------------------------------------------------|
| `col`         | entero ≥ 1 | `1`       | Columna de inicio (1-indexado).                                |
| `row`         | entero ≥ 1 | `1`       | Fila de inicio (1-indexado).                                   |
| `colSpan`     | entero ≥ 1 | `1`       | Columnas que abarca (clamp a los tracks disponibles).          |
| `rowSpan`     | entero ≥ 1 | `1`       | Filas que abarca (clamp a los tracks disponibles).             |
| `justifySelf` | string   | `"stretch"` | Alineación horizontal en la celda: `start` \| `center` \| `end` \| `stretch`. |
| `alignSelf`   | string   | `"stretch"` | Alineación vertical en la celda: `start` \| `center` \| `end` \| `stretch`. |

Con `stretch` (default CSS Grid), el ítem llena su celda (`SetWidth`/`SetHeight` = tamaño de celda). Con `start`/`center`/`end`, el ítem conserva su tamaño natural (cacheado en `Add()`) y se alinea dentro de la celda.

## API pública

| Función                          | Firma                             | Descripción                                                                     |
|----------------------------------|-----------------------------------|---------------------------------------------------------------------------------|
| `Craft.Grid.new(container, cfg)` | `(Frame, table?) → grid_instance` | Crea una instancia grid para `container`. `cfg` opcional (defaults aplicados).  |
| `grid:Add(frame, itemConfig)`    | `(Frame, table?) → item_ref`      | Coloca un frame en la celda `(col,row)`. Retorna el item para modificación. No llama Layout(). |
| `grid:Remove(frame)`             | `(Frame) → void`                  | Elimina el ítem con ese frame. No llama Layout().                               |
| `grid:Layout()`                  | `() → void`                       | Calcula y aplica `SetPoint` (+ `SetSize` para stretch) a todos los ítems.        |
| `grid:SetConfig(cfg)`            | `(table) → void`                  | Merge de `cfg` sobre `_cfg` y llama `Layout()` automáticamente.                 |
| `grid:Clear()`                   | `() → void`                       | Vacía `_items`. No oculta ni destruye los frames.                               |
| `grid:GetItems()`                | `() → table`                      | Copia read-only del array de ítems.                                             |
| `grid:GetContentWidth()`         | `() → number`                     | Ancho total (padding incluido) consumido por el último `Layout()`. `0` hasta correr uno. |
| `grid:GetContentHeight()`        | `() → number`                     | Alto total (padding incluido) consumido por el último `Layout()`. `0` hasta correr uno. |

## Algoritmo de Layout

```
1. Guarda: si container:GetWidth() == 0 → return (contenedor sin dimensionar aún).
2. Calcular disponible por eje:
     availW = cW - paddingH*2 - colGap*(nCols-1)
     availH = cH - paddingV*2 - rowGap*(nRows-1)
3. Resolver tamaños de tracks (columnas y filas):
     px    → tamaño fijo
     auto  → max(_naturalW/_naturalH de los ítems de span 1 en ese track)
     fr    → free * (fr_i / totalFr), con free = max(0, avail - fijos - auto)
4. Prefix-offset de cada track (inicio X/Y, sin padding).
5. Para cada ítem:
     a. Resolver celda: rectángulo (cellX, cellY, cellW, cellH) sumando los tracks
        que abarca col..col+colSpan y row..row+rowSpan (+ gaps internos del span).
     b. Eje horizontal (justifySelf):
          stretch → SetWidth(cellW), x = cellX
          start   → x = cellX
          center  → x = cellX + (cellW - w)/2
          end     → x = cellX + cellW - w   (w = ancho natural)
     c. Eje vertical (alignSelf): análogo con cellH y alto natural.
     d. ClearAllPoints() + SetPoint("TOPLEFT", container, "TOPLEFT",
          math.floor(paddingH + x), -math.floor(paddingV + y))   (ADR-0011)
6. Guardar GetContentWidth()/GetContentHeight() (extensión + padding).
```

## Ejemplos de uso

### `CardHeader` con `CardAction` (el caso que motiva FR-040 → FR-039)

```lua
local grid = Craft.Grid.new(header, {
  columns = { "1fr", "auto" },   -- grid-cols-[1fr_auto]
  rows    = { "auto", "auto" },  -- title + description
  gap     = 8,                   -- gap-2
})

grid:Add(titleFrame,  { col = 1, row = 1 })
grid:Add(descFrame,   { col = 1, row = 2 })
grid:Add(actionFrame, { col = 2, row = 1, rowSpan = 2,   -- row-span-2
                        justifySelf = "end",             -- justify-self-end
                        alignSelf   = "start" })          -- self-start
grid:Layout()
```

### Rejilla de campos de formulario

```lua
local grid = Craft.Grid.new(content, {
  columns = { "auto", "1fr" },   -- label | control
  rows    = { "auto", "auto", "auto" },
  rowGap  = 12,
  colGap  = 8,
})

grid:Add(label1:GetFrame(),   { col = 1, row = 1, alignSelf = "center", justifySelf = "start" })
grid:Add(input1:GetFrame(),   { col = 2, row = 1 })  -- stretch: llena la columna 1fr
grid:Add(label2:GetFrame(),   { col = 1, row = 2, alignSelf = "center", justifySelf = "start" })
grid:Add(input2:GetFrame(),   { col = 2, row = 2 })
grid:Layout()
```

### Auto-relayout al resize del contenedor

```lua
container:HookScript("OnSizeChanged", function() grid:Layout() end)
```

## Notas de implementación

**ClearAllPoints antes de SetPoint**: cada `Layout()` llama `frame:ClearAllPoints()` en cada ítem antes de `SetPoint` para evitar anclajes en conflicto (misma regla que Flex).

**math.floor() en offsets (ADR-0011)**: los tracks `fr` producen valores fraccionarios (p. ej. `95.5`) que causan sub-pixel blending. Los offsets `x`/`y` se redondean con `math.floor()` antes de `SetPoint`.

**`_naturalW` / `_naturalH` — estabilidad en re-layout**: con `justifySelf`/`alignSelf` = `stretch`, `Layout()` hace `SetWidth`/`SetHeight` = tamaño de celda. Releer ese tamaño en el siguiente `Layout()` (p. ej. durante drag de ventana) encogería/estiraría acumulativamente. Igual que `Flex._naturalBasis`, Grid **cachea el tamaño natural en `Add()`** (antes de cualquier `Layout()`) y lo usa para dimensionar tracks `auto` y para posicionar ítems no-stretch. Si el contenido de un frame cambia de tamaño tras el `Add()`, re-agregarlo para refrescar la base.

**Guarda de ancho 0**: `container:GetWidth()` retorna 0 si el frame no está dimensionado aún; `Layout()` hace `return` temprano en ese caso (no posiciona nada) — evita layout en tamaño cero.

**Tracks `auto` y span**: un track `auto` se dimensiona solo con los ítems que **no** hacen span en ese eje (`colSpan`/`rowSpan == 1`). Un ítem que abarca varias columnas no dimensiona ninguna columna `auto`. Es suficiente para los casos de shadcn (la acción del `CardHeader` hace span en filas, no en columnas).

## Limitaciones conocidas (fuera del MVP)

Documentadas explícitamente, igual que Flex documentó `align-content` en wrap:

- **`grid-template-areas`** — no hay áreas con nombre; la colocación es por `col`/`row` numéricos.
- **Auto-placement / `grid-auto-flow`** — cada ítem declara su celda; no hay flujo automático.
- **`minmax()`, `repeat()`** — no soportados; enumerar los tracks explícitamente.
- **Subgrid** — no soportado.
- **Alineación de la rejilla completa** (`justify-content`/`align-content` a nivel de contenedor) — no soportada; usar `paddingH`/`paddingV` y tracks `fr` para distribuir espacio.
