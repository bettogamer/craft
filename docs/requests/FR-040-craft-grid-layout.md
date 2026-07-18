# FR-040 — `Craft.Grid`: motor de layout 2D (columnas/filas), hermano de `Craft.Flex`

**Reportado por:** Análisis de layout de las Form Cards al portar shadcn (Craft_Browser, 2026-07-18)
**Componente:** nuevo módulo `Craft/layout/Grid.lua` (shadcn/Tailwind: `display:grid`)
**Tipo:** Feature (nueva API pública — requiere aprobación del maintainer)
**Prioridad:** Media
**Estado:** ✅ Implementado (dev) — `Craft/layout/Grid.lua`, ADR-0017, `docs/components/grid.md`, `tests/grid_spec.lua` (7 tests) + página demo `Craft_Browser/pages/Grid.lua` (8 ejemplos: CardHeader, columnas iguales, fila de formulario, tracks auto, justifySelf, alignSelf, span, gaps separados). Pendiente: verificación in-game + bump de build + release (maintainer).

---

## Problema

shadcn escribe sus layouts con **Tailwind**, que no es una alternativa a flex/grid sino la
notación con que se aplican ambos. En el `Card` real (`card.tsx` del registry) conviven los dos:

| Parte | display | Clases |
|-------|---------|--------|
| `Card` (raíz)  | **flex**  | `flex flex-col gap-6` |
| `CardHeader`   | **grid**  | `grid grid-rows-[auto_auto] gap-2` + `has-data-[slot=card-action]:grid-cols-[1fr_auto]` |
| `CardContent`  | block     | `px-6` (flujo de bloque normal) |
| `CardFooter`   | **flex**  | `flex items-center px-6` |
| `CardAction`   | ítem grid | `col-start-2 row-span-2 row-start-1 self-start justify-self-end` |

Craft ya cubre el eje flex (`Craft.Flex` — usado en Tabs/Button/Toggle), pero **no tiene un
motor 2D**. Los dos huecos concretos que esto abre:

1. **`CardHeader` con `CardAction`** — es `grid-cols-[1fr_auto]` con la acción en la 2ª columna,
   `row-span-2` y `justify-self-end`. Esto **no se expresa en un flex de un solo eje**: necesita
   dos columnas donde la acción abarca las dos filas (title + description). Es exactamente lo que
   bloquea [FR-039](FR-039-panel-cardaction-header.md).
2. **Colocación 2D de formularios** — hoy el content del Form Card "Payout Threshold" en
   `Craft_Browser/pages/Panel.lua` emula a mano (offsets `-y` acumulados y anclas `BOTTOMLEFT`/
   `BOTTOMRIGHT` en la misma fila) el block-flow + rejilla que en la web es gratis. Un grid lo
   haría declarativo en vez de aritmético.

**Escenario:** portar cualquier `Card` de shadcn con acción de header o layout en rejilla →
no hay motor que exprese columnas/filas; se cae a `SetPoint` manual con offsets frágiles.

## Solución propuesta

Añadir `Craft/layout/Grid.lua`, **hermano de `Flex`** (mismo estilo: no crea frames visuales,
solo calcula y aplica `SetPoint`/`SetSize` sobre frames hijos; mismo contrato de instancia con
`new`/`Add`/`Remove`/`Clear`/`Layout`/`SetConfig`). ADR nuevo (hermano de ADR-0006 de Flex).

API tentativa (a refinar en el ADR):

```lua
local grid = Craft.Grid.new(container, {
  columns = { "1fr", "auto" },   -- grid-template-columns: [1fr auto]
  rows    = { "auto", "auto" },  -- grid-template-rows
  gap     = 8,                   -- gap uniforme; opcional rowGap/colGap por separado
  paddingH = 0, paddingV = 0,
})

grid:Add(titleFrame,  { col = 1, row = 1 })
grid:Add(descFrame,   { col = 1, row = 2 })
grid:Add(actionFrame, { col = 2, row = 1, rowSpan = 2, justifySelf = "end", alignSelf = "start" })
grid:Layout()
```

Alcance mínimo (MVP) — **suficiente para desbloquear el CardHeader**:

- Tracks por columna/fila con unidades `"<n>fr"` (fracción del espacio libre), `"auto"`
  (tamaño natural del hijo) y `<número>` (px fijos). Es el subconjunto que usa shadcn
  (`[1fr auto]`, `[auto auto]`).
- `col`/`row` (1-indexado) + `colSpan`/`rowSpan` por ítem.
- `justifySelf` / `alignSelf` (`start` | `center` | `end` | `stretch`) por ítem.
- `gap` (y opcional `rowGap`/`colGap`), `paddingH`/`paddingV`.
- Reusar las lecciones ya resueltas en Flex: `math.floor` en offsets (ADR-0011),
  `ClearAllPoints` antes de cada `SetPoint`, cache de tamaño natural tipo `_naturalBasis`
  para no encoger acumulativo en resize, guarda `if container:GetWidth() == 0 then return end`.

Fuera de alcance MVP (documentar como limitación, igual que hizo Flex con wrap): áreas con nombre
(`grid-template-areas`), auto-placement/`grid-auto-flow`, `minmax()`, `repeat()`, subgrid.

## Caso de uso

- **`CardHeader` de `Craft.Panel`** → implementar [FR-039](FR-039-panel-cardaction-header.md)
  (slot `CardAction`) sobre un grid `[1fr auto]` en vez de anclas manuales. Este FR es
  prerrequisito natural de FR-039.
- Form Cards (Payout Threshold y similares) → filas label+valor y rejillas de campos declarativas.
- Cualquier consumidor (Coffer, Beacon) que porte un `Card`/formulario de shadcn.

## Impacto

Nuevo módulo de **API pública** (`Craft.Grid`) → requiere aprobación del maintainer, ADR propio,
spec en `docs/components/grid.md`, suite `tests/grid_spec.lua`, registro en `.toc`/`Craft.lua` con
`Craft.register` (build-versioned, colisión LibStub §CLAUDE.md), y bump de build. Aditivo: no
toca componentes existentes. Recomendado también: página demo en Craft_Browser (`pages/Grid.lua`).

## Workaround actual

Colocación manual con `SetPoint` y offsets `-y` (patrón actual en `pages/Panel.lua`). Funciona
pero es frágil y no expresa el `CardAction` 2D → FR-039 sigue bloqueado sin este motor.
