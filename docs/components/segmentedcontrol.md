# Component: SegmentedControl

> Referencia shadcn: **`toggle-group`** (selección única) — Craft lo expone como
> `Craft.SegmentedControl`. Es el control que el RFC-009 llamaba "SegmentedControl".
> Se replica el render real de la página de shadcn: **`variant=outline`, `spacing=1`** →
> segmentos **separados**, cada uno con su propio borde, con un gap de 4px.

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

## Jerarquía de frames WoW

```
segmented.frame              (Frame — h-8, w-fit; ancho = Σ segmentos + gaps)
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
| `options` | table | `{}` | Lista de `{ value, label, icon? }` |
| `value` | any | nil | Valor seleccionado inicial |
| `disabled` | boolean | false | Deshabilita el control |
| `onChange` | function | nil | `fn(value)` al seleccionar |

## API pública

| Método | Descripción |
|---|---|
| `SetValue(v[, silent])` | Selecciona un segmento; `silent=true` no dispara `onChange` |
| `GetValue()` | Valor seleccionado |
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
- **Selección múltiple** y la variante **conectada** (`spacing=0`, bordes compartidos) del
  ToggleGroup no se implementan (sin caso de uso en Sentry); añadir si se necesitan.
