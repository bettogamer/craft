# Component: ToggleGroup

> Referencia shadcn: **`toggle-group`** — Craft lo expone como `Craft.ToggleGroup` (mismo
> nombre que shadcn; el RFC-009 lo llamaba "SegmentedControl"). Implementa el subset de
> **selección única**. Se replica el render real de la página: **`variant=outline`,
> `spacing=1`** → segmentos **separados**, cada uno con su propio borde, con un gap de 4px.

## CSS de referencia (Lyra) — render real de la página

```css
.cn-toggle                 { @apply rounded-none text-xs font-medium hover:text-foreground
                                   data-[state=on]:bg-muted transition-all gap-1; }
.cn-toggle-variant-outline { @apply border-input border bg-transparent hover:bg-muted; }
.cn-toggle-size-default    { @apply h-8 min-w-8 px-2.5; }
/* group: variant=outline, spacing=1 → gap = spacing(1) = 4px, w-fit */
```

El HTML renderizado: cada `toggle-group-item` lleva `cn-toggle-variant-outline` (borde propio,
`bg-transparent`) y los botones `on`/`off` tienen **clases idénticas** salvo `data-state` — el
único cambio de estado es `data-[state=on]:bg-muted`. El hover también es `bg-muted`.

## Propósito

Selección **única** mostrada como una fila de segmentos con borde (display Barra/Icono/Texto,
modo de trigger). Alternativa compacta y horizontal al `RadioGroup`/`Select`.

## Animación ([Unreleased])

Como shadcn (`transition-all`), el ToggleGroup **anima** el relleno (hover + selección) **por segmento** usando `Weave.tween` (ADR-0013 §4.6). Cada segmento reacciona a dos señales: `onSig` (seleccionado) y `hoverSig` (hover); ambas disparan el mismo relleno `t.muted` (no hay distinción visual: checked y hovered comparten color). El alpha interpola suavemente entre 0 (idle) y 1 (filled) en ~150ms. Por eficiencia, los segmentos se **reciclan** en un pool de frames, cada uno con su propio tween+effect que sigue siendo válido al re-usarse con nuevos datos. Los endpoints se cachean en `_applyTheme` y se re-aplican al progreso vigente en cambios de tema (AGENTS §9).

## Jerarquía de frames WoW

```
togglegroup.frame            (Frame — h-8, w-fit; ancho = Σ segmentos + gaps)
└── seg[i]                    (Button — un segmento, separado 4px del siguiente)
    ├── border bT/bB/bL/bR    (Texture 1px — border-input, caja PROPIA del segmento)
    ├── bg                    (Texture BACKGROUND — bg-muted, inset 1px; visible si activo/hover)
    ├── iconTex (opcional)    (Texture ARTWORK — icono Lucide size-4)
    └── fs                    (FontString — text-xs font-medium, centrado)
```

## Dimensiones / tokens

| Elemento | Valor / Token |
|---|---|
| Altura | 32px (`h-8`) |
| Padding H por segmento | 10px (`px-2.5`) |
| Ancho mínimo segmento | 32px (`min-w-8`) |
| Gap entre segmentos | 4px (`spacing(1)`) |
| Icono | 14px (`size-4`), gap 4px (`gap-1`) |
| Font | `t.fontBold` (font-medium), 12px (`text-xs`) |
| Borde (por segmento) | `t.input` (`border-input`) |
| Fondo activo / hover | `t.muted` (`data-[state=on]:bg-muted` / `hover:bg-muted`) |
| Texto | `t.foreground` siempre (disabled `t.mutedForeground`) |

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|---|---|---|---|
| `options` | table | `{}` | Lista de `{ value, label, icon?, tooltip? }` |
| `value` | any | nil | Valor seleccionado inicial |
| `disabled` | boolean | false | Deshabilita el control |
| `onChange` | function | nil | `fn(value)` al seleccionar |

> **Props reactivas (ADR-0013):** `options`, `value` y `disabled` aceptan señal/computed.
> `options` re-renderiza reutilizando segmentos por índice (un segmento reciclado puede
> ganar/perder su icono); `value` es two-way.

## API pública

| Método | Descripción |
|---|---|
| `SetValue(v[, silent])` | Selecciona un segmento; `silent=true` no dispara `onChange` |
| `GetValue()` | Valor seleccionado |
| `SetOptions(options)` | Reemplaza la lista y re-renderiza (segmentos reutilizados). Conserva la selección si sigue presente; no dispara `onChange` |
| `SetEnabled(bool)` | Habilita/deshabilita |
| `GetFrame()` | Frame raíz |

## Notas de implementación

- **Separados (outline + spacing=1)**: cada segmento es su propia caja `border-input` (4×1px),
  `bg-transparent`, separadas por un gap de 4px. Se dimensionan al contenido (`text + 2·px-2.5`,
  mínimo `min-w-8`).
- **Relleno**: `data-[state=on]:bg-muted` y `hover:bg-muted` comparten color (`t.muted`); el
  relleno se muestra si el segmento está **activo o con hover** (`_setSegFill`). El texto es
  `t.foreground` siempre (los botones on/off solo difieren en `data-state`).
- **font-medium** → `t.fontBold` (Craft solo trae Regular + Bold).
- **Iconos** opcionales por segmento (`icon = "<lucide>"`), tintados al color del texto.
- **Tooltips** opcionales por segmento (`tooltip = "texto"`); muestran `Craft.Tooltip` en hover, incluso si el segmento está disabled.
- **Selección múltiple** y la variante **conectada** (`spacing=0`, bordes compartidos) del
  ToggleGroup no se implementan (sin caso de uso en Sentry); añadir si se necesitan.
