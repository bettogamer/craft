# FR-042 — `Craft.Tabs` variante `line`: indicador de subrayado en vez de fondo

**Reportado por:** Port del popover "Clone repository" de shadcn a Craft_Browser (2026-07-18)
**Componente:** `Craft/components/Tabs.lua` (shadcn: `tabs` — `data-variant="line"`)
**Tipo:** Feature (nueva variante de API pública — requiere aprobación del maintainer)
**Prioridad:** Media (bloquea fidelidad del demo Clone; hay fallback: usar variante default degradada)
**Estado:** ✅ Implementado (2026-07-18). `variant="line"` en `Craft/components/Tabs.lua`;
tests en `tests/tabs_spec.lua` (11 casos); spec `docs/components/tabs.md` y `design-reference.md
§9.1` actualizados. Demo "Clone repository" (Anexo A) materializado en
`Craft_Browser/pages/Panel.lua` como **Card** (`Craft.Panel` sin título — el contenedor real del
ejemplo es `data-slot="card"`, no Popover; movido desde Popover.lua el 2026-07-18): Card → Tabs
default+`fill` anidado + Tabs `line` + Field + acciones ghost. Pendiente: verificación in-game +
bump/release/re-vendoreo por el owner.

---

## Problema

shadcn Tabs tiene dos variantes de barra: la **default** (fondo `muted`, la tab activa se
diferencia por su propio fondo) — ya implementada en Craft — y **`line`**
(`data-variant="line"`): la barra es transparente con una línea inferior completa, y la tab
activa se marca con un **subrayado de 2px** bajo su trigger en vez de un fondo.

El caso concreto que lo destapó es el popover **"Clone repository"** de GitHub (bloque HTML
pegado por el owner para portar a Craft_Browser). Ese ejemplo anida **dos** Tabs:

1. Selector superior Codespaces/Local → variante **default** (`bg-muted`) → ✅ ya reproducible.
2. Selector interno HTTPS/SSH/GitHub CLI → variante **`line`** (`bg-transparent` + `border-b`,
   subrayado activo) → ❌ **no reproducible hoy**; cae al estilo default (fondo muted), que
   diverge visiblemente del ejemplo.

**Escenario:** portar cualquier UI de shadcn que use `<Tabs variant="line">` (patrón muy común
para sub-navegación dentro de una card) → Craft solo ofrece la barra con fondo, sin el subrayado.

## Solución propuesta

Añadir un parámetro `variant` a `Craft.Tabs:Create` con valores `"default"` (actual, por defecto)
y `"line"`. El modelo de layout, wrap, show/hide de content y API pública **no cambian**; solo
cambia el pintado de la barra y del estado activo.

### Diferencias `line` vs `default` (derivadas de las clases del HTML pegado)

| Aspecto | `default` (actual) | `line` (nuevo) |
|---|---|---|
| Fondo de la barra (`_listBg`) | `t.muted` | **transparente** (sin textura de fondo, o a=0) |
| Línea inferior de la barra (`_listBorder`) | 1px `t.border` (ya existe) | 1px `t.border` full-width (**se conserva**, es el `border-b`) |
| Padding interno de la barra | `p-[3px]` | sin el `p-[3px]` (la lista no tiene fondo que rellenar); triggers pegados al borde inferior |
| Separación entre triggers | wrap Flex (auto) | **`gap-1` = 4px** explícito entre triggers |
| Alineación | left (`justify-start`) | left (`justify-start`) — igual |
| Estado activo | fondo diferenciado del trigger | **subrayado de 2px** en `t.foreground`, alineado a la línea inferior; **sin** fondo |
| Estado inactivo | texto `t.mutedForeground`, fondo transparente | texto `t.mutedForeground`, **sin** subrayado (opacity 0) |
| Hover | fondo `t.accent` | texto → `t.foreground` (sin fondo; `hover:text-foreground`) |

### Indicador de subrayado (la pieza nueva)

Del HTML: cada trigger `line` lleva un pseudo-elemento `after:` que es el subrayado —
`after:bg-foreground after:h-0.5 after:inset-x-0 after:bottom-[-5px]`, `after:opacity-0` por
defecto y `data-active:after:opacity-100`. Traducción a WoW:

- Crear **una textura `_underline` de 2px** por trigger (o una compartida que se reposiciona bajo
  el trigger activo — decisión de implementación), pintada con `t.foreground`.
- Ancho = ancho del trigger (content-width), anclada al borde inferior del trigger, **coincidiendo
  con la línea `_listBorder`** de la barra (el `bottom-[-5px]` la sienta sobre esa línea).
- Alto de 2px pixel-perfect vía `Craft.Theme.SetPixelHeight(_underline, 2)` (ADR-0011).
- Visible solo bajo el trigger activo; en los inactivos, oculta (o a=0).

> **Nota de fidelidad:** esta variante **sí** tiene indicador de línea, a diferencia de la
> default (la nota "Lyra tabs NO tienen indicador de línea" en `tabs.md:44` aplica **solo** a la
> variante default). Actualizar esa nota para acotarla a `variant="default"` al implementar.

## Alcance mínimo (MVP)

- Solo el eje **horizontal** (el del ejemplo). La orientación **vertical** sigue fuera de alcance
  (§9.1) — no se aborda aquí.
- `variant="line"` + `variant="default"`. Sin variantes adicionales.
- Reutiliza todo el motor existente (Flex wrap, auto-width por trigger, show/hide, icon slots).

## Consideraciones de implementación

- **No romper la API actual:** `variant` es opcional con default `"default"`; el código y los
  tests existentes de Tabs siguen pasando sin cambios.
- **`_listBg` transparente:** en `line`, o no crear la textura de fondo o pintarla con a=0; el
  `_listBorder` (1px) **se conserva** en ambas variantes (es el `border-b`).
- **Subrayado vs wrap:** si los triggers hacen wrap a varias filas (poco probable con 3 tabs, pero
  el motor lo permite), el subrayado debe seguir al trigger activo en su fila. Anclar el underline
  al propio trigger (no a la barra) lo resuelve gratis.
- **Pixel-perfect:** subrayado 2px y `_listBorder` 1px con `Craft.Theme.SetPixelHeight` (ADR-0011),
  re-aplicado en `_applyTheme` (los grosores dependen de escala, no de fuente).
- **Tests:** añadir casos a `tests/tabs_spec.lua` — `variant="line"` crea underline y no crea
  fondo muted; el underline sigue a `SetActiveTab`; default sin `variant` no regresiona.
- **Spec:** actualizar `docs/components/tabs.md` (nueva sección de variante, acotar la nota de
  "sin indicador" a default) y quitar la fila `line` de la tabla §9.1 de `design-reference.md`.

## Fallback mientras tanto

El demo Clone (fila en `Craft_Browser/pages/Panel.lua`, como Card) puede materializarse **antes** de
este FR usando `Craft.Tabs` default para el selector HTTPS/SSH/CLI, con un comentario marcando la
degradación. Al cerrar este FR, cambiar ese Tabs a `variant="line"` para lograr fidelidad total.

## Referencias

- Spec del componente: [`docs/components/tabs.md`](../components/tabs.md) (gap en líneas 68-77)
- Omisión de alcance: `docs/design-reference.md §9.1` (fila Tabs)
- Origen del port: popover "Clone repository" (shadcn), HTML pegado por el owner 2026-07-18

---

## Anexo A — Receta completa del demo "Clone repository" (para materializar tras cerrar este FR)

> Persistido aquí para no depender del HTML original ni de re-mapear. Destino: **fila nueva en
> `Craft_Browser/pages/Panel.lua`** (el "Clone repository" real de shadcn es contenido de un **Card**,
> `data-slot="card"` — ver esqueleto abajo con `Craft.Panel`, NO Popover). Lo materializa
> **browser-demo-writer** cuando el variant `line` exista.

### Estructura visual (de arriba a abajo)

Card (≈320px ancho) → solo `card-content`, sin header:

1. **Tabs superior** (variante **default**, `bg-muted`, full-width): `Codespaces` | `Local`
   (activa = Local). Sin iconos.
2. Dentro de "Local", un **Item** (fila): icono `terminal` (16px) + label "Clone" (izquierda) +
   botón ghost `size=icon` con icono `info` a la derecha (era un tooltip-trigger; en Craft =
   `Button{variant=ghost,size=icon,icon="info",tooltip=...}`).
3. **Tabs interno** (variante **`line`** — ESTE FR): `HTTPS` | `SSH` | `GitHub CLI` (activa =
   HTTPS). Barra transparente, subrayado bajo la activa.
4. Dentro de "HTTPS", un contenedor con borde redondeado y fondo `bg-muted/30`, que contiene un
   **Field** (label `sr-only` → omitir label en Craft) con:
   - **Input readonly** `value="https://github.com/shadcn-ui/ui.git"` + botón `copy` embebido a la
     derecha (input-group addon `inline-end`). Aproximación Craft: `Input{iconTrailing="copy",
     onTrailingClick=...}`.
   - **Descripción**: "Clone using the web URL."
5. **Separator** horizontal.
6. Dos **Button** `variant=ghost size=sm`, icono a la izquierda, apilados full-width alineados a la
   izquierda: `monitor` "Open with GitHub Desktop" · `download` "Download ZIP".

### Iconos usados (todos ya en el atlas)

`terminal` (Atlas.lua:517), `info` (588), `copy` (877), `monitor` (1057), `download` (1576).

### Llamadas Craft (esqueleto que dio el mapper)

```lua
-- Card
local card = Craft.Panel:Create(parent, { width = 320, height = 280 })

-- Tabs superior (default)
local outerTabs = Craft.Tabs:Create(card:GetContent(), {
    tabs = { {id="codespaces",label="Codespaces"}, {id="local",label="Local"} },
    defaultTab = "local",
})

-- Item "Clone" (MANUAL — no hay Craft.Item): Frame + icono terminal + Label + Button info
--   icon: Craft.Icons.Apply(tex, "terminal", 16)
--   Craft.Label:Create(f, {text="Clone"})
--   Craft.Button:Create(f, {variant="ghost", size="icon", icon="info", tooltip="More info"})

-- Tabs interno (variant="line" cuando exista este FR; hasta entonces default = degradado)
local innerTabs = Craft.Tabs:Create(itemFrame, {
    tabs = { {id="https",label="HTTPS"}, {id="ssh",label="SSH"}, {id="cli",label="GitHub CLI"} },
    defaultTab = "https",
    -- variant = "line",   -- ← activar al cerrar FR-042
})

-- Input readonly + copy embebido (aprox. de input-group)
local urlInput = Craft.Input:Create(innerTabs:GetContentFrame("https"), {
    value = "https://github.com/shadcn-ui/ui.git",
    iconTrailing = "copy",
    onTrailingClick = function() --[[ ver nota clipboard ]] end,
})
local field = Craft.Field:Create(innerTabs:GetContentFrame("https"), {
    control = urlInput,
    description = "Clone using the web URL.",
    -- label omitido a propósito (equivale a sr-only)
})

-- Separator
local sep = Craft.Separator:Create(card:GetContent(), { orientation = "horizontal" })

-- Botones ghost sm, apilados, alineados a la izquierda
Craft.Button:Create(card:GetContent(), {variant="ghost", size="sm", icon="monitor",
    iconPosition="left", text="Open with GitHub Desktop"})
Craft.Button:Create(card:GetContent(), {variant="ghost", size="sm", icon="download",
    iconPosition="left", text="Download ZIP"})
```

### Divergencias WoW a respetar en la demo

- **`readonly` no existe** en `Craft.Input` (solo `disabled`, que grisea → NO usarlo para simular
  readonly, diverge del readonly real de shadcn que muestra texto normal). Candidato a FR aparte.
- **Clipboard:** WoW no expone API de portapapeles a addons. El botón `copy` es cosmético; patrón
  estándar = `EditBox:HighlightText()` + foco (el jugador hace Ctrl+C). No inventar `SetClipboard`.
- **Foco (ADR-0011):** el Input de la URL es un EditBox real → SÍ aplica el focus-ring Lyra en los
  4 bordes (no omitir, a diferencia de Button/Tabs que son mouse-only).

## Anexo B — Gaps del mismo ejemplo NO levantados como FR (candidatos)

Detectados por el mapper en este HTML; se componen a mano / degradan en la demo. Registrar como FR
propio solo si el patrón se repite en más ports (precedente: `clearable` = FR-016):

1. **`Craft.Item`** — fila "icono + título + acciones" (`item-content` / `item-actions`). Hoy se
   reconstruye a mano en cada page (aparece con variantes propias en Menu/DragList). Evaluar
   generalizar.
2. **`Craft.InputGroup`** — input con addon/botón **visualmente fusionado con borde propio
   segmentado**. `Input.iconTrailing`+`onTrailingClick` solo da un icono clickeable sin borde. FR
   aparte si Coffer/Beacon necesitan el botón segmentado real.
3. **`readonly` en `Craft.Input`** — flag para mostrar valor no editable con estilo normal (texto
   sin gris), distinto de `disabled`. FR aparte si aparece en más demos.
- Relacionados: icon slots (implementado v1.1, precedente de extensión no disruptiva de Tabs)
