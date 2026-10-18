# Component: Checkbox

> Referencia shadcn: `checkbox` — https://ui.shadcn.com/docs/components/checkbox
> WoW frame base: `Frame` (no hay widget checkbox nativo en WoW)

## CSS de referencia (Lyra)

```css
.cn-checkbox {
  @apply border-input dark:bg-input/30 data-checked:bg-primary data-checked:text-primary-foreground
         dark:data-checked:bg-primary data-checked:border-primary
         aria-invalid:border-destructive dark:aria-invalid:border-destructive/50
         flex size-4 items-center justify-center rounded-none border
         transition-colors focus-visible:ring-1 aria-invalid:ring-1;
}
.cn-checkbox-indicator {
  @apply [&>svg]:size-3.5;
}
```

## Propósito
Control de selección binaria (marcado/desmarcado) con soporte para estado indeterminado, label opcional y detección de errores de validación.

## Animación ([Unreleased])

Como shadcn v4, el Checkbox **anima** la transición de estado usando `Weave.tween` (ADR-0013 §4.6). Los cambios no snappean: el relleno (fondo + borde) interpola entre input/30 (unchecked) → primary (checked) y el check hace fade de alpha.

Los tres estados **no se reducen a un solo eje**, así que hay **dos tweens** (una señal privada `_checkedSig` captura la tri-state y ambas la observan computada):

| tween    | 0                    | 1                      | qué pinta                    |
|----------|----------------------|------------------------|------------------------------|
| `_fill`  | unchecked **+ indeterminate** | checked       | fondo, borde y tinte del glyph |
| `_iconA` | unchecked            | checked **+ indeterminate** | alpha del check          |

Con un único progreso (la primera implementación) indeterminate compartía endpoints con checked y salía rellenado de accent — ver "Estado indeterminado" abajo. El tinte del glyph (`foreground` ↔ `primaryForeground`) se interpola con `_fill`, que es justo el eje que separa ambos casos; en unchecked el alpha es 0, así que el color es indiferente. Los endpoints se cachean en `_applyTheme` y se re-aplican al progreso vigente en cambios de tema (AGENTS §9); `_refreshVisual` repinta también al progreso vivo, porque un cambio que no mueve ningún tween (`SetError`) no re-dispara el effect.

## Jerarquía de frames WoW

```
checkbox.frame          (Frame — nivel raíz, contiene box + label, recibe eventos de ratón)
├── checkbox._box       (Frame — BACKGROUND) contenedor del cuadro visual exterior
│   ├── _box._bg        (Texture — BACKGROUND) fondo interior del cuadro (transparent o primary)
│   ├── _box._border    (Texture — BORDER)     borde de 1px (SetPixelHeight/Width)
│   └── _box._check     (Texture — ARTWORK)    ícono "check" Lucide 14×14, centrado en _box
└── checkbox._label     (FontString — OVERLAY) texto opcional a la derecha del box
```

Sin frame `_ring` — no se implementa focus ring en WoW (mouse-only).

`checkbox.frame` es un Frame genérico que actúa como contenedor interactivo; los eventos `OnMouseDown`/`OnMouseUp` se registran aquí para simular el comportamiento de checkbox. `_box` contiene el cuadro visible y sus estados. `_check` es la textura del checkmark (ícono Lucide "check") que se muestra u oculta según el estado. Es el **único** glyph del componente: el estado indeterminado pinta el MISMO check (ver "Estado indeterminado" abajo).

## Dimensiones

### Tamaños

Lyra define un único tamaño para `checkbox` (`size-4`). No hay variante `lg` en el CSS real.

| Propiedad         | Valor   | Fuente Tailwind      |
|-------------------|---------|----------------------|
| Box               | 16×16px | `size-4`             |
| Border radius     | 0       | `rounded-none`       |
| Border            | 1px     | `border`             |
| Checkmark (indicator) | 14×14px | `size-3.5` (en `.cn-checkbox-indicator svg`) |
| Hit-area (interactiva) | 40×32px | `after:-inset-x-3 after:-inset-y-2` |

- El checkmark indicator es 14px (no 10px). Viene de `[&>svg]:size-3.5` en `.cn-checkbox-indicator`.
- El box actúa como contenedor flex centrado (`flex items-center justify-center`); el indicator se posiciona automáticamente.
- Gap entre el borde derecho del `_box` y el inicio del `_label`: `spacingSm` = 8px.
- La altura del `checkbox.frame` se ajusta automáticamente al mayor de: box height o label height.

### Hit-area (FR-055)

Lyra agranda el target del checkbox más allá del box visual con un pseudo-elemento
`::after` de inset negativo (`after:-inset-x-3 after:-inset-y-2` = 12px por lado horizontal,
8px vertical), dando **40×32px** reales con el box en 16×16.

En WoW el equivalente exacto es **`SetHitRectInsets` con valores negativos** (expanden el
rect de mouse del frame). Se implementa así — y no con un frame hitbox hijo — porque, igual
que el pseudo-elemento, queda **fuera del flujo de layout**: no altera `GetWidth`/`GetHeight`,
así que `Craft.Field`, `Craft.Flex` y `Craft.Grid` siguen midiendo el box real y el apilado no
se mueve. La expansión se aplica una vez en `Create()` y no necesita recálculo:

```lua
self.frame:SetHitRectInsets(-12, -12, -8, -8)   -- L, R, T, B
```

Con label el frame ya abarca `box + gap + texto`, así que el margen de 12px se añade también
después del texto. El margen vertical (8px por lado, 16px totales) es menor que el gap de
`Craft.FieldGroup` (20px), por lo que dos checkboxes apilados nunca solapan sus hit-areas.

Complemento práctico: el label de `Craft.Field` también acciona el control (ver
[`field.md`](field.md), FR-056).

### Variantes visuales (estados del checkbox)

| Estado         | Borde `_box`                        | Fondo `_box._bg`                         | Checkmark visible |
|----------------|-------------------------------------|------------------------------------------|--------------------|
| unchecked      | {r=1,g=1,b=1,a=0.15} (`t.input`, `border-input`) | {r=1,g=1,b=1,a=0.045} (`input/30`)      | no                 |
| checked        | `t.primary`                         | `t.primary`                              | sí                 |
| indeterminate  | {r=1,g=1,b=1,a=0.15} (`t.input`, igual que unchecked) | {r=1,g=1,b=1,a=0.045} (`input/30`, igual que unchecked) | sí (check en `t.foreground`) |
| disabled       | opacity 0.5 sobre estado base       | opacity 0.5 sobre estado base            | según estado base  |
| error          | `t.destructive`                     | {r=1,g=1,b=1,a=0.045} (`input/30`)      | no                 |

## Estados

| Estado        | Borde                               | Fondo interior                        | Texto label         |
|---------------|-------------------------------------|---------------------------------------|---------------------|
| unchecked     | {r=1,g=1,b=1,a=0.15}               | {r=1,g=1,b=1,a=0.045}                | `t.foreground`      |
| checked       | `t.primary`                         | `t.primary`                           | `t.foreground`      |
| indeterminate | {r=1,g=1,b=1,a=0.15}                | {r=1,g=1,b=1,a=0.045}                 | `t.foreground`      |
| disabled      | estado base a opacity 0.5           | estado base a opacity 0.5             | `t.mutedForeground` |
| error         | `t.destructive`                     | {r=1,g=1,b=1,a=0.045}                | `t.foreground`      |

Notas sobre estados:
- **Focus ring**: NO implementar en WoW (mouse-only, sin keyboard navigation). El `focus-visible:ring-1` de Lyra no aplica.
- **Disabled**: `group-has-disabled/field:opacity-50` → aplicar `SetAlpha(0.5)` al frame `_box` completo, no cambiar colores individualmente.
- Los estados `disabled` + `checked` combinados: aplicar `SetAlpha(0.5)` al box con fondo y borde de `t.primary`, y el checkmark visible pero atenuado.
- El estado `error` solo afecta el borde; el label puede recibir un texto de error externo (no gestionado por el componente).

## Mapa de tokens

| Elemento visual               | Token / Valor dark mode                        |
|-------------------------------|------------------------------------------------|
| Borde del box (unchecked)     | `t.input` = {r=1,g=1,b=1,a=0.15} (`border-input`) |
| Fondo del box (unchecked)     | input/30 = {r=1,g=1,b=1,a=0.045}              |
| Borde del box (checked)       | `t.primary` = {r=0.000,g=0.378,b=0.271}       |
| Fondo del box (checked)       | `t.primary` = {r=0.000,g=0.378,b=0.271}       |
| Borde del box (error)         | `t.destructive` = {r=1.000,g=0.391,b=0.404}   |
| Disabled                      | `SetAlpha(0.5)` en `_box`                      |
| Checkmark                     | `t.primaryForeground` = {r=0.924,g=0.992,b=0.960} |
| Texto del label               | `t.foreground` = {r=0.980,g=0.980,b=0.980}    |
| Texto del label (disabled)    | `t.mutedForeground` = {r=0.630,g=0.630,b=0.630} |

## Config — `Create(parent, config)`
| Clave      | Tipo     | Default      | Descripción                                                        |
|------------|----------|--------------|--------------------------------------------------------------------|
| `checked`  | boolean  | `false`      | Estado inicial del checkbox. `nil` activa estado indeterminado.   |
| `disabled` | boolean  | `false`      | Si `true`, suprime interacción y aplica estilo disabled.           |
| `label`    | string   | `nil`        | Texto opcional mostrado a la derecha del box.                      |
| `size`     | string   | `"default"`  | Solo `"default"` (16px box). Lyra no define variante `lg`.         |
| `onChange` | function | `nil`        | Callback `function(checked)` donde `checked` es `true`, `false` o `nil` (indeterminado). |

## API pública
| Método               | Firma                    | Descripción                                                                          |
|----------------------|--------------------------|--------------------------------------------------------------------------------------|
| `SetChecked(value)`  | `boolean|nil → void`    | Actualiza el estado: `true`=checked, `false`=unchecked, `nil`=indeterminado. Dispara `onChange`. |
| `GetChecked()`       | `→ boolean|nil`         | Devuelve el estado actual: `true`, `false` o `nil`.                                  |
| `Toggle()`           | `→ void`                | Invierte el estado como un clic del usuario: dispara `onChange` **y** escribe el signal two-way (`config.checked` writable), cosa que `SetChecked` no hace. No-op si está `disabled`. Lo usa el label clickable de `Craft.Field` (FR-056). |
| `SetEnabled(enabled)`| `boolean → void`         | Activa o desactiva la interacción y el estilo.                                       |
| `SetLabel(text)`     | `string → void`          | Cambia el texto del label. Pasa `nil` o `""` para ocultar el label.                  |
| `SetError(hasError)` | `boolean → void`         | Activa/desactiva el estado de error (borde `t.destructive`).                         |
| `GetFrame()`         | `→ Frame`                | Devuelve el frame WoW raíz para posicionamiento externo.                             |

## Notas de implementación

**Sin widget nativo**: WoW no tiene un frame `CheckButton` equivalente al checkbox web. Se construye con un `Frame` genérico que registra `OnMouseDown` para toggle. El `CheckButton` nativo de WoW existe pero tiene estilos heredados del juego difíciles de neutralizar; usar `Frame` limpio es más predecible.

**Checkmark Lucide**: El ícono "check" de Lucide se carga desde el atlas de la librería. La textura `_box._check` usa `SetAtlas("lucide-check")` o coordenadas UV del spritesheet `lucide-16.tga`. El indicator mide **14×14px** (`size-3.5`). El estado indeterminado reutiliza esta misma textura (FR-054); no hay una textura de guion.

**Borde del box**: No usar 9-slice. El borde se implementa como 4 texturas de 1px: top, right, bottom, left, dentro de `_box` con `SetPoint` absoluto. Alternativamente, usar un Frame con backdrop si el contexto lo permite, pero la solución con 4 texturas es más fiel al estilo Lyra.

**Sin focus ring en WoW**: el `focus-visible:ring-1` de Lyra no se implementa. WoW es mouse-only, sin keyboard navigation. No crear el frame `_ring`.

**Propagación del click a toda el área**: Registrar `OnMouseDown` en `checkbox.frame` completo (no solo `_box`) para que hacer clic en el label también active el checkbox. Esto mejora la usabilidad y es consistente con shadcn.

**Estado indeterminado con `nil`**: Al recibir `SetChecked(nil)`, mostrar `_check` pero **NO rellenar
el box de accent**: el chrome es el de unchecked (borde `t.input`, fondo `input/30`, o sea el card
visible a través) y el check se tiñe con `t.foreground`. Internamente guardar el estado como `nil`,
no como `false`.

> **El glyph es un check, el relleno NO es accent (FR-054 + corrección 2026-07-20).**
> shadcn base usa `MinusIcon` para indeterminate, y Craft lo copió sin verificar. El markup Lyra
> real renderiza el mismo `<svg class="lucide lucide-check">` en ambos estados, sin regla CSS que lo
> sustituya — confirmado visualmente por el owner: en la doc de Lyra nunca aparece un guion.
>
> Lo que la primera pasada asumió de más fue que, al compartir glyph, indeterminate era
> **visualmente idéntico a checked**. Es falso: la regla de relleno está **scopeada a
> `[data-state="checked"]`**, así que indeterminate no la matchea y cae al `.cn-checkbox` base:
>
> ```css
> .style-lyra .cn-checkbox:where([data-state="checked"]),
> .style-lyra .cn-checkbox:where([data-checked]:not([data-checked="false"]))
>   { border-color: var(--primary); background-color: var(--primary); color: var(--primary-foreground); }
> ```
>
> Corroborado por el **computed del indicator en indeterminate**: `color` = `oklch(0.987 0.002
> 197.1)` = `--foreground`, NO `--primary-foreground` (`oklch(0.984 0.019 200.873)`) — si la regla de
> checked hubiera aplicado, el glyph heredaría primary-foreground. El owner lo describe como
> *"background transparente… el mismo color que un card"*, que es exactamente `input/30` (blanco a
> α 0.045) sobre el card.
>
> Es decir: la diferencia checked/indeterminate **sí es visual** (el relleno), no solo semántica
> (ARIA). Lo que NO cambia entre ambos es el glyph.

**Disabled — suprimir eventos**: Llamar `checkbox.frame:EnableMouse(false)`. No modificar el `onChange` callback — simplemente no ejecutarlo.
