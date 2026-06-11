# Component: RadioGroup

> Referencia shadcn: `radio-group` — existe en Lyra.
> CSS: `.cn-radio-group` (`grid gap-2`), `.cn-radio-group-item`, `.cn-radio-group-indicator(-icon)`.

## CSS de referencia (Lyra)

```css
.cn-radio-group { @apply grid gap-2; }

.cn-radio-group-item {
  @apply border-input dark:bg-input/30 data-checked:bg-primary data-checked:border-primary
         data-checked:text-primary-foreground focus-visible:border-ring focus-visible:ring-ring/50
         flex size-4 rounded-full focus-visible:ring-3;
}

.cn-radio-group-indicator      { @apply flex size-4 items-center justify-center; }
.cn-radio-group-indicator-icon { @apply bg-primary-foreground absolute top-1/2 left-1/2
                                        size-2 -translate-x-1/2 -translate-y-1/2 rounded-full; }
```

## Propósito

Selección **única** dentro de un conjunto de opciones (tipo de display, modo de trigger).
Equivale a un grupo de `<input type=radio>`. Apilado vertical con `gap-2` (8px).

## Nota de diseño: el radio es el único `rounded-full` de Lyra

Lyra fija `--radius: 0` → todo es cuadrado (Button, Input, Checkbox, Slider thumb…). El radio
es la **excepción**: `rounded-full` (círculo). WoW no tiene primitiva redondeada, así que cada
radio se compone de tres **discos** = una textura `WHITE8X8` enmascarada con el mask circular
estándar de Blizzard `Interface\Masks\CircleMaskScalable` y tintada con `SetVertexColor`:

```
_ring (16px disc)  — border-input        / primary             (seleccionado)
_fill (14px disc)  — input/30            / primary             (seleccionado)  ← 1px ring visible
_dot  (8px disc)   — (oculto)            / primary-foreground  (seleccionado)
```

No se viola el invariante Radius=0: el radio es `rounded-full` **en el propio shadcn Lyra**, no
una esquina redondeada de un control cuadrado.

## Jerarquía de frames WoW

```
radiogroup.frame          (Frame — alto = n·16 + (n-1)·8)
└── row[i]                 (Button — clic selecciona; ancho = 16 + 8 + label)
    ├── _ring              (Texture BACKGROUND — disco 16px, masked)
    ├── _fill              (Texture BORDER     — disco 14px, masked)
    ├── _dot               (Texture ARTWORK    — disco 8px, masked, solo seleccionado)
    └── _label             (FontString — text-xs)
```

## Dimensiones / tokens

| Elemento | Valor / Token |
|---|---|
| Radio | 16px (`size-4`), círculo |
| Dot (indicador) | 8px (`size-2`) |
| Gap radio↔label | 8px (`gap-2`) |
| Gap entre items | 8px (grid `gap-2`) |
| Font label | `t.font`, 12px (`text-xs`) |
| Ring default | `t.input` (`border-input`) |
| Ring seleccionado | `t.primary` |
| Fill default | `input/30` (`t.input.a * 0.30`) |
| Fill seleccionado | `t.primary` |
| Dot | `t.primaryForeground` |
| Label | `t.foreground`; disabled `t.mutedForeground` |

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|---|---|---|---|
| `options` | table | `{}` | Lista de `{ value, label }` |
| `value` | any | nil | Valor seleccionado inicial |
| `width` | number | nil | Ancho fijo; nil = ancho del label más largo |
| `disabled` | boolean | false | Deshabilita todo el grupo |
| `onChange` | function | nil | `fn(value)` al seleccionar |

## API pública

| Método | Descripción |
|---|---|
| `SetValue(v[, silent])` | Selecciona un valor; `silent=true` no dispara `onChange` |
| `GetValue()` | Valor seleccionado |
| `SetEnabled(bool)` | Habilita/deshabilita el grupo |
| `GetFrame()` | Frame raíz |

## Notas de implementación

- **Dependencia WoW**: `Texture:SetMask("Interface\\Masks\\CircleMaskScalable")` sobre
  `SetTexture("Interface\\Buttons\\WHITE8X8")` + `SetVertexColor`. Mask escalable estándar de
  retail; el color se aplica por vertex-color (no `SetColorTexture`, que no samplea el mask).
- **Selección única**: clic en una fila fija `_value` y refresca todas (la previa se apaga).
- **border-input** (no `t.border`), igual que el resto de form-controls.
- Sin estado `error` por ahora (el CSS lo soporta vía `aria-invalid`); añadir si Sentry lo pide.
