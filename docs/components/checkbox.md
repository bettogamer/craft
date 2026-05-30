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

`checkbox.frame` es un Frame genérico que actúa como contenedor interactivo; los eventos `OnMouseDown`/`OnMouseUp` se registran aquí para simular el comportamiento de checkbox. `_box` contiene el cuadro visible y sus estados. `_check` es la textura del checkmark (ícono Lucide "check") que se muestra u oculta según el estado. Para el estado indeterminado, `_check` se reemplaza por `_dash`, una textura de línea horizontal de 2px centrada.

## Dimensiones

### Tamaños

Lyra define un único tamaño para `checkbox` (`size-4`). No hay variante `lg` en el CSS real.

| Propiedad         | Valor   | Fuente Tailwind      |
|-------------------|---------|----------------------|
| Box               | 16×16px | `size-4`             |
| Border radius     | 0       | `rounded-none`       |
| Border            | 1px     | `border`             |
| Checkmark (indicator) | 14×14px | `size-3.5` (en `.cn-checkbox-indicator svg`) |

- El checkmark indicator es 14px (no 10px). Viene de `[&>svg]:size-3.5` en `.cn-checkbox-indicator`.
- El box actúa como contenedor flex centrado (`flex items-center justify-center`); el indicator se posiciona automáticamente.
- Gap entre el borde derecho del `_box` y el inicio del `_label`: `spacingSm` = 8px.
- La altura del `checkbox.frame` se ajusta automáticamente al mayor de: box height o label height.

### Variantes visuales (estados del checkbox)

| Estado         | Borde `_box`                        | Fondo `_box._bg`                         | Checkmark visible |
|----------------|-------------------------------------|------------------------------------------|--------------------|
| unchecked      | {r=1,g=1,b=1,a=0.15} (`t.border`)  | {r=1,g=1,b=1,a=0.045} (`input/30`)      | no                 |
| checked        | `t.primary`                         | `t.primary`                              | sí                 |
| indeterminate  | `t.primary`                         | `t.primary`                              | no (dash visible)  |
| disabled       | opacity 0.5 sobre estado base       | opacity 0.5 sobre estado base            | según estado base  |
| error          | `t.destructive`                     | {r=1,g=1,b=1,a=0.045} (`input/30`)      | no                 |

## Estados

| Estado        | Borde                               | Fondo interior                        | Texto label         |
|---------------|-------------------------------------|---------------------------------------|---------------------|
| unchecked     | {r=1,g=1,b=1,a=0.15}               | {r=1,g=1,b=1,a=0.045}                | `t.foreground`      |
| checked       | `t.primary`                         | `t.primary`                           | `t.foreground`      |
| indeterminate | `t.primary`                         | `t.primary`                           | `t.foreground`      |
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
| Borde del box (unchecked)     | `t.border` = {r=1,g=1,b=1,a=0.15}             |
| Fondo del box (unchecked)     | input/30 = {r=1,g=1,b=1,a=0.045}              |
| Borde del box (checked)       | `t.primary` = {r=0.024,g=0.373,b=0.275}       |
| Fondo del box (checked)       | `t.primary` = {r=0.024,g=0.373,b=0.275}       |
| Borde del box (error)         | `t.destructive` = {r=0.973,g=0.443,b=0.443}   |
| Disabled                      | `SetAlpha(0.5)` en `_box`                      |
| Checkmark / dash              | `t.primaryForeground` = {r=0.925,g=0.992,b=0.961} |
| Texto del label               | `t.foreground` = {r=0.980,g=0.980,b=0.980}    |
| Texto del label (disabled)    | `t.mutedForeground` = {r=0.631,g=0.631,b=0.667} |

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
| `SetEnabled(enabled)`| `boolean → void`         | Activa o desactiva la interacción y el estilo.                                       |
| `SetLabel(text)`     | `string → void`          | Cambia el texto del label. Pasa `nil` o `""` para ocultar el label.                  |
| `SetError(hasError)` | `boolean → void`         | Activa/desactiva el estado de error (borde `t.destructive`).                         |
| `GetFrame()`         | `→ Frame`                | Devuelve el frame WoW raíz para posicionamiento externo.                             |

## Notas de implementación

**Sin widget nativo**: WoW no tiene un frame `CheckButton` equivalente al checkbox web. Se construye con un `Frame` genérico que registra `OnMouseDown` para toggle. El `CheckButton` nativo de WoW existe pero tiene estilos heredados del juego difíciles de neutralizar; usar `Frame` limpio es más predecible.

**Checkmark Lucide**: El ícono "check" de Lucide se carga desde el atlas de la librería. La textura `_box._check` usa `SetAtlas("lucide-check")` o coordenadas UV del spritesheet `lucide-16.tga`. El indicator mide **14×14px** (`size-3.5`). Para el estado indeterminado, `_box._dash` es una textura simple de 1–2px de alto y ancho = box_size - 4px, centrada, con color `t.primaryForeground`.

**Borde del box**: No usar 9-slice. El borde se implementa como 4 texturas de 1px: top, right, bottom, left, dentro de `_box` con `SetPoint` absoluto. Alternativamente, usar un Frame con backdrop si el contexto lo permite, pero la solución con 4 texturas es más fiel al estilo Lyra.

**Sin focus ring en WoW**: el `focus-visible:ring-1` de Lyra no se implementa. WoW es mouse-only, sin keyboard navigation. No crear el frame `_ring`.

**Propagación del click a toda el área**: Registrar `OnMouseDown` en `checkbox.frame` completo (no solo `_box`) para que hacer clic en el label también active el checkbox. Esto mejora la usabilidad y es consistente con shadcn.

**Estado indeterminado con `nil`**: Al recibir `SetChecked(nil)`, mostrar `_dash` (ocultar `_check`) y pintar el fondo como si fuera checked (`t.primary`). Internamente guardar el estado como `nil`, no como `false`.

**Disabled — suprimir eventos**: Llamar `checkbox.frame:EnableMouse(false)`. No modificar el `onChange` callback — simplemente no ejecutarlo.
