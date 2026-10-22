# Component: Select

> Referencia shadcn: `select` — WoW frame base: `Frame` (dropdown custom)

## CSS de referencia (Lyra)

```css
.cn-select-trigger {
  @apply border-input data-placeholder:text-muted-foreground dark:bg-input/30 dark:hover:bg-input/50
         gap-1.5 rounded-none border bg-transparent py-2 pr-2 pl-2.5 text-xs
         data-[size=default]:h-8 data-[size=sm]:h-7
         [&_svg:not([class*='size-'])]:size-4;
}
.cn-select-content {
  @apply bg-popover text-popover-foreground ring-foreground/10 min-w-36 rounded-none shadow-md ring-1 duration-100;
}
.cn-select-item {
  @apply focus:bg-accent focus:text-accent-foreground gap-2 rounded-none py-2 pr-8 pl-2 text-xs;
}
.cn-select-label {
  @apply text-muted-foreground px-2 py-2 text-xs;
}
.cn-select-separator {
  @apply bg-border -mx-1 h-px;
}
```

## Propósito

Selector de opción única con trigger visible y panel dropdown flotante, implementado completamente en Lua ya que WoW no provee un widget select nativo moderno.

## Animación ([Unreleased])

Panel fade + `zoom-in-95` + `slide-in-from-top` (ADR-0013 §4.6): alpha eases 0→1 (Close la invierte 1→0), escala y slide reutilizan el mismo progreso. **Zoom se MULTIPLICA sobre la compensación de escala del contenedor** (`triggerEff/uiParentEff`) en lugar de reemplazarla — el panel siempre compensa si el trigger está en un frame escalado (p. ej. Craft_Browser a 0.75x), y el pop suma el zoom encima. Slide eases `motionSlide` px desde el top (signo= +1 downward), con gancho `_panelSlideDir` listo para invertir si algún día se implementa apertura hacia arriba. **Al cerrar**: inmediatamente disables mouse en los items (antes de que la fade termine) para que el panel fading no capture clics a la UI de fondo.

## Jerarquía de frames WoW

```
Frame (trigger root)                — MEDIUM strata
├── Texture (bg)                    — BACKGROUND layer, t.input fill
├── Texture (border)                — BORDER layer, 1px, t.border
├── FontString (selectedLabel)      — OVERLAY layer, padding izq 10px, truncado con "…"
├── Texture (chevronNormal)         — ARTWORK layer, 16×16px, 8px desde borde derecho
├── Texture (chevronRotated)        — ARTWORK layer, 16×16px, misma posición, oculto por defecto
└── (sin ring en trigger — el panel open se diferencia solo por border color)

Frame (dropdownPanel)               — TOOLTIP strata (siempre sobre otros frames)
├── Texture (bg)                    — BACKGROUND layer, t.popover fill
├── Frame (ring)                    — frame separado 1px outward, t.foreground a=0.10
├── Frame (arrowUp)                 — banda 24px al borde superior, solo si hay contenido arriba
│   ├── Texture (bg)                — BACKGROUND layer, t.popover opaco
│   └── Texture (chevron-up)        — ARTWORK layer, 16×16px centrado
├── Frame (arrowDown)               — ídem al borde inferior (solo si hay contenido abajo)
└── ScrollFrame (itemScroll)        — ARTWORK layer
    └── Frame (scrollChild)
        └── Frame (item) × N        — 28px alto cada uno (py-2=8px + text-xs=12px + py-2=8px)
            ├── Texture (itemBg)    — BACKGROUND layer, transparent por defecto
            └── FontString (itemLabel) — OVERLAY layer, pl-2=8px izq, pr-8=32px der (espacio checkmark)
```

## Dimensiones

### Tamaños del trigger

| Tamaño    | Height | Padding izq (pl-2.5) | Padding der (pr-2) | Padding V (py-2) | Gap ícono |
|-----------|--------|----------------------|--------------------|------------------|-----------|
| `sm`      | 28px   | 10px                 | 8px                | 8px              | 6px       |
| `default` | 32px   | 10px                 | 8px                | 8px              | 6px       |

Solo dos tamaños: `sm` (h-7=28px) y `default` (h-8=32px). No existe variante `lg`.

El padding es asimétrico: `pl-2.5` (10px) a la izquierda, `pr-2` (8px) a la derecha — el chevron ocupa el espacio derecho reservado.

El `selectedLabel` se extiende desde 10px del borde izquierdo hasta 8px + 16px (chevron) del borde derecho.

Width del trigger: 100% del parent por defecto (puede fijarse con `config.width`).

### Panel dropdown

| Propiedad            | Valor                                                          |
|----------------------|----------------------------------------------------------------|
| Width                | igual al width del trigger (min-w-36 = 144px mínimo)          |
| Height por item      | 28px (py-2=8 + text-xs=12 + py-2=8)                           |
| Max items visibles   | `config.maxItems`, default 6 (max-height ≈ 168px)              |
| Scroll               | `ScrollFrame` activo cuando items > `maxItems`; rueda + flechas |
| Height del panel     | `min(items, maxItems) × 28 + 2` — **no cambia** al scrollear   |
| Padding interno      | 4px top/bottom del panel (antes del primer item)               |
| Separación del trigger | 2px de gap (`SetPoint("TOPLEFT", trigger, "BOTTOMLEFT", 0, -2)`) |

### Scroll del panel (FR-066)

Cuando `#options > maxItems` el panel scrollea y lo anuncia. Tres vías, ninguna excluyente:

| Vía | Comportamiento |
|-----|----------------|
| Rueda del ratón | 2 filas (56px) por muesca, clampeada. Enganchada en el `ScrollFrame`, en el panel y en las dos bandas de flecha → no hay zona muerta |
| Flechas ▲/▼ (`SelectScrollUpButton` / `SelectScrollDownButton`) | Bandas de 24px (`py-1` + chevron `size-4`) pegadas al borde interior del panel. Hover = auto-scroll continuo a 112 px/s (`ITEM_HEIGHT × 4`) |
| `Open()` | Abre desplazado hasta la fila seleccionada (scroll mínimo: si la fila ya entra bajo la banda inferior, el offset es 0) |

**Semántica Radix, literal.** Cada banda existe **solo mientras hay contenido en su dirección**
(la de arriba aparece al scrollear, la de abajo desaparece al final del recorrido) y **quita
espacio al viewport** en vez de superponerse:

| Offset | Bandas montadas | Viewport |
|--------|-----------------|----------|
| `0` (arriba del todo) | solo ▼ | `maxItems × 28 − 24` |
| intermedio | ▲ y ▼ | `maxItems × 28 − 48` |
| `_maxScroll()` (abajo del todo) | solo ▲ | `maxItems × 28 − 24` |

De ahí que el recorrido máximo sea `contentH − maxItems×28 + 24` (el estado final tiene una sola
banda) y que una lista que scrollea muestre una **fila parcial asomando** — la otra mitad del
affordance de shadcn, junto con la flecha. La altura del panel no cambia nunca: `maxItems × 28`
es el *max-height*, igual que en Radix. Los tres estados son auto-consistentes con el clamp
(`canUp = offset > 0`, `canDown = offset < max`), así que no oscilan.

### Ring del panel (outline outward)

El panel usa `ring-1 ring-foreground/10` — se implementa como un frame hermano de 1px hacia afuera del panel, no como ring del trigger.

| Propiedad   | Valor                                                             |
|-------------|-------------------------------------------------------------------|
| Offset      | −1px en cada lado (1px outward del panel)                         |
| Width       | 1px — usar `Craft.Theme.SetPixelHeight/Width(ringFrame, 1)`       |
| Color       | `t.foreground` al 10% = {r=0.980, g=0.980, b=0.980, a=0.10}      |
| Visibilidad | Siempre visible mientras el panel esté abierto                    |

El trigger NO tiene ring propio — el estado "open" se expresa solo con cambio de border color.

## Variantes visuales

| Elemento          | Estado default                          | Estado open                             | Estado disabled       |
|-------------------|-----------------------------------------|-----------------------------------------|-----------------------|
| Trigger bg        | `t.input` a=0.30 ({r=1,g=1,b=1,a=0.045}) | `t.input` a=0.30                      | igual + `SetAlpha(0.5)` |
| Trigger bg hover  | `t.input` a=0.50 ({r=1,g=1,b=1,a=0.075}) | —                                     | —                     |
| Trigger border    | `t.input` (`border-input`)              | `t.ring`                                | `t.input`             |
| selectedLabel     | `t.foreground`                          | `t.foreground`                          | `t.mutedForeground`   |
| Chevron           | Normal (0°), `t.mutedForeground`        | `chevron-up`, `t.mutedForeground` (swap de ícono, sin rotación — ver §Notas)             | `t.mutedForeground`   |

Los fondos del trigger dark mode corresponden a `dark:bg-input/30` (default) y `dark:hover:bg-input/50` (hover), donde `input = {r=1,g=1,b=1,a=0.15}`:
- `/30` → a=0.15×0.30 = 0.045
- `/50` → a=0.15×0.50 = 0.075

## Estados

### Trigger

| Estado     | Bg                                | Border     | Label               | Chevron                              |
|------------|-----------------------------------|------------|---------------------|--------------------------------------|
| Default    | {r=1,g=1,b=1,a=0.045} (input/30) | `t.input` | `t.foreground`      | `chevron-down`, `t.mutedForeground`  |
| Hover      | {r=1,g=1,b=1,a=0.075} (input/50) | `t.input` | `t.foreground`      | `chevron-down`, `t.mutedForeground`  |
| Open       | {r=1,g=1,b=1,a=0.045} (input/30) | `t.ring`   | `t.foreground`      | `chevron-up`, `t.mutedForeground`    |
| Disabled   | input/30 + `SetAlpha(0.5)`        | `t.input` | `t.mutedForeground` | `t.mutedForeground`                  |

No hay focus ring en el trigger (WoW es mouse-only — ADR-0011).

Placeholder (sin valor seleccionado): `selectedLabel` muestra `config.placeholder` con color `t.mutedForeground`.

### Items del dropdown

| Estado    | Bg              | Label color             |
|-----------|-----------------|-------------------------|
| Default   | Transparent     | `t.popoverForeground`   |
| Hover     | `t.accent`      | `t.accentForeground`    |
| Selected  | Transparent (checkmark visible) | `t.popoverForeground` |

> **Item seleccionado = solo checkmark** (como shadcn). No lleva fondo `t.primary`; se distingue de los demás únicamente por el checkmark a la derecha. (En una versión previa llevaba fondo emerald; se alineó a shadcn.)

Item height: 28px (py-2=8px top + text-xs=12px + py-2=8px bottom). Padding: 8px izq (pl-2), 32px der (pr-8, reserva para checkmark de item seleccionado).

## Mapa de tokens

| Elemento                        | Token / Valor                                          |
|---------------------------------|--------------------------------------------------------|
| Trigger bg default              | `t.input` a×0.30 = {r=1,g=1,b=1,a=0.045}              |
| Trigger bg hover                | `t.input` a×0.50 = {r=1,g=1,b=1,a=0.075}              |
| Trigger border default          | `t.input` ({r=1,g=1,b=1,a=0.15}, `border-input`)       |
| Trigger border open             | `t.ring`                                               |
| Trigger bg disabled             | input/30 + `SetAlpha(0.5)` en el frame                 |
| Label seleccionado              | `t.foreground`                                         |
| Placeholder label               | `t.mutedForeground`                                    |
| Chevron default                 | `t.mutedForeground`                                    |
| Chevron open                    | `t.foreground`                                         |
| Label disabled                  | `t.mutedForeground`                                    |
| Panel bg                        | `t.popover` = {r=0.091,g=0.091,b=0.091}               |
| Panel ring (outline 1px outward)| `t.foreground` a=0.10 = {r=0.980,g=0.980,b=0.980,a=0.10} |
| Item bg hover                   | `t.accent`                                             |
| Item label hover                | `t.accentForeground`                                   |
| Item seleccionado               | checkmark visible (sin fondo) — ver nota arriba        |

## Config — `Create(parent, config)`

| Parámetro    | Tipo       | Default     | Descripción                                                                 |
|--------------|------------|-------------|-----------------------------------------------------------------------------|
| `options`    | `table`    | `{}`        | Array de `{value, label}`. Ejemplo: `{{value="en", label="English"}, ...}`  |
| `value`      | `string`   | `nil`       | Valor inicial seleccionado. `nil` muestra el placeholder                    |
| `placeholder`| `string`   | `"Select…"` | Texto en `selectedLabel` cuando no hay valor seleccionado                   |
| `size`       | `string`   | `"default"` | `"sm"` (28px) o `"default"` (32px). No existe `"lg"`.                      |
| `disabled`   | `boolean`  | `false`     | Deshabilita el trigger y cierra el panel si estaba abierto                  |
| `onSelect`   | `function` | `nil`       | `fn(value, label)` — se dispara al seleccionar un item                      |
| `width`      | `number`   | `nil`       | Ancho fijo en px. Si es nil, ocupa 100% del parent                          |
| `maxItems`   | `number`   | `6`         | Filas visibles antes de scrollear (mínimo 1). No limita cuántas opciones se pueden elegir — el resto se alcanza con rueda/flechas (FR-066) |
| `multiple`   | `boolean`  | `false`     | FR-121: selección múltiple (Base UI `Select multiple`). Clicar un item lo marca/desmarca **sin cerrar** |
| `values`     | `table`    | `{}`        | FR-121, con `multiple`: conjunto inicial `{ [value] = true }` (o array `{ "a", "b" }`). Se copia: la tabla del caller nunca se muta |
| `onChange`   | `function` | `nil`       | FR-121, con `multiple`: `fn(values)` en cada toggle del usuario, con una tabla **nueva** `{ [value] = true }` |

> **Props reactivas (ADR-0013):** `options`, `value`, `placeholder` y `disabled` aceptan una
> señal/computed de Weave además del literal. `options` re-renderiza la lista reutilizando
> frames por índice; `value` es two-way (elegir un item escribe de vuelta si es escribible).
> `values` (FR-121) igual: two-way con una señal escribible (cada toggle escribe una tabla nueva).

### Selección múltiple (FR-121)

Referencia: el `Select` de shadcn sobre **Base UI** acepta `multiple` (Radix no). Fidelidad:

- **Mismo trigger, mismos items, mismo indicador**: el `check` a la derecha (pr-8) marca cada
  opción elegida. **No** se usan casillas — Base UI pinta el `ItemIndicator` de siempre.
- Clicar un item **alterna** su check y deja el popup abierto; Esc o un clic fuera lo cierran.
- Trigger: labels elegidos **en el orden de `options`**, separados por `", "`, en una línea
  truncada con elipsis (`line-clamp-1`); placeholder (muted) si no hay ninguno. Un value que no
  está en `options` se muestra crudo al final (igual que `SetValue` con un value desconocido).
- Al abrir, el scroll va a la **primera** opción elegida.
- `SetValues`/programático nunca dispara `onChange` (como `SetValue`/`onSelect`).

## API pública

| Método                  | Descripción                                                                    |
|-------------------------|--------------------------------------------------------------------------------|
| `SetValue(value)`       | Selecciona la opción con ese value. Actualiza `selectedLabel`. No dispara `onSelect` |
| `GetValue()`            | Retorna el value actualmente seleccionado, o `nil`                             |
| `SetValues(values)`     | FR-121 (`multiple`): reemplaza el conjunto (`{ [v] = true }` o array). No dispara `onChange` |
| `GetValues()`           | FR-121 (`multiple`): copia del conjunto `{ [v] = true }` actual                |
| `SetOptions(options)`   | Reemplaza la lista de opciones. Cierra el panel si estaba abierto              |
| `SetEnabled(bool)`      | Habilita/deshabilita el componente                                             |
| `Open()`                | Abre el panel dropdown programáticamente                                       |
| `Close()`               | Cierra el panel dropdown                                                       |
| `GetFrame()`            | Retorna el frame trigger raíz                                                  |

## Notas de implementación

- **Sin widget nativo**: WoW no tiene un `DropdownMenu` moderno suficientemente personalizable. Todo el dropdown se construye con frames, texturas y FontStrings.
- **Strata del panel**: el `dropdownPanel` debe usar `SetFrameStrata("TOOLTIP")` para aparecer siempre sobre otros frames de la UI (barras de acción, otros paneles, etc).
- **Cierre al hacer click fuera**: registrar un frame invisible (`backdropCatcher`) de tamaño de pantalla completa en strata `DIALOG` pero debajo del panel. Al hacer click en él, cerrar el dropdown. Alternativa: hookear `WorldFrame` con `HookScript("OnMouseDown", ...)` y verificar si el click fue fuera del panel y el trigger. Usar `panel:IsMouseOver()` y `trigger:IsMouseOver()` para la comprobación.
- **Posición del panel**: anclar con `SetPoint("TOPLEFT", trigger, "BOTTOMLEFT", 0, -2)`. Si el panel se sale de la pantalla por abajo, anclar con `SetPoint("BOTTOMLEFT", trigger, "TOPLEFT", 0, 2)` en su lugar. Verificar con `GetBottom()` vs `GetScreenHeight() * 0` (0 = bottom de pantalla).
- **Chevron abierto/cerrado**: se usan dos íconos Lucide distintos — `chevron-down` (cerrado) y `chevron-up` (abierto) — intercambiados con `Craft.Icons.Apply` en `Open()`/`Close()`. No se rota la textura.
- **ScrollFrame de items**: cuando `#options > maxItems`, el `ScrollFrame` se re-ancla en cada cambio de offset (`_layoutViewport`), porque sus insets dependen de qué bandas están montadas. El `scrollChild` tiene `SetHeight(#options * 28)`. Cada item usa `SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i-1) * 28)`.
- **Recorrido del scroll**: las alturas se **calculan** (`maxItems × 28` menos las bandas montadas), NO se leen del `ScrollFrame` — un frame anclado por esquinas no tiene altura resuelta hasta el frame siguiente, y `GetHeight()` devolvería 0 en el mismo tick en que se abre el panel.
- **Bandas de flecha**: `Frame` (no `Button`) con `EnableMouse(true)` — solo necesitan hover y tragarse el clic que caería en el item de debajo. El auto-scroll vive en un `OnUpdate` que arma `OnEnter` y desarma `OnLeave`; `Close()` y el `OnHide` del panel también lo desarman (si el panel desaparece bajo el cursor, `OnLeave` no dispara). Las bandas pierden el mouse durante el fade-out igual que los items.
- **Ancho del label del item**: `_itemTextWidth()` es la **única** fuente (`max(anchoTrigger, 144) − 2 − pl-2 − pr-8`), y `_updatePanelSize` la re-aplica a todas las filas pooleadas en cada `Open()`. Imprescindible porque el patrón normal del consumidor es `Create(...)` y **después** `SetWidth(...)`: la primera pasada de `_buildItems` (dentro de `_applyTheme`, en `Create`) mide un trigger de ancho 0 y cae al suelo `min-w-36`, así que sin re-aplicar, un Select de 240px trunca sus labels como si midiera 144.
- **Una sola línea por fila**: el label del item lleva ancho explícito (`availW`) y el del trigger lo hereda de sus anclas LEFT+RIGHT — y un `FontString` **con ancho envuelve por defecto**, así que sin `SetWordWrap(false)` + `SetNonSpaceWrap(false)` una etiqueta larga dibuja una segunda línea que se sale de la fila de 28px y pisa el item siguiente. Con el wrap desactivado WoW trunca con elipsis, que es el equivalente del item flex de shadcn y del `[&>span]:line-clamp-1` del trigger.
- **Item hover**: usar `OnEnter`/`OnLeave` en cada frame de item para cambiar el color del `itemBg`. El item selected se marca visualmente aunque el panel se cierre y reabra — recordar el índice seleccionado y aplicar color `t.primary` al crear los items.
- **Borde 1px trigger**: cuatro texturas de 1px o `SetBackdrop` con `edgeSize=1`.
- **Ring del panel (1px outward)**: frame hermano del panel, anclado con −1px en cada lado. Usar `Craft.Theme.SetPixelHeight/Width` para las cuatro aristas. Color: {r=0.980, g=0.980, b=0.980, a=0.10}.
- **Trigger bg dark mode**: la textura bg del trigger usa alpha calculado: default `a=0.045` ({r=1,g=1,b=1}), hover `a=0.075`. Cambiar `SetVertexColor` o `SetAlpha` de la textura en OnEnter/OnLeave. No aplicar hover si el panel está abierto o si `disabled`.
- **Separación visual**: el panel abre con 2px de separación del trigger (`SetPoint("TOPLEFT", trigger, "BOTTOMLEFT", 0, -2)`).
- **Sin focus ring en trigger**: WoW es mouse-only (ADR-0011) — no implementar ring de keyboard en el trigger.
- **Esc cierra el panel** (FR-121, Radix/Base UI dismiss on Escape): el panel es un frame con
  nombre (`CraftSelectPanelN`) registrado en `UISpecialFrames` durante toda la vida del Select
  (`CloseSpecialWindows` ignora los ocultos) y retirado en `Destroy`. Blizzard lo oculta con
  `Hide()` directo, saltándose el fade: el `OnHide` reconcilia (`_escHidden` + `Close()`) para que
  el bind `shown` no lo vuelva a enseñar durante el fade-out. No se registra/desregistra en
  `Open`/`Close`: mutaría `UISpecialFrames` desde el propio `OnHide` que dispara su iteración.

### Diferencias conocidas vs shadcn (fuera de MVP)

**Ancho del panel: Craft lo capa, shadcn lo deja crecer.** En shadcn el viewport lleva
`min-w-[var(--radix-select-trigger-width)]`, o sea que el ancho del trigger es un **mínimo**: el
content crece hasta el ancho intrínseco del label más largo y **nunca trunca**. Craft usa
`max(anchoTrigger, 144)` como ancho **fijo**, así que un label que no cabe se corta con elipsis
(una sola línea — ver "Una sola línea por fila"). Decisión del owner (2026-07-28): se mantiene el
cap; un panel más ancho que su trigger descuadraría las columnas de formulario de los
consumidores. Si algún día se quiere paridad, el cambio es medir con `GetStringWidth` en
`_buildItems` y usar ese máximo, topado al borde de pantalla.

Craft.Select solo soporta una **lista plana** de opciones `{value, label}`. shadcn
ofrece además `SelectGroup`, `SelectLabel` y `SelectSeparator` (opciones agrupadas
con encabezados y separadores). No implementados — omisión de alcance MVP, no bug
(ver `docs/design-reference.md` §9.1). El item seleccionado se marca solo con
checkmark, igual que shadcn.
