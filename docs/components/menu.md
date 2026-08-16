# Component: Menu

> Referencia shadcn: `dropdown-menu` + `context-menu` — WoW frame base: `Frame` (popover custom)
> Origen: [FR-015](../requests/FR-015-context-menu.md) (+ [FR-065](../requests/FR-065-menu-item-avatar.md),
> avatar de fila). Estado: **implementado** en `dev` y verificado in-game
> (`Craft/components/Menu.lua`, `tests/menu_spec.lua`). Pendiente de release (MINOR).

`Craft.Menu` es **un solo componente** que cubre las dos primitivas de shadcn a la vez:
`DropdownMenu` (abre con click izquierdo desde un trigger) y `ContextMenu` (abre con click
derecho anclado al cursor). Ambas comparten en shadcn **exactamente la misma anatomía de
contenido** (`Content`/`Item`/`CheckboxItem`/`RadioGroup`/`RadioItem`/`Label`/`Separator`/
`Shortcut`/`Sub…`) — por debajo son el mismo primitivo `Menu` de Radix. `Menubar` y
`NavigationMenu` NO son el análogo: el primero es una barra horizontal persistente de menús,
el segundo un menú de navegación web. Un futuro menubar sería *componer una fila de triggers
sobre `Craft.Menu`*, no un componente nuevo.

## CSS de referencia (Lyra)

> **✅ Geometría verificada vía `/update-design-tokens`** contra `style-lyra.css`
> (`.cn-dropdown-menu-*` / `.cn-context-menu-*`) — 2026-07-09. Valores literales abajo.

```css
/* dropdown-menu (Open anclado) · context-menu min-w = 36 (144px), resto idéntico */
.cn-dropdown-menu-content {
  @apply bg-popover text-popover-foreground ring-foreground/10 min-w-32 rounded-none
         shadow-md ring-1 duration-100;                 /* p-1 (4px) viene del base .tsx */
}
.cn-dropdown-menu-item {           /* item plano */
  @apply focus:bg-accent focus:text-accent-foreground gap-2 rounded-none
         px-2 py-2 text-xs data-inset:pl-7 [&_svg]:size-4
         data-[variant=destructive]:text-destructive
         data-[variant=destructive]:focus:bg-destructive/20;   /* dark */
}
.cn-dropdown-menu-checkbox-item,
.cn-dropdown-menu-radio-item {     /* indicador a la DERECHA → pl-2 pr-8 */
  @apply focus:bg-accent focus:text-accent-foreground gap-2 rounded-none
         py-2 pr-8 pl-2 text-xs data-inset:pl-7 [&_svg]:size-4;
}
.cn-dropdown-menu-item-indicator { @apply absolute right-2 flex items-center justify-center; }
.cn-dropdown-menu-label      { @apply text-muted-foreground px-2 py-2 text-xs font-medium; }
.cn-dropdown-menu-separator  { @apply bg-border -mx-1 h-px; }  /* my-1 (4px) del base .tsx */
.cn-dropdown-menu-shortcut   { @apply text-muted-foreground ml-auto text-xs tracking-widest; }
/* indicadores (de dropdown-menu.tsx): check = size-3.5 (14px) CheckIcon ·
   radio = size-2 (8px) CircleIcon filled · sub-trigger chevron = chevron-right ml-auto size-4 */
```

> **✅ DECISIÓN (2026-07-09) — indicador checkbox/radio a la DERECHA.** Se sigue Lyra
> (`.cn-*-item-indicator { absolute right-2 }`, item `pl-2 pr-8`), igual que el checkmark de
> [`Select`](select.md): fidelidad total + consistencia con el resto de Craft. Se descartó la
> opción izquierda (mockup de Coffer, [FR-015](../requests/FR-015-context-menu.md)) — Coffer se
> adapta a la posición Lyra. Confirmado en el demo oficial de `ContextMenu` de shadcn (checkmarks
> de CheckboxItem/RadioItem a la derecha). Todo el spec asume este lado.

## Propósito

Menú rico flotante de una sola columna: encabezados (headings), separadores, e ítems de
acción con icono, texto a la derecha (right-text), botón de borrar por fila, checkbox
(tri-estado) y radio exclusivo por grupo. WoW no provee un menú contextual moderno
personalizable — todo se construye con frames, texturas y FontStrings, reutilizando la infra
de panel de `Craft.Select`.

## Alcance (v1) y diferido

**En alcance v1** — desbloquea los 6 consumidores de Coffer:
`heading`, `item` (+`icon` +`rightText` +`onDelete`), `checkbox` (tri-estado), `radio`
(+`group`), `separator`, filas `disabled`, props reactivas, dismissal unificado
(catcher fullscreen + Esc), `Open(anchor, opts)` anclado + `AttachContextMenu(frame, builder)`
al cursor, scroll interno si excede `maxHeight`.

**Diferido (fuera de v1):**
- **Submenús** (`Sub`/`SubTrigger`/`SubContent`). Ningún caso de Coffer los usa y concentran el
  grueso de la complejidad (panel propio, apertura por hover, flip lateral, dismissal
  encadenado). La key `submenu` queda **reservada / no-op** en v1 para no romper el API.
- **`layout="grid"`** (marker-menu de Coffer — grid 4×2 de iconos). Coffer lo resuelve custom;
  posible variante futura.

## Animación

Reutiliza la animación de panel de `Craft.Select`: fade + `zoom-in-95` + `slide-in-from-top`
(ADR-0013 §4.6) con un único progreso `alpha` 0→1 (Close lo invierte 1→0); el zoom se
**multiplica** sobre la compensación de escala del contenedor (`anchorEff/uiParentEff`). En
modo context (anclado al cursor) el slide entra desde el borde más cercano al cursor.

## Jerarquía de frames WoW

```
Frame (panel)                       — TOOLTIP strata, parent UIParent, con NOMBRE (UISpecialFrames)
├── Texture (bg)                    — BACKGROUND layer, t.popover fill
├── Frame  (ring)                   — hermano 1px outward, t.foreground a=0.10
└── ScrollFrame (rowScroll)
    └── Frame (scrollChild)
        └── row × N  (pooled por índice — nunca destruir/recrear):
            ├─ heading   → FontString (mutedForeground, font-medium)  — no interactivo
            ├─ separator → Texture 1px t.border
            └─ item      → Button   (pl-2; checkbox/radio reservan pr-8 a la derecha)
                 ├── Craft.Avatar (24px)   ← si config.avatar (slot leading; PISA a icon, fila 36px)
                 ├── Texture (icon 16px)   ← si config.icon (izquierda, tras pl-2)
                 ├── FontString (label)
                 ├── FontString (rightText)← muted, right-aligned (Shortcut)
                 ├── Texture (indicator)   ← DERECHA (right-2): check/minus 14px (checkbox)
                 │                              | discos ring/fill/dot 8px (radio)   [ver DECISIÓN]
                 └── Button (delete ✕ 12px)← si config.onDelete (área propia, no dispara onClick)

Frame (catcher)                     — FULLSCREEN_DIALOG strata (justo bajo TOOLTIP),
                                       fullscreen, transparente, EnableMouse → click cierra
```

El indicador de `checkbox` reutiliza el patrón de [`Checkbox.lua`](../../Craft/components/Checkbox.lua)
(glyphs `check`/`minus`, tri-estado). El indicador de `radio` reutiliza los **3 discos**
supersampleados de [`RadioGroup.lua`](../../Craft/components/RadioGroup.lua) (glyph `disc`;
no hay glyph `circle` plano en el atlas).

## Tipos de entrada (`items[]`)

| `type` | Render | Callback | Parte shadcn |
|---|---|---|---|
| `heading` | label atenuado (`mutedForeground`, font-medium), no interactivo | — | `MenuLabel` (Group) |
| `item` | label + (`avatar` **o** `icon` izq) + (`rightText` der) + (`onDelete`→✕); `variant="destructive"` → texto/hover destructive | `onClick` | `MenuItem` (+`Shortcut`) |
| `checkbox` | indicador check/minus a la izq (tri-estado) | `onToggle(on)` | `CheckboxItem` |
| `radio` (`group`) | disco radio; exclusivo dentro de `group` | `onSelect(value)` | `RadioGroup`+`RadioItem` |
| `separator` | línea 1px `t.border` | — | `MenuSeparator` |
| `submenu` | **reservado / no-op en v1** (chevron-right a futuro) | — | `Sub…` |

> **`avatar` (retrato en el slot leading) es una extensión de Craft** ([FR-065](../requests/FR-065-menu-item-avatar.md)),
> igual que `rightText` y `onDelete`. En shadcn el avatar del patrón *account switcher* viene del
> **markup del bloque**, no del CSS de `dropdown-menu` (que solo fija `[&_svg]:size-4` para
> iconos): **no hay CSS Lyra que replicar** — misma clase de matiz que el `h-56`/`border` de
> [FR-063](../requests/FR-063-empty-state.md). Es un `Craft.Avatar` size `sm` (24px) y **excluye
> a `icon`** (si vienen los dos, gana `avatar`).
>
> **`onDelete` (✕ por fila) es una extensión de Craft**, no existe en shadcn `dropdown-menu`.
> Es un botón trailing con su propia hit-area (frameLevel mayor que la fila) para que su click
> dispare `onDelete` sin disparar el `onClick` de la fila. Requerido por Coffer (dropdown de
> personajes offline, caso #4). Documentado como divergencia consciente.
>
> **`tooltip` por fila es una extensión de Craft** ([FR-067](../requests/FR-067-menu-item-tooltip.md)).
> `DropdownMenuItem` de shadcn no lo tiene, pero el tooltip es la afordancia WoW para explicar
> un control (ya establecida en `Craft.Button`, FR-020) y una acción que se muda de un botón de
> barra a una fila de menú perdía su único canal explicativo. Detalles de comportamiento:
>
> - `string` para el caso simple; `fn(cfg) → string` para texto que cambia entre aperturas
>   (se evalúa **en el hover**, no al construir — las filas son pooled y se reconfiguran en
>   cada `Open`). Devolver `nil`/`""` no muestra nada.
> - **Anclado a la DERECHA** (`side = "right"` de `Craft.Tooltip`): un menú ya está pegado a su
>   ancla y un tooltip arriba/abajo taparía las filas vecinas.
> - **Retardo de 300ms**, el mismo de `Craft.Tooltip.Attach`. Las filas están apiladas, así que
>   el cursor barre varias camino de la suya: sin retardo el tooltip estroboscopía por la lista.
>   No se usa `Attach` directamente porque ata UNA config a un frame de por vida y estas filas
>   se reciclan.
> - **Funciona con `disabled = true`** — que es el caso que más lo pide ("necesitas un banquero").
>   Por eso una fila gris **conserva el mouse** (`EnableMouse`); el clic y el resaltado de hover
>   los siguen bloqueando los guards de `_disabled`, no la ausencia de mouse. Misma política que
>   `Craft.Button`, cuyo tooltip también se ve estando gris.

## Dimensiones

> ✅ Verificado contra `style-lyra.css` (2026-07-09). Asume el indicador a la DERECHA
> (opción (a), ver DECISIÓN arriba); con opción (b) intercambiar `pl-2 pr-8` → `pl-7 pr-2`.

| Propiedad | Valor |
|---|---|
| Altura de fila `item`/`checkbox`/`radio` | **28px** (`py-2`=8 + text-xs=12 + `py-2`=8) — igual que Select |
| Altura de fila `item` **con `avatar`** | **36px** = 24 (avatar `sm`) + 6×2 de aire — solo esa fila (extensión Craft, alturas mixtas) |
| Avatar de fila | `Craft.Avatar` size `sm` = **24px**, en `pl-2`, `gap-2` hasta el label |
| Altura `heading` | 28px (`px-2 py-2` + text-xs, `font-medium`) |
| Padding interno del panel | `p-1` = 4px (del base .tsx; Lyra no lo overridea) |
| Padding H de `item` plano | `px-2` = 8px ambos lados |
| Padding de `checkbox`/`radio` | `pl-2` = 8px izq · `pr-8` = 32px der (reserva indicador derecho) |
| Indicador (posición) | `absolute right-2` = 8px del borde derecho |
| Gap icono → label | `gap-2` = 8px |
| Check indicator | `size-3.5` = 14px (glyph `check`/`minus`) |
| Radio dot | `size-2` = 8px (disco `dot`, como RadioGroup) |
| Icono de fila | `size-4` = 16px |
| Botón delete ✕ | 12px (extensión Craft) |
| Separator | `h-px` (1px) + `-mx-1` (se extiende 4px) + `my-1` (4px margen V, del base) |
| Min-width del panel | dropdown `min-w-32`=**128px** · context `min-w-36`=144px |
| Width del panel | `w-fit`: `max` sobre filas de `(pl + indicador? + icono? + gap + label + rightText + delete? + pr)`, piso `min-w-32` |
| Max height | altura disponible en pantalla (`max-h-available`); scroll si excede |
| Ring del panel | 1px outward, `t.foreground` a=0.10 (idéntico a Select) |

## Estados

### Fila `item` / `checkbox` / `radio`

| Estado | Bg | Label |
|---|---|---|
| Default | Transparent | `t.popoverForeground` |
| Hover | `t.accent` | `t.accentForeground` |
| Disabled | Transparent + `SetAlpha(0.5)`, sin mouse | `t.mutedForeground` |

- `checkbox` marcado → glyph `check`; indeterminado → glyph `minus`; ambos `popoverForeground`.
- `radio` seleccionado → disco `dot` visible (`primary`), como `RadioGroup`.
- `rightText` → siempre `t.mutedForeground`, alineado a la derecha (no cambia en hover salvo el resto).
- Botón `delete` ✕ → `mutedForeground`, `destructive` en su propio hover.

### `heading` / `separator`

No interactivos. `heading` = `mutedForeground` font-medium. `separator` = `t.border` 1px.

## Mapa de tokens

| Elemento | Token / Valor |
|---|---|
| Panel bg | `t.popover` = {r=0.091,g=0.091,b=0.091} |
| Panel ring (1px outward) | `t.foreground` a=0.10 = {r=0.980,g=0.980,b=0.980,a=0.10} |
| Label de fila (default) | `t.popoverForeground` |
| Fila bg hover | `t.accent` |
| Fila label hover | `t.accentForeground` |
| Fila disabled | `t.mutedForeground` + `SetAlpha(0.5)` |
| Heading | `t.mutedForeground` |
| rightText | `t.mutedForeground` |
| Separator | `t.border` |
| Checkbox indicador | `t.popoverForeground` (glyph check/minus) |
| Radio ring/fill/dot | `t.border`/`t.input` (idle) · `t.primary`/`t.primaryForeground` (selected) |
| Delete ✕ | `t.mutedForeground` · `t.destructive` (hover) |

## Config — `Create(config)`

> **Nota:** a diferencia del resto de componentes, `Menu` no se instala en un `parent` — su
> panel se parenta a `UIParent` (strata TOOLTIP) y se ancla en `Open`. Por eso la firma es
> `Create(config)` (sin `parent`), o se usa el helper `AttachContextMenu`.

| Parámetro | Tipo | Default | Descripción |
|---|---|---|---|
| `items` | `table` | `{}` | Array de entradas (ver tabla de tipos). Cada campo puede ser literal o señal Weave |
| `width` | `number` | `nil` (`w-fit`) | Ancho fijo del panel en px (equivale a `className="w-56"` en shadcn). Si es `nil`, `w-fit` = ancho de la fila más ancha, piso `min-w-32`=128 |
| `maxHeight` | `number` | altura disponible en pantalla | Tope de altura (Lyra: `max-h-(--available-height)`); scroll interno (`Craft.Scroll`) si el contenido excede |
| `onClose` | `function` | `nil` | Callback al cerrar (click-fuera, Esc, o selección) |

### Campos por entrada de `items`

| Campo | Tipos que lo usan | Descripción |
|---|---|---|
| `type` | todos | `"heading"` \| `"item"` \| `"checkbox"` \| `"radio"` \| `"separator"` \| `"submenu"`(no-op) |
| `label` | heading, item, checkbox, radio | Texto (acepta señal) |
| `icon` | item | Nombre de icono Lucide del atlas (`Craft.Icons`) — ignorado si hay `avatar` |
| `avatar` | item | Tabla de config de `Craft.Avatar` size `sm`: `{ unit=… }` \| `{ atlas=… }` \| `{ image=…, crop=…, texCoord=… }` + `fallback` (iniciales) + `desaturated`. Sube la fila a 36px (extensión Craft, [FR-065](../requests/FR-065-menu-item-avatar.md)) |
| `rightText` | item | Texto atenuado a la derecha (Shortcut) |
| `onClick` | item | `fn()` al clickear la fila |
| `onDelete` | item | `fn()` — muestra ✕ trailing; su click no dispara `onClick` (extensión Craft) |
| `variant` | item | `"default"` (def) \| `"destructive"` → texto `t.destructive`, hover `destructive/20` (confirmado en HTML Lyra real) |
| `checked` | checkbox, radio | `true`/`false`/`"indeterminate"` — acepta señal (reactivo) |
| `onToggle` | checkbox | `fn(on)` al alternar |
| `group` | radio | Id de grupo; selección exclusiva dentro del grupo |
| `value` | radio | Valor de esta opción de radio |
| `onSelect` | radio | `fn(value)` al seleccionar |
| `disabled` | item, checkbox, radio | Fila gris no clickeable — acepta señal. **Sigue recibiendo hover** para poder mostrar su `tooltip` (FR-067) |
| `tooltip` | item, checkbox, radio | `string` \| `fn(cfg) → string`. Tooltip de la fila, anclado a su DERECHA tras 300ms de hover. Funciona también con `disabled = true` (extensión Craft, [FR-067](../requests/FR-067-menu-item-tooltip.md)) |
| `submenu` | (reservado) | v1: ignorado |

> **Props reactivas (ADR-0013):** `label`, `checked` y `disabled` de cada entrada aceptan
> señal/computed de Weave. **Ciclo de vida:** los binds se crean al **abrir** el menú y se
> descartan (`disposeAll`) al **cerrar** — no en `Destroy` — porque el contenido es efímero y
> `AttachContextMenu` lo reconstruye en cada apertura. Sin esto habría ghost-updates entre
> aperturas.

## API pública

| Método | Descripción |
|---|---|
| `Craft.Menu:Create(config)` | Crea una instancia de menú (panel oculto hasta `Open`) |
| `menu:Open(anchor, opts)` | Abre anclado a `anchor`. `opts = {point, relativePoint, x, y}` (default `TOPLEFT`→`BOTTOMLEFT`). Modo dropdown |
| `menu:OpenAtCursor(scaleRef)` | Abre bajo el cursor (`GetCursorPosition()`, ADR-0011), con clamp si se sale de pantalla. Modo context. `scaleRef` (opcional) = frame cuya escala adopta el panel — mismo rol que `anchor` en `Open`; por defecto `UIParent` |
| `menu:Close()` | Cierra el panel (dispara `onClose`) |
| `menu:SetItems(items)` | Reemplaza las entradas (reutiliza filas por índice) |
| `menu:Destroy()` | Libera frames, listeners de tema y binds |
| `Craft.Menu:AttachContextMenu(frame, builder)` | Registra click derecho sobre `frame`; `builder()` retorna `{ items = {...} }` fresco en cada apertura, y abre al cursor |

## Notas de implementación

- **Reutilizar la infra de panel de `Select`**: `Menu` es esencialmente el panel de
  [`Select.lua`](../../Craft/components/Select.lua) **sin trigger propio** + filas heterogéneas
  + Esc. Reaprovechar: panel en `UIParent` strata `TOOLTIP`, ring 1px + bg `popover`,
  `ScrollFrame`+`scrollChild`, **pooling de filas por índice** (`_makeRow`/`_buildRows`),
  animación fade+zoom+slide, medición de ancho. NO destruir/recrear frames entre rebuilds.
- **Un factory por tipo de fila** que crea el frame una vez; `_buildRows` sólo hace fluir datos
  y reposiciona; el excedente se oculta y neutraliza (contador `_count`; `_applyTheme` itera
  `1.._count`, no `#pool`). Igual que Select/Sidebar (AGENTS §5, props de lista).
- **Dismissal unificado** (FR §Comportamiento): (1) `catcher` fullscreen transparente
  `EnableMouse(true)` en strata `FULLSCREEN_DIALOG` (justo bajo el panel TOOLTIP) que en
  `OnMouseDown` cierra; (2) **Esc** vía `table.insert(UISpecialFrames, panelName)` (panel con
  NOMBRE), patrón de [`Dialog.lua`](../../Craft/components/Dialog.lua)/`Window.lua`. Blizzard
  llama `panel:Hide()` directo en Esc → hookear `OnHide` para disparar `onClose` y limpiar.
- **Posición context (cursor)** (FR-061): `GetCursorPosition()` devuelve **píxeles de pantalla**;
  el offset se ancla a `UIParent` `BOTTOMLEFT`, así que hay que dividir por la escala efectiva
  que el panel **tendrá** tras `_doOpen` — la de `scaleRef` (`UIParent` por defecto), no
  `panel:GetEffectiveScale()`, que en ese momento aún guarda la escala del open ANTERIOR:
  `local eff = (scaleRef or UIParent):GetEffectiveScale(); panel:SetPoint("TOPLEFT", UIParent,
  "BOTTOMLEFT", x/eff, y/eff)` con `_doOpen(scaleRef)` (→ `panelBaseScale = eff/uiEff`, coherente).
  Flip/clamp con `SetClampedToScreen`.
- **El zoom de la animación no debe arrastrar el offset**: los offsets de `SetPoint` se leen en
  las unidades del **propio panel**, que está escalando (`zoom-in-95`). Con el offset de 2px de un
  dropdown es imperceptible, pero el de `OpenAtCursor` es una coordenada de pantalla entera y el
  panel entraría volando desde la esquina → dividir el offset por el factor de zoom en el effect.
- **`onDelete` sin robar el click de la fila**: el ✕ es un `Button` hijo con `frameLevel`
  mayor y su propio `OnClick`; la fila comprueba `MouseIsOver(deleteBtn)` o el ✕ hace
  `StopPropagation` (en WoW: manejar el click en el ✕ y no propagar — botones separados ya no
  comparten el evento).
- **`avatar` — ciclo de vida (FR-065)**: el `Craft.Avatar` vive en el **bundle de la fila
  pooleada** y se crea **lazy** la primera vez que esa fila lo necesita (`_ensureAvatar`) — nunca
  uno por rebuild: `AttachContextMenu` reconstruye en cada apertura y `Craft.Avatar` crea
  `MaskTexture`s (regla #132 de [FR-062](../requests/FR-062-avatar-avatargroup.md): nada de
  máscaras colgando de filas que no muestran retrato). En rebuilds se **reusa** el mismo objeto
  (`SetAtlas`/`SetImage`/`SetFallback`), se **oculta** si la fila se recicla como otro tipo, y
  `Menu:Destroy()` llama a `avatar:Destroy()` de cada fila del pool. La altura por fila ya la
  devuelve `_renderRow` (el `separator` ya devolvía la suya), así que las alturas mixtas 28/36
  no necesitan refactor; sí hay que estirar la hit-area del ✕ a la altura real de la fila.
- **Radios por `group`**: el menú mantиene un mapa `group → value` vivo; al seleccionar una
  fila radio, actualiza el mapa, refresca los discos de todas las filas del mismo grupo, y
  dispara `onSelect(value)`. Si `checked` es señal, `applyOrBind` la refleja.
- **Ancho auto por fila heterogénea**: medir cada fila (`GetStringWidth` de label + rightText +
  huecos de indicador/icono/delete) y tomar el `max`, con piso `min-w-32`. Re-medir dentro de
  `_applyTheme` (fuente async en primer arranque — AGENTS §9).
- **Strata TOOLTIP** (decisión FR): el panel debe quedar sobre `Window`/`Dialog` (strata
  `DIALOG`). Catcher un escalón por debajo (`FULLSCREEN_DIALOG`).
- **Sin focus ring / navegación por teclado** (WoW mouse-only, ADR-0011). Esc sí aplica (cierra).

### Diferencias conocidas vs shadcn

- **Un `Craft.Menu` = `DropdownMenu` + `ContextMenu`** (misma anatomía; solo cambia el
  disparador). No se replican dos componentes.
- **`onDelete` (✕ por fila)** y **`avatar` (retrato leading)**: extensiones de Craft, no existen
  en shadcn `dropdown-menu` (el avatar del account-switcher vive en el markup del bloque).
- **Submenús y `Group`**: diferidos (v1 usa `heading`+`separator` para agrupar; `submenu` no-op).
- **Config declarativa plana** (`items[]` con `type`) en vez del árbol de subcomponentes JSX de
  shadcn — coherente con el resto de componentes de Craft (Select, Sidebar).

---

## Arranque de implementación (handoff — listo para codear)

> Todo lo de esta sección ya está resuelto contra Lyra; no re-derivar. Requiere luz verde del
> maintainer (componente nuevo, AGENTS §8). Empezar por `feat/menu` desde `dev`.

### Constantes (copiar tal cual al tope de `Menu.lua`)

```lua
-- Geometría verificada contra style-lyra.css (2026-07-09). 1 Tailwind unit = 4px.
local ROW_H        = 28   -- fila item/checkbox/radio/heading (py-2×2 + text-xs=12)
local PANEL_PAD    = 4    -- p-1 (padding interno del panel, del base .tsx)
local ITEM_PL      = 8    -- px-2 (item plano, izq)
local ITEM_PR      = 8    -- px-2 (item plano, der)
local CR_PL        = 8    -- pl-2 (checkbox/radio, izq)
local CR_PR        = 32   -- pr-8 (checkbox/radio, reserva indicador derecho)
local IND_RIGHT    = 8    -- right-2 (indicador a la DERECHA — decisión (a))
local GAP          = 8    -- gap-2 (icono → label)
local CHECK_SIZE   = 14   -- size-3.5 (glyph check/minus)
local RADIO_DOT    = 8    -- size-2 (disco dot; ver RadioGroup GUTTER_COMP)
local ICON_SIZE    = 16   -- size-4
local DELETE_SIZE  = 12   -- ✕ (extensión Craft)
local SEP_MY       = 4    -- my-1 (margen vertical del separator, del base)
local FONT_SIZE    = 12   -- text-xs
local MIN_W        = 128  -- min-w-32 (dropdown; context usa 144)
-- Ring del panel: t.foreground a=0.10 (idéntico a Select). Fondo: t.popover.
```

### Mapa de reuso (qué copiar/adaptar y de dónde)

| Necesito | Fuente | Anclas aprox. |
|---|---|---|
| Panel popover (UIParent, ring 1px + bg popover, `SetClipsChildren`) | `Select.lua` | ~103-125 |
| Fade + zoom + slide (un solo progreso Weave) | `Select.lua` | ~127-183 |
| Cierre por click-fuera (base; sustituir por catcher fullscreen) | `Select.lua` | ~209-221 |
| Factory de fila + pooling por índice (`_makeItem`/`_buildItems`) | `Select.lua` | ~259-358 |
| Cálculo de tamaño de panel + scroll | `Select.lua` | ~451-470 |
| `Open`/`Close` (anclaje, scale-compensation, re-arm mouse) | `Select.lua` | ~473-540 |
| Indicador check/minus (checkbox, tri-estado) | `Checkbox.lua` | glyphs `check`/`minus` |
| Discos radio (ring/fill/dot, `GUTTER_COMP`, glyph `disc`) | `RadioGroup.lua` | ~22-35 |
| Esc vía `UISpecialFrames` (frame con NOMBRE) | `Dialog.lua` | ~231-233 |
| Iconos disponibles | atlas | `check`, `minus`, `chevron-right`, `x` |

### Checklist por fases

1. **Esqueleto + contrato §5** — `Create(config)` (sin `parent`), `_applyTheme`, `Destroy`
   (guarda `if not self.frame`, `disposeAll`, `unregister`). `Craft.register("Menu", Menu, _BUILD)`.
2. **Panel base** — adaptar panel de Select (ring+bg popover, scroll, fade/zoom/slide). Sin trigger.
3. **Filas por tipo** — factory `_makeRow(type)` (heading/separator/item/checkbox/radio); pooling
   por índice con `_count`; `_buildRows` sólo fluye datos y reposiciona. Indicador **derecha**.
4. **item rico** — icono izq, `rightText` der (muted), `variant="destructive"`, `onDelete` ✕
   (Button hijo frameLevel+1, no dispara `onClick`).
5. **checkbox/radio** — tri-estado (check/minus) y discos radio; mapa `group→value` vivo.
6. **Apertura/cierre** — `Open(anchor, opts)` + `OpenAtCursor()` (flip si sale de pantalla);
   catcher fullscreen (`FULLSCREEN_DIALOG`) + Esc; `disposeAll` en **Close** (no en Destroy).
7. **`AttachContextMenu(frame, builder)`** — hook click-derecho; `builder()` reconstruye items.
8. **Ancho auto** — `w-fit` (max por fila) con piso `MIN_W`, o `width` fijo; re-medir en `_applyTheme`.
9. **Props reactivas** — `applyOrBind` para `label`/`checked`/`disabled` por entrada.

### Tests (`tests/menu_spec.lua`, mini-runner + busted)

- Construye por `type` correcto (heading/separator/item/checkbox/radio) y respeta `#items`.
- Pooling: rebuild con menos items oculta el excedente (no crea frames nuevos; `_count` correcto).
- Radio: seleccionar en un `group` deselecciona los demás del mismo grupo; `onSelect(value)` dispara.
- Checkbox: `onToggle(on)` alterna; tri-estado (`"indeterminate"`) pinta `minus`.
- `onClick` no se dispara si se clickea el ✕ (`onDelete`).
- `OpenAtCursor` (FR-061): con `GetCursorPosition`/`UIParent:GetEffectiveScale` mockeados,
  `_anchorX/_anchorY == cursor/uiEff` **independiente de la escala previa del panel**; con
  `scaleRef` propio, `cursor/refEff` y `panelBaseScale == refEff/uiEff`.
- `disabled` (literal y señal) suprime callbacks.
- `Open`/`Close` togglea visibilidad; `Close` corre `disposeAll` (sin ghost-updates al reabrir).
- Señales Weave en `checked`/`label`/`disabled` se reflejan (patrón `reactive_spec`).

### Verificación (invocaciones reales, CLAUDE.md §Comandos)

```bash
luac -p Craft/components/Menu.lua
luacheck Craft/*.lua Craft/components/*.lua Craft/theme/*.lua Craft/layout/*.lua Craft/icons/*.lua --config .luacheckrc
"/c/Program Files/nodejs/node.exe" /c/Users/Usuario/Documents/Workspace/taintlint/dist/cli.js Craft --min-severity warning
lua tests/run.lua tests/menu_spec.lua tests/button_spec.lua tests/reactive_spec.lua tests/theme_spec.lua
bash scripts/bump-build.sh   # antes de release (MINOR — nuevo componente)
```

### Cierre (no auto-hacer — reportar al maintainer)

- Añadir `Craft.Menu` a `Craft/Craft.toc` (orden de carga tras Select/Checkbox/RadioGroup).
- Página demo en `Craft_Browser/pages/` (los 6 casos de Coffer como showcase).
- Fila en `CHANGELOG.md` (MINOR, nuevo componente). Bump `CRAFT_BUILD`.
