# Component: Combobox

> Referencia shadcn: `combobox` — https://ui.shadcn.com/docs/components/combobox
> (composición Popover + Command; verificado contra `command.json` new-york-v4, 2026-07-13)
> WoW frame base: trigger `Button` (como Select) + panel = **`Craft.Popover`** (FR-028) con
> `padding = 0` conteniendo el "Command": EditBox de búsqueda + lista scrolleable filtrada.
> FR de origen: `docs/requests/FR-027-combobox-command.md` (Coffer).

## CSS de referencia (Command, new-york-v4)

```
CommandInput wrapper: flex h-9 items-center gap-2 border-b px-3
CommandInput:         bg-transparent text-sm placeholder:text-muted-foreground
CommandList:          max-h-[300px] overflow-y-auto
CommandEmpty:         py-6 text-center text-sm
CommandGroup:         p-1  · heading: px-2 py-1.5 text-xs font-medium text-muted-foreground
CommandItem:          px-2 py-1.5 text-sm gap-2
                      data-[selected=true]:bg-accent data-[selected=true]:text-accent-foreground
                      (check ml-auto, visible solo en el value seleccionado — demo combobox)
Trigger (demo):       Button variant=outline role=combobox + ChevronsUpDown opacity-50
PopoverContent:       w-[200px] p-0
```

Adaptaciones Craft (Lyra base `text-xs`): texto de items/búsqueda = 12px (paridad
Select/Menu, no el `text-sm` web). Trigger reusa el estilo del trigger de Select
(border `t.input`, bg `input/30`, hover `input/50`, h-8/h-7). El icono
`chevrons-up-down` no está en el atlas → chevron-down/up como Select (candidato a
añadirse al atlas en un FR de iconos futuro).

## Propósito

Selector con **búsqueda tipeada** para listas largas o variables (`Select` es para
listas cortas y fijas). Al abrir: input de filtro arriba + lista scrolleable filtrada
en vivo, con grupos opcionales. Casos Coffer: fuentes LSM (decenas) y "añadir regla"
(~30 clases × subclases de ítem).

## Jerarquía de frames WoW

```
combo.frame            (Frame — raíz, en parent)
└── combo._trigger     (Button — estilo trigger de Select: border/bg/texto/chevron)
combo._pop             (Craft.Popover — padding=0, side=bottom, align=start)
└── content
    ├── combo._searchRow   (Frame h-9=36: icono search 16px + EditBox + border-b 1px)
    ├── combo._scroll      (ScrollFrame p-1, max-h 300)
    │   └── rows pooled    (≤ 14 — una ventana del viewport, FR-125; headings + items con check)
    └── combo._empty       (FontString py-6 center — sin resultados)
```

## Dimensiones

| Propiedad | Valor | Fuente |
|-----------|-------|--------|
| Trigger alto | 32 (default) / 28 (sm) | Select h-8 / h-7 |
| Search row | 36 alto, px 12, gap icono→texto 8, icono 16 | `h-9 px-3 gap-2` |
| Item | 24 alto (py-1.5×2 + 12), pl 8, reserva check 28 | `px-2 py-1.5` |
| Group heading | 24 alto, pl 8, font-medium, mutedForeground | `px-2 py-1.5 text-xs` |
| Lista | padding 4 (`p-1`), alto máx 300 | `max-h-[300px]` |
| Empty | py-6 → 60 alto, centrado | `py-6 text-center` |
| Check | 12px, derecha (`ml-auto`), solo en el value seleccionado | demo combobox |
| Panel | ancho = trigger (floor 144), alto auto | `w-[200px] p-0` + MIN_PANEL_W Select |

## Filtrado

- Match **case-insensitive** por substring contra `label` y contra `keywords`
  (string u array de strings opcional por opción).
- Con grupos: un grupo aparece si tiene ≥1 item que matchea (heading incluido).
- Sin matches: estado empty (`emptyText`).
- El filtro se **resetea al abrir** (query vacía = lista completa).

## Teclado (paridad Menu/shadcn)

| Tecla | Acción |
|-------|--------|
| ↑ / ↓ | Mueve el highlight (bg-accent) entre items visibles, con wrap; auto-scroll para mantenerlo visible. |
| Enter | Selecciona el item highlighted (equivale a click). |
| Esc | Cierra el panel (OnEscapePressed del EditBox; el catcher/Esc de Popover cubre el resto). |

El highlight (`data-[selected=true]` de cmdk) es **hover O teclado** — una sola noción:
mover el mouse actualiza el highlight, las flechas también.

## Estados

| Estado | Visual |
|--------|--------|
| closed | trigger normal (border `t.input`, bg `input/30`) |
| open | border `t.ring`, chevron-up, search con foco |
| item highlighted | bg `t.accent`, texto `t.accentForeground` |
| item seleccionado | check 12px `t.popoverForeground` a la derecha |
| disabled | alpha 0.5, sin mouse |

## Mapa de tokens

| Elemento | Token |
|----------|-------|
| Trigger border / bg / hover | `t.input` (a, /30, /50) — paridad Select |
| Trigger texto placeholder / valor | `t.mutedForeground` / `t.foreground` |
| Chevron / icono search | `t.mutedForeground` |
| Search texto / placeholder | `t.popoverForeground` / `t.mutedForeground` |
| Separador bajo el search | `t.border` (1px vía `SetPixelHeight`) |
| Panel (bg/borde) | los de Popover (`t.popover` / `t.border`) |
| Item texto / highlight | `t.popoverForeground` / `t.accent`+`t.accentForeground` |
| Group heading | `t.mutedForeground`, `t.fontMedium` |
| Empty | `t.popoverForeground` |

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|-------|------|---------|-------------|
| `options` | table/signal | `{}` | Plana `{{value, label, keywords?}, ...}` o agrupada `{{group="Tipo", items={...}}, ...}` (mezclables). Señal = bind one-way via `SetOptions`. |
| `value` | any/signal | `nil` | Selección. Señal escribible = two-way (ADR-0013). |
| `placeholder` | string | `"Select..."` | Texto del trigger sin selección. |
| `searchPlaceholder` | string | `"Search..."` | Placeholder del input de filtro. |
| `emptyText` | string | `"No results."` | Texto del estado sin matches. |
| `size` | string | `"default"` | `"default"` (h 32) / `"sm"` (h 28) — paridad Select. |
| `width` | number | `nil` | Ancho fijo del trigger (el panel siempre iguala al trigger, floor 144). |
| `disabled` | boolean/signal | `false` | Bindeable (`SetEnabled`). |
| `onSelect` | function | `nil` | `function(value, label)` en cada selección del usuario. |

## API pública

| Método | Descripción |
|--------|-------------|
| `Open()` / `Close()` | Abre/cierra el panel (Open resetea el filtro y enfoca el search). |
| `IsOpen()` | → boolean. |
| `SetValue(v)` / `GetValue()` | Selección programática (no dispara `onSelect`). |
| `SetOptions(opts)` | Reemplaza las opciones (re-filtra si está abierto). |
| `SetEnabled(b)` | Habilita/deshabilita el trigger. |
| `GetFrame()` | → Frame raíz (trigger). |
| `Destroy()` | Contrato §5; destruye también su Popover interno. |

## Notas de implementación

- **Construido sobre `Craft.Popover`** (FR-028): anclaje/z-order/catcher/Esc/animación
  vienen del Popover (`padding=0`, `SetWidth` al ancho del trigger en cada Open). El
  Combobox solo posee el contenido (search + lista) y el trigger.
- **Lista virtualizada (FR-125).** El scroll child mide `#entries × ROW_H` (headings
  incluidos, misma altura), pero solo existen `POOL_SIZE = ceil(292 / 24) + 1 = 14` filas:
  las que caben en el viewport (`max-h 300` − `p-1`) más la parcial del borde. Todo scroll
  (rueda, `_scrollIntoView`, refiltro) pasa por `_setScroll`, que recorta el offset y
  reasigna el pool a la ventana `_first .. _first+13` (`_renderWindow`); `_rowOf[i]` da la
  fila que pinta la entrada `i`, si está en pantalla. El catálogo de 1247 zonas de SMRT
  cuesta 14 marcos, no 1247, y cada tecla repinta 14 filas. Las filas morfan entre
  heading/item; el excedente (lista corta) queda oculto con `index = nil`. Es la
  virtualización que se le añade a `cmdk` para listas grandes: el aspecto no cambia.
- **Highlight, Enter, click y check van por ÍNDICE DE ENTRADA**, nunca por fila: `_hl` es
  un índice de `_entries` y `row.index` dice qué entrada muestra la fila ahora. ↑ desde el
  primer item salta al último y lo trae a la vista aunque no tuviera fila. La rueda no
  mueve el highlight (cmdk: solo el movimiento del puntero lo mueve).
- **Alto del viewport calculado, no medido:** `_viewH` sale del alto que `_buildRows` da
  al contenido, porque en el primer render de `Open` el Popover aún no ha resuelto anclas
  y el `GetHeight()` del ScrollFrame no es fiable.
- **El EditBox captura Enter/Esc/flechas** solo mientras tiene foco (WoW se lo da al
  abrir); no hay navegación Tab (mouse-only, AGENTS.md §7 — esto es tipeo, no focus ring).
- **`SetValue` programático no dispara `onSelect`** — solo el click/Enter del usuario
  (paridad Select; evita double-fire con el bind two-way).
- **Sin `Command` genérico**: los grupos en `options` cubren el caso "añadir regla" del
  FR sin un componente Command aparte.
