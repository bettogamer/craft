# Component: Checkbox

> Referencia shadcn: `checkbox` — https://ui.shadcn.com/docs/components/checkbox
> WoW frame base: `Frame` (no hay widget checkbox nativo en WoW)

## Propósito
Control de selección binaria (marcado/desmarcado) con soporte para estado indeterminado, label opcional y detección de errores de validación.

## Jerarquía de frames WoW

```
checkbox.frame          (Frame — nivel raíz, contiene box + label, recibe eventos de ratón)
├── checkbox._box       (Frame — BACKGROUND) contenedor del cuadro visual exterior
│   ├── _box._bg        (Texture — BACKGROUND) fondo interior del cuadro (transparent o primary)
│   ├── _box._border    (Texture — BORDER)     borde de 1px del cuadro
│   └── _box._check     (Texture — ARTWORK)    ícono "check" Lucide 10×10, centrado en _box
├── checkbox._ring      (Frame — OVERLAY)      focus ring de 2px outward, oculto por defecto
│   └── _ring._tex      (Texture — OVERLAY)    textura del ring coloreada con t.ring
└── checkbox._label     (FontString — OVERLAY) texto opcional a la derecha del box
```

`checkbox.frame` es un Frame genérico que actúa como contenedor interactivo; los eventos `OnMouseDown`/`OnMouseUp` se registran aquí para simular el comportamiento de checkbox. `_box` contiene el cuadro visible y sus estados. `_check` es la textura del checkmark (ícono Lucide "check") que se muestra u oculta según el estado. Para el estado indeterminado, `_check` se reemplaza por `_dash`, una textura de línea horizontal de 2px centrada.

## Dimensiones

### Tamaños
| Variante de tamaño | Box (px) | Fondo interior (px) | Checkmark (px) | Fuente label (px) | Ícono (px) |
|-------------------|----------|---------------------|----------------|-------------------|-----------|
| default           | 16×16    | 14×14               | 10×10          | 12                | —         |
| lg                | 20×20    | 18×18               | 12×12          | 14                | —         |

- El fondo interior (`_box._bg`) está centrado dentro de `_box` con 1px de margen en cada lado (el borde ocupa ese pixel).
- El checkmark (`_box._check`) está centrado dentro de `_box._bg`.
- Gap entre el borde derecho del `_box` y el inicio del `_label`: `spacingSm` = 8px.
- La altura del `checkbox.frame` se ajusta automáticamente al mayor de: box height o label height.

### Variantes visuales (estados del checkbox)
| Estado         | Borde `_box`    | Fondo `_box._bg`   | Checkmark visible |
|----------------|-----------------|--------------------|--------------------|
| unchecked      | `t.border`      | transparente       | no                 |
| checked        | `t.primary`     | `t.primary`        | sí                 |
| indeterminate  | `t.primary`     | `t.primary`        | no (dash visible)  |
| disabled       | `t.muted`       | `t.muted` a=0.5    | según estado base  |
| error          | `t.destructive` | transparente       | no                 |

## Estados
| Estado        | Borde       | Fondo interior      | Ring               | Texto label         |
|---------------|-------------|---------------------|--------------------|---------------------|
| unchecked     | `t.border`  | transparente        | —                  | `t.foreground`      |
| checked       | `t.primary` | `t.primary`         | —                  | `t.foreground`      |
| indeterminate | `t.primary` | `t.primary`         | —                  | `t.foreground`      |
| hover         | `t.primary` | `t.primary` a=0.15  | —                  | `t.foreground`      |
| focus         | `t.border`  | según estado base   | `t.ring` 2px outward | `t.foreground`    |
| disabled      | `t.muted`   | `t.muted` a=0.5     | —                  | `t.mutedForeground` |
| error         | `t.destructive` | transparente    | —                  | `t.foreground`      |

- En hover sobre unchecked: el fondo interior muestra `t.primary` con a=0.15 (anticipación visual del estado checked).
- Los estados `disabled` + `checked` combinados muestran borde `t.muted`, fondo `t.muted` a=0.5, y el checkmark visible pero atenuado.
- El estado `error` solo afecta el borde; el label puede recibir un texto de error externo (no gestionado por el componente).

## Mapa de tokens
| Elemento visual             | Token                   |
|-----------------------------|-------------------------|
| Borde del box (unchecked)   | `t.border`              |
| Borde del box (checked)     | `t.primary`             |
| Borde del box (error)       | `t.destructive`         |
| Borde del box (disabled)    | `t.muted`               |
| Fondo interior (checked)    | `t.primary`             |
| Fondo interior (hover)      | `t.primary` a=0.15      |
| Fondo interior (disabled)   | `t.muted` a=0.5         |
| Checkmark / dash            | `t.primaryForeground`   |
| Texto del label             | `t.foreground`          |
| Texto del label (disabled)  | `t.mutedForeground`     |
| Focus ring                  | `t.ring`                |

## Config — `Create(parent, config)`
| Clave      | Tipo     | Default      | Descripción                                                        |
|------------|----------|--------------|--------------------------------------------------------------------|
| `checked`  | boolean  | `false`      | Estado inicial del checkbox. `nil` activa estado indeterminado.   |
| `disabled` | boolean  | `false`      | Si `true`, suprime interacción y aplica estilo disabled.           |
| `label`    | string   | `nil`        | Texto opcional mostrado a la derecha del box.                      |
| `size`     | string   | `"default"`  | `"default"` (16px box) o `"lg"` (20px box).                       |
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

**Checkmark Lucide**: El ícono "check" de Lucide se carga desde el atlas de la librería. La textura `_box._check` usa `SetAtlas("lucide-check")` o coordenadas UV del spritesheet `lucide-16.tga`. Para el estado indeterminado, `_box._dash` es una textura simple de 1px de alto (o 2px) y ancho = box_size - 4px, centrada, con color `t.primaryForeground`.

**Borde del box**: No usar 9-slice. El borde se implementa como 4 texturas de 1px: top, right, bottom, left, dentro de `_box` con `SetPoint` absoluto. Alternativamente, usar un Frame con backdrop si el contexto lo permite, pero la solución con 4 texturas es más fiel al estilo Lyra.

**Focus ring outward**: Igual que Button — el frame `_ring` se posiciona con `SetPoint("TOPLEFT", checkbox._box, "TOPLEFT", -2, 2)` y `SetPoint("BOTTOMRIGHT", checkbox._box, "BOTTOMRIGHT", 2, -2)`. El ring rodea solo el `_box`, no el label completo.

**Propagación del click a toda el área**: Registrar `OnMouseDown` en `checkbox.frame` completo (no solo `_box`) para que hacer clic en el label también active el checkbox. Esto mejora la usabilidad y es consistente con shadcn.

**Estado indeterminado con `nil`**: Al recibir `SetChecked(nil)`, mostrar `_dash` (ocultar `_check`) y pintar el fondo como si fuera checked (`t.primary`). Internamente guardar el estado como `nil`, no como `false`.

**Disabled — suprimir eventos**: Llamar `checkbox.frame:EnableMouse(false)`. No modificar el `onChange` callback — simplemente no ejecutarlo.
