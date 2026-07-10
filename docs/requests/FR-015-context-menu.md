# FR-015 — ContextMenu / Menu rico (headings, checkbox/radio/right-text/delete por entrada)

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** nuevo `Craft/components/Menu.lua` (shadcn: `DropdownMenu` + `ContextMenu`)
**Tipo:** Feature Request
**Prioridad:** **Alta** — 6 consumidores en Coffer; `Select` no lo cubre. Es el gap #1 de la
fase de diseño de UI (Coffer `docs/UI-DESIGN.md` §5.7, §9 FR-1)
**Estado:** Implementado en `dev` (2026-07-10, rama `feat/menu`) — `Craft/components/Menu.lua` +
`tests/menu_spec.lua` (20 tests). Pendiente: demo Browser (6 casos) + release MINOR + re-vendoreo en Coffer.

---

## Problema

`Craft.Select` es un `<select>` plano: un nivel, un solo valor, checkmark en el elegido. No
soporta **menús ricos**: headings/agrupación, checkbox/radio por entrada, texto a la derecha
(right-text), icono por entrada, botón de borrar por fila, submenús, ni entradas
deshabilitadas. Coffer necesita exactamente eso en **seis** sitios distintos, todos con la
misma forma. Sin un componente, cada uno se reimplementa a mano (lo que hacía Sorted con su
`DropdownMenu` propio — 300+ líneas — por esta misma carencia).

## Casos de uso (Coffer) — los 6 consumidores

```
column-header (sort/columnas)   char dropdown (offline)          category-narrowing
┌───────────────────┐           ┌──────────────────────────┐     ┌──────────────────────┐
│ Grouping          │           │ ── Kalimdor (realm) ──    │     │ Type/Subtype         │
│  ◉ Category       │           │  ◉ Thrall     70 Orc  (✕) │     │  ☑ Consumable        │
│  ○ Type           │           │  ○ Garrosh    68 Orc  (✕) │     │  ☐ Flask             │
│ Columns           │           │ ── Azeroth ──             │     │ Equip Location       │
│  ☑ Quantity       │           │  ○ Jaina      70 Human(✕) │     │  ☑ Head              │
│  ☑ Name (locked)  │           └──────────────────────────┘     └──────────────────────┘
│  ☐ Age            │           heading + radio + right-text     heading + checkbox por
└───────────────────┘           + botón borrar por fila           atributo (temporal)
```

1. **Column-header** (click-der en cabecera): heading "Grouping" + radios; heading "Columns" +
   checkboxes; una entrada **deshabilitada** (NAME no desactivable).
2. **Category-narrowing** (click-der en categoría): valores agrupados por atributo (headings) +
   checkboxes temporales.
3. **Group-by**: radios (Category/Marker/Type/Equip/Quality/Binding/Expansion).
4. **Char dropdown** (offline): headings por reino + radios + **right-text** ("70 Orc") +
   **botón de borrar (✕) por fila** (menos el personaje actual).
5. **Equipment-set dropdown**: radios (sets) + entradas especiales ("No Equipment Set", "Clear").
6. **Attributes dropdown** (editor de categorías): headings por tipo de atributo + marca de
   "tiene datos".

## Solución propuesta

### API (config declarativa; las props aceptan señales Weave)
```lua
local menu = Craft.Menu:Create({
  items = {
    { type = "heading", label = "Grouping" },
    { type = "radio", group = "grouping", value = "category", label = "Category",
      checked = groupingSignal, onSelect = function(v) ... end },        -- checked reactivo
    { type = "separator" },
    { type = "heading", label = "Columns" },
    { type = "checkbox", label = "Quantity", checked = true,  onToggle = function(on) ... end },
    { type = "checkbox", label = "Name", checked = true, disabled = true },   -- locked
    { type = "item", label = "Thrall", icon = "user", rightText = "70 Orc",
      onClick = fn, onDelete = fn },                                     -- delete (✕) por fila
    { type = "item", label = "More…", submenu = { items = { ... } } },   -- submenú
  },
})
menu:Open(anchorFrame, { point = "TOPLEFT", relativePoint = "BOTTOMLEFT" })
-- o helper de conveniencia para right-click:
Craft.Menu:AttachContextMenu(frame, function() return { items = { ... } } end)
```

### Tipos de entrada
| `type` | Render | Callback |
|---|---|---|
| `heading` | label atenuado, no interactivo | — |
| `item` | label (+ `icon`, + `rightText`, + `onDelete`→✕) | `onClick` |
| `checkbox` | checkbox a la izquierda (tri-estado ok) | `onToggle(on)` |
| `radio` (`group`) | radio-dot; exclusivo dentro de `group` | `onSelect(value)` |
| `separator` | línea 1px | — |
| con `submenu` | chevron-right; abre al hover | — |

### Comportamiento
- **Un popup por instancia**, strata `DIALOG`, **anclado** al frame que lo abre; ancho = string
  más ancho; scroll interno si excede `maxHeight` (reusar `Craft.Scroll`).
- **Dismissal unificado**: click-fuera (catcher fullscreen) **+ Esc** (`UISpecialFrames`). Un
  solo comportamiento para todos los menús (Coffer §U6: Sorted tenía dismissal inconsistente
  entre sus 3 menús — no repetir).
- `disabled` → entrada gris no clickeable. `checked`/`disabled`/`label` **aceptan señales
  Weave** (binding reactivo, como el resto de Craft).
- Themed por tokens (`popover`/`popover-foreground`/`border`/`accent`).
- Iconos por entrada del atlas Lucide existente (`icon="..."`).

## Alcance / no-alcance
- **En alcance**: menú de **lista** (los 6 casos de arriba).
- **Fuera** (Coffer lo resuelve custom): el **marker-menu** de Coffer es un **grid 4×2 de
  iconos** (marcadores de raid, texturas Blizzard) + Clear — no es una lista. Podría ser una
  variante `layout="grid"` a futuro, pero NO es necesaria para este FR.

## Workaround actual (Coffer)

Menú custom addon-side estilo el `DropdownMenu` de Sorted (un frame pooled + builder
`AddEntry`/`AddCheckbox`/`AddRadio`/`AddRightText`/`AddDeleteButton`/`SetHeading`), con el
dismissal unificado. Funcional pero fuera del estilo/tokens de Craft y sin binding reactivo;
se migra a `Craft.Menu` en cuanto exista. **No bloquea M5.**

## Impacto

Componente nuevo (aditivo, no toca API existente). Alto apalancamiento: cubre 6 interacciones
de Coffer de un golpe y es reutilizable por otros consumidores (Sentry/Beacon tienen menús
contextuales equivalentes). shadcn ya modela esto como `DropdownMenu`/`ContextMenu` → encaja en
la familia.
