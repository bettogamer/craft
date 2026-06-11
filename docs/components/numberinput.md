# Component: NumberInput

> **Craft-original** — shadcn **no** tiene number input / stepper (no hay clases `.cn-*`
> para spinners numéricos). Se diseña con el estilo de form-control de Craft (idéntico a
> `Input`: `border-input`, `bg-input/30`, `text-xs`, `rounded-none`, `h-8`) más una columna
> de stepper ▲▼ a la derecha. WoW frame base: `Frame` + `EditBox` + 2 `Button`.

## Propósito

Campo **numérico** para configuración (posición x/y, tamaño, duración, recuento). El valor se
edita escribiendo directamente o con las flechas ▲▼ / rueda del mouse, que avanzan por `step`.
Los valores escritos se **clampan** a `[min, max]` al confirmar (Enter / perder foco); las
flechas siempre clampan.

## Jerarquía de frames WoW

```
numberinput.frame      (Frame — borde + fondo, h-8)
├── _borderT/B/L/R       (Texture — 1px cada una, t.input; t.ring en focus)
├── _bg                  (Texture — inset 1px, input/30)
├── _sep                 (Texture — 1px vertical antes de la columna stepper, t.input)
├── _edit                (EditBox — single-line; inset derecho = STEP_W)
├── _up   + _upTex       (Button + chevron-up,   mitad superior derecha)
└── _down + _downTex     (Button + chevron-down, mitad inferior derecha)
```

## Dimensiones / tokens

| Elemento | Valor / Token |
|---|---|
| Altura | 32px (`h-8`) |
| Padding H | 10px (`px-2.5`) |
| Columna stepper | 16px de ancho |
| Ícono stepper | `chevron-up` / `chevron-down` @ 10px |
| Font | `t.font`, 12px (`text-xs`) |
| Borde default | `t.input` (`border-input`) |
| Borde focus | `t.ring` |
| Fondo | `input/30` (`t.input.a * 0.30`) |
| Fondo disabled | `input/80` (`* 0.80`) |
| Texto | `t.foreground`; disabled `t.mutedForeground` |
| Ícono stepper | `t.mutedForeground` (default) → `t.foreground` (hover) |

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|---|---|---|---|
| `value` | number | `min` o `0` | Valor inicial (clampado) |
| `min` | number | nil | Mínimo (nil = sin tope inferior) |
| `max` | number | nil | Máximo (nil = sin tope superior) |
| `step` | number | 1 | Incremento de flechas/rueda (admite decimales) |
| `width` | number | 100 | Ancho del frame |
| `disabled` | boolean | false | Deshabilita el campo |
| `onChange` | function | nil | `fn(value)` al cambiar el valor (flechas, rueda, commit) |

## API pública

| Método | Descripción |
|---|---|
| `SetValue(v[, silent])` | Fija el valor (clampado); `silent=true` no dispara `onChange` |
| `GetValue()` | Retorna el valor actual (number) |
| `SetRange(min, max)` | Cambia los topes y re-clampa |
| `SetEnabled(bool)` | Habilita/deshabilita |
| `GetFrame()` | Frame raíz |

## Notas de implementación

- **Sin `SetNumeric`**: WoW `EditBox:SetNumeric(true)` solo admite enteros positivos; para
  soportar decimales y negativos se valida a mano con `tonumber` en el commit.
- **Commit**: `OnEnterPressed` / `OnEditFocusLost` parsean el texto; si es número válido →
  `SetValue` (clampa + reformatea con `%g` + `onChange`), si no → revierte al valor actual.
  `Escape` revierte y quita el foco.
- **No se snapea el texto al step** — escribir 7 con `step=5` deja 7 (solo clampa); las flechas
  hacen `±step`. Es el comportamiento estándar de un spinner web.
- **Rueda del mouse** sobre el frame hace `±step`. Click en el padding enfoca el EditBox.
- **Border-input** (no `t.border`), igual que Input/Textarea/Checkbox/Select.
- **Formato `%g`** quita ceros sobrantes (`5.0` → `5`, `5.5` → `5.5`).
