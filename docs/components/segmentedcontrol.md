# Component: SegmentedControl

> Referencia shadcn: **`toggle-group`** (con `spacing=0` y selección única) — Craft lo expone
> como `Craft.SegmentedControl`. Es el control que el RFC-009 llamaba "SegmentedControl".
> CSS: `.cn-toggle-group`, `.cn-toggle-group-item`, `.cn-toggle`, `.cn-toggle-size-default`.

## CSS de referencia (Lyra)

```css
.cn-toggle              { @apply rounded-none text-xs font-medium hover:text-foreground
                                data-[state=on]:bg-muted transition-all gap-1; }
.cn-toggle-size-default { @apply h-8 min-w-8 px-2.5; }
.cn-toggle-group        { @apply rounded-none; }
.cn-toggle-group-item   { @apply group-data-[spacing=0]/toggle-group:px-2 ...rounded-none; }
```

(grouped con `spacing=0` los items comparten bordes — `px-2` en vez de `px-2.5`.)

## Propósito

Selección **única** mostrada como una barra de segmentos conectados (display Barra/Icono/Texto,
modo de trigger). Alternativa compacta y horizontal al `RadioGroup`/`Select`.

## Jerarquía de frames WoW

```
segmented.frame              (Frame — h-8, ancho = suma de segmentos)
├── _borderT/B/L/R            (Texture 1px — border-input, caja exterior)
└── seg[i]                    (Button — un segmento)
    ├── bg                    (Texture BACKGROUND — bg-muted, visible si activo)
    ├── iconTex (opcional)    (Texture ARTWORK — icono Lucide size-4)
    ├── fs                    (FontString — text-xs font-medium, centrado)
    └── divider               (Texture BORDER 1px — border-input, salvo el último)
```

## Dimensiones / tokens

| Elemento | Valor / Token |
|---|---|
| Altura | 32px (`h-8`) |
| Padding H por segmento | 8px (`px-2`, grouped spacing=0) |
| Ancho mínimo segmento | 32px (`min-w-8`) |
| Icono | 14px (`size-4`), gap 4px (`gap-1`) |
| Font | `t.fontBold` (font-medium), 12px (`text-xs`) |
| Borde / dividers | `t.input` (`border-input`) |
| Fondo activo | `t.muted` (`data-[state=on]:bg-muted`) |
| Texto activo | `t.foreground` |
| Texto inactivo | `t.mutedForeground` |
| Texto hover | `t.foreground` |

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

- **Conectado (spacing=0)**: una sola caja `border-input`, con dividers verticales de 1px entre
  segmentos. Los segmentos se dimensionan al contenido (`text + 2·px-2`, mínimo `min-w-8`).
- **Activo**: `data-[state=on]:bg-muted` → relleno `t.muted` + texto `t.foreground`. Inactivo
  `t.mutedForeground`; hover lleva a `t.foreground` (`hover:text-foreground`).
- **font-medium** → `t.fontBold` (Craft solo trae Regular + Bold).
- **Iconos** opcionales por segmento (`icon = "<lucide>"`), tintados al color del texto.
- **Variante `outline` y `spacing` ≠ 0** del ToggleGroup no se implementan (sin caso de uso en
  Sentry); añadir si se necesita selección múltiple o segmentos separados.
