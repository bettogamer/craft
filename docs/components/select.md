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
| Max items visibles   | 6 (max height ≈ 168px)                                         |
| Scroll               | `ScrollFrame` activo cuando items > 6                          |
| Padding interno      | 4px top/bottom del panel (antes del primer item)               |
| Separación del trigger | 2px de gap (`SetPoint("TOPLEFT", trigger, "BOTTOMLEFT", 0, -2)`) |

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
| Chevron           | Normal (0°), `t.mutedForeground`        | Rotado 180°, `t.foreground`             | `t.mutedForeground`   |

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

## API pública

| Método                  | Descripción                                                                    |
|-------------------------|--------------------------------------------------------------------------------|
| `SetValue(value)`       | Selecciona la opción con ese value. Actualiza `selectedLabel`. No dispara `onSelect` |
| `GetValue()`            | Retorna el value actualmente seleccionado, o `nil`                             |
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
- **ScrollFrame de items**: cuando `#options > 6`, activar el `ScrollFrame` con altura fija ≈ 168px (6 × 28px). El `scrollChild` tiene `SetHeight(#options * 28)`. Cada item usa `SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i-1) * 28)`.
- **Item hover**: usar `OnEnter`/`OnLeave` en cada frame de item para cambiar el color del `itemBg`. El item selected se marca visualmente aunque el panel se cierre y reabra — recordar el índice seleccionado y aplicar color `t.primary` al crear los items.
- **Borde 1px trigger**: cuatro texturas de 1px o `SetBackdrop` con `edgeSize=1`.
- **Ring del panel (1px outward)**: frame hermano del panel, anclado con −1px en cada lado. Usar `Craft.Theme.SetPixelHeight/Width` para las cuatro aristas. Color: {r=0.980, g=0.980, b=0.980, a=0.10}.
- **Trigger bg dark mode**: la textura bg del trigger usa alpha calculado: default `a=0.045` ({r=1,g=1,b=1}), hover `a=0.075`. Cambiar `SetVertexColor` o `SetAlpha` de la textura en OnEnter/OnLeave. No aplicar hover si el panel está abierto o si `disabled`.
- **Separación visual**: el panel abre con 2px de separación del trigger (`SetPoint("TOPLEFT", trigger, "BOTTOMLEFT", 0, -2)`).
- **Sin focus ring en trigger**: WoW es mouse-only (ADR-0011) — no implementar ring de keyboard en el trigger.

### Diferencias conocidas vs shadcn (fuera de MVP)

Craft.Select solo soporta una **lista plana** de opciones `{value, label}`. shadcn
ofrece además `SelectGroup`, `SelectLabel` y `SelectSeparator` (opciones agrupadas
con encabezados y separadores). No implementados — omisión de alcance MVP, no bug
(ver `docs/design-reference.md` §9.1). El item seleccionado se marca solo con
checkmark, igual que shadcn.
