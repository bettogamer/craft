# ADR-0017: Craft.Grid — motor de layout 2D (columnas/filas), hermano de Craft.Flex

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0017 |
| Título | Craft.Grid — motor de layout 2D (columnas/filas), hermano de Craft.Flex |
| Fecha | 18/07/2026 |
| Autor(es) | Betto |
| Estado | **Aceptada** |
| Alcance | Módulo `Craft.Grid` — motor de layout; componentes que necesitan colocación 2D (CardHeader, formularios) |
| Stakeholders consultados | Consumidores que portan `Card`/formularios de shadcn (Coffer, Beacon) |

---

### 1. Contexto

shadcn escribe sus layouts con **Tailwind**, que aplica indistintamente `display:flex` y
`display:grid`. En el `Card` real conviven ambos: la raíz y el footer son flex, pero el
`CardHeader` es **grid** (`grid-cols-[1fr_auto]` cuando hay `CardAction`, con la acción en la 2ª
columna, `row-span-2` y `justify-self-end`).

Craft ya cubre el eje flex (`Craft.Flex`, ADR-0006 — usado en Tabs/Button/Toggle), pero **no
tenía un motor 2D**. Esto abría dos huecos concretos (ver FR-040):

1. **`CardHeader` con `CardAction`** — `grid-cols-[1fr_auto]` con la acción abarcando dos filas
   (title + description) y alineada a la derecha. No se expresa en un flex de un solo eje; es el
   prerrequisito de FR-039.
2. **Colocación 2D de formularios** — hoy los Form Cards emulan a mano (offsets `-y` acumulados y
   anclas `BOTTOMLEFT`/`BOTTOMRIGHT`) el block-flow + rejilla que en la web es gratis.

Sin motor 2D, cualquier `Card` de shadcn con acción de header o layout en rejilla se cae a
`SetPoint` manual con offsets frágiles.

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras | Costo |
|-------------|------|---------|-------|
| A. Seguir con `SetPoint` manual | Cero código nuevo | Frágil, verboso; no expresa `CardAction` 2D; FR-039 sigue bloqueado | Cero |
| B. Extender `Craft.Flex` con un modo grid | Un solo módulo | Contamina el modelo flex (un eje) con conceptos 2D; API confusa | Medio |
| C. **`Craft.Grid` nuevo, hermano de Flex (MVP: fr/auto/px)** | Modelo mental CSS familiar; aditivo; aísla la complejidad 2D; cubre el subconjunto real de shadcn | ~230 líneas Lua; otro módulo que mantener | Bajo-Medio |
| D. Grid completo (areas, auto-flow, minmax, repeat, subgrid) | Paridad CSS total | Sobre-ingeniería para los casos de addon; superficie de bugs enorme | Alto |

---

### 3. Decisión

> **Elegimos la alternativa C: `Craft.Grid` nuevo, hermano de `Craft.Flex`, con un MVP acotado al
> subconjunto que usa shadcn.**

`Craft.Grid` sigue el mismo estilo que Flex: **no crea frames visuales**, solo calcula y aplica
`SetPoint`/`SetSize` sobre frames hijos; mismo contrato de instancia
(`new`/`Add`/`Remove`/`Clear`/`Layout`/`SetConfig`/`GetItems`). Implementación pura Lua 5.1.

**Alcance del MVP** (suficiente para desbloquear el `CardHeader`):

- Tracks por columna/fila con unidades `"<n>fr"` (fracción del espacio libre), `"auto"` (tamaño
  natural del contenido) y `<número>` (px fijos) — el subconjunto que usa shadcn (`[1fr auto]`,
  `[auto auto]`).
- `col`/`row` (1-indexado) + `colSpan`/`rowSpan` por ítem.
- `justifySelf` / `alignSelf` (`start` | `center` | `end` | `stretch`; default CSS `stretch`).
- `gap` uniforme + `rowGap`/`colGap` por separado; `paddingH`/`paddingV`.

**Fuera de alcance del MVP** (documentado como limitación, igual que Flex hizo con wrap):
`grid-template-areas`, auto-placement / `grid-auto-flow`, `minmax()`, `repeat()`, subgrid. Los
tracks `auto` se dimensionan solo con ítems de span 1 en ese track (un ítem que abarca varias
columnas no dimensiona ninguna columna auto).

Criterios decisivos:
1. **Familiaridad**: mismo modelo mental CSS que Flex, sin curva nueva de implementación.
2. **Aditivo**: no toca ningún componente existente; se registra con `Craft.register`
   (build-versioned, colisión LibStub — ver CLAUDE.md §1).
3. **Reusa lecciones de Flex**: `math.floor` en offsets (ADR-0011), `ClearAllPoints` antes de
   `SetPoint`, cache de tamaño natural (`_naturalW`/`_naturalH`) para no encoger/estirar
   acumulativo en resize, guarda `if container:GetWidth() == 0 then return end`.

---

### 4. Consecuencias

#### 4.1 Positivas

- `CardHeader` con `CardAction` (FR-039) es expresable sobre un grid `[1fr auto]` en vez de anclas
  manuales.
- Form Cards y rejillas de campos se vuelven declarativas en vez de aritméticas.
- Cualquier consumidor (Coffer, Beacon) que porte un `Card`/formulario de shadcn tiene un motor 2D.

#### 4.2 Negativas / costos

- ~230 líneas de Lua adicionales.
- El cálculo ocurre en Lua (no nativo); para rejillas muy grandes hay overhead medible.
- El subconjunto MVP deja fuera casos raros de CSS Grid; se documentan como limitaciones conocidas.

#### 4.3 Neutras / observables

- `Craft.Grid.new(container, config)` crea la instancia; `grid:Add(frame, itemConfig)` coloca cada
  hijo en su celda; `grid:Layout()` calcula y aplica posiciones. Sin observación reactiva — el dev
  llama `Layout()` cuando cambian dimensiones (idéntico a Flex).
- `justifySelf`/`alignSelf` por defecto son `"stretch"` (default CSS Grid): el ítem llena su celda.
- `GetContentWidth()`/`GetContentHeight()` exponen la extensión consumida para auto-dimensionar el
  contenedor.

---

### 5. Impacto en el sistema

- **Código**: `Craft/layout/Grid.lua` (~230 líneas). API pública: `Craft.Grid`. Registro en
  `Craft.toc` (tras `layout/Flex.lua`) y en el comentario de submódulos de `Craft.lua`.
- **Tests**: `tests/grid_spec.lua` — tracks fr/auto/px, gap, `CardHeader` (rowSpan + justify/align
  self), guarda de ancho 0, estabilidad en re-layout, `GetContentHeight`.
- **Documentación**: `docs/components/grid.md` con API, algoritmo y limitaciones.
- **Bump de build**: al cortar el release (proceso del maintainer, `bump-build.sh`).

---

### 6. Plan de reversión

- **Señales de problema**: overhead medible en rejillas grandes; bugs de colocación difíciles de
  reproducir.
- **Costo de revertir**: bajo — módulo independiente y aditivo. Los consumidores que lo usen
  migrarían a `SetPoint`/`Flex`; Craft no depende de Grid.

---

### 7. Referencias

- CSS Grid spec: `https://www.w3.org/TR/css-grid-1/`
- ADR-0006 (Craft.Flex — motor hermano), ADR-0011 (pixel-perfect: math.floor en offsets)
- FR-040 (este motor), FR-039 (CardAction en CardHeader — consumidor natural)
- CLAUDE.md §1 (colisión LibStub → `Craft.register` build-versioned)

---

### 8. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 18/07/2026 | Betto | Propuesta y aceptación — Grid MVP (fr/auto/px) hermano de Flex, desbloquea FR-039 |
