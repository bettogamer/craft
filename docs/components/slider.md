# Component: Slider

> Referencia shadcn: `slider` — WoW frame base: `Slider`

## Propósito

Control deslizante horizontal para seleccionar un valor numérico dentro de un rango, con track, fill proporcional, thumb cuadrado y labels opcionales de valor/rango.

## Jerarquía de frames WoW

```
Frame (root)                            — contenedor, height según config de labels
├── Slider (track nativo)               — BACKGROUND layer, height=4px, ancho completo
│   └── Texture (trackBg)              — BACKGROUND layer, t.secondary fill
├── Frame (fillTrack)                   — BACKGROUND layer, mismo SetPoint left que track
│   └── Texture (fillBg)               — BACKGROUND layer, t.primary fill, height=4px
├── Button (thumb)                      — OVERLAY layer, 14×14px (default) o 18×18px (lg)
│   ├── Texture (thumbBg)              — BACKGROUND layer, t.primary fill
│   └── Frame (thumbRing)              — sibling del thumb, 2px outward, t.ring (en hover)
├── FontString (valueLabel)             — OVERLAY layer, sobre el thumb, fontSizeSm, t.foreground
├── FontString (minLabel)               — OVERLAY layer, extremo izquierdo del track, t.mutedForeground, fontSizeSm
└── FontString (maxLabel)               — OVERLAY layer, extremo derecho del track, t.mutedForeground, fontSizeSm
```

## Dimensiones

### Track

| Propiedad    | Valor               |
|--------------|---------------------|
| Height       | 4px                 |
| Width        | 100% del root frame |
| Color        | `t.secondary`       |
| Fill color   | `t.primary`         |

### Thumb

| Tamaño    | Width × Height | Delta dragging |
|-----------|---------------|----------------|
| `default` | 14 × 14px     | +2px (→ 16×16) |
| `lg`      | 18 × 18px     | +2px (→ 20×20) |

El thumb es un `Button` posicionado con `SetPoint("CENTER", track, "LEFT", offset, 0)` donde `offset = (value - min) / (max - min) * trackWidth`.

### Altura total del root frame

| Configuración                     | Height  |
|-----------------------------------|---------|
| Sin labels                        | 32px    |
| Solo `showMinMax=true`            | 32px    |
| Solo `showValue=true`             | 48px    |
| `showValue=true` + `showMinMax=true` | 48px |

Posición vertical del track dentro del root:
- Sin `showValue`: centrado verticalmente en el root.
- Con `showValue`: desplazado hacia abajo — track a 24px del top del root (deja 20px para el `valueLabel` arriba).

### Labels

| Label        | Posición                                            | Font size       | Color               |
|--------------|-----------------------------------------------------|-----------------|---------------------|
| `valueLabel` | `SetPoint("BOTTOM", thumb, "TOP", 0, 4)`           | `fontSizeSm` 11px | `t.foreground`    |
| `minLabel`   | `SetPoint("LEFT", track, "LEFT", 0, -12)`          | `fontSizeSm` 11px | `t.mutedForeground` |
| `maxLabel`   | `SetPoint("RIGHT", track, "RIGHT", 0, -12)`        | `fontSizeSm` 11px | `t.mutedForeground` |

## Variantes visuales

No hay variantes de color adicionales. El tamaño (`default`/`lg`) controla el thumb.

## Estados

| Estado     | Track fill    | Track bg      | Thumb bg      | Thumb ring          | Drag              |
|------------|---------------|---------------|---------------|---------------------|-------------------|
| Default    | `t.primary`   | `t.secondary` | `t.primary`   | Oculto              | Permitido         |
| Hover      | `t.primary`   | `t.secondary` | `t.primary`   | Visible (`t.ring`)  | Permitido         |
| Dragging   | `t.primary`   | `t.secondary` | `t.primary`   | Visible (`t.ring`)  | Thumb +2px size   |
| Disabled   | `t.muted`     | `t.muted`     | `t.muted`     | Oculto              | Suprimido         |

En estado disabled: `Slider:EnableMouse(false)`, `thumb:EnableMouse(false)`. El fill track y thumb usan `t.muted` como color.

## Mapa de tokens

| Elemento             | Token               |
|----------------------|---------------------|
| Track bg             | `t.secondary`       |
| Fill track           | `t.primary`         |
| Thumb bg             | `t.primary`         |
| Thumb bg disabled    | `t.muted`           |
| Track bg disabled    | `t.muted`           |
| Fill track disabled  | `t.muted`           |
| Thumb ring (hover)   | `t.ring`            |
| Value label          | `t.foreground`      |
| Min/max labels       | `t.mutedForeground` |

## Config — `Create(parent, config)`

| Parámetro    | Tipo       | Default   | Descripción                                                                  |
|--------------|------------|-----------|------------------------------------------------------------------------------|
| `min`        | `number`   | `0`       | Valor mínimo del rango                                                       |
| `max`        | `number`   | `100`     | Valor máximo del rango                                                       |
| `value`      | `number`   | `0`       | Valor inicial                                                                |
| `step`       | `number`   | `1`       | Incremento mínimo por paso                                                   |
| `disabled`   | `boolean`  | `false`   | Deshabilita la interacción                                                   |
| `showValue`  | `boolean`  | `false`   | Muestra el `valueLabel` sobre el thumb con el valor actual                   |
| `showMinMax` | `boolean`  | `false`   | Muestra `minLabel` y `maxLabel` en los extremos del track                    |
| `size`       | `string`   | `"default"` | `"default"` (14px thumb) o `"lg"` (18px thumb)                            |
| `onChange`   | `function` | `nil`     | `fn(value)` — se dispara en `OnValueChanged` del Slider nativo              |
| `width`      | `number`   | `nil`     | Ancho fijo en px. Si es nil, ocupa 100% del parent                           |

## API pública

| Método                  | Descripción                                                                   |
|-------------------------|-------------------------------------------------------------------------------|
| `SetValue(n)`           | Establece el valor. Actualiza fill track, posición del thumb y valueLabel     |
| `GetValue()`            | Retorna el valor actual del Slider                                            |
| `SetEnabled(bool)`      | Habilita/deshabilita. Aplica colores de disabled al track, fill y thumb       |
| `SetRange(min, max)`    | Actualiza el rango. Llama `Slider:SetMinMaxValues(min, max)`. Reposiciona thumb |
| `GetFrame()`            | Retorna el frame root del componente                                          |

## Notas de implementación

- **Slider nativo**: usar `CreateFrame("Slider", nil, parent)` con `SetOrientation("HORIZONTAL")`, `SetMinMaxValues(min, max)`, `SetValue(value)`, `SetValueStep(step)`. WoW renderiza el thumb nativo del Slider — reemplazarlo por un Button custom sobre él.
- **Ocultar thumb nativo**: el Slider nativo tiene un thumb visual propio. Ocultarlo asignando una textura invisible: `slider:SetThumbTexture("")`. El thumb personalizado es un `Button` separado.
- **Fill track**: no es nativo de WoW. Crear un `Frame` hijo del root, anclado al extremo izquierdo del track con la misma altura (4px). Su width se calcula en `OnValueChanged`:
  ```lua
  local pct = (value - min) / (max - min)
  fillTrack:SetWidth(math.max(1, pct * trackWidth))
  ```
  Usar `math.max(1, ...)` para evitar width=0 que causa errores en WoW.
- **Posición del thumb Button**: recalcular en `OnValueChanged`:
  ```lua
  local pct = (value - min) / (max - min)
  local offset = pct * trackWidth - trackWidth / 2
  thumb:SetPoint("CENTER", track, "CENTER", offset, 0)
  ```
- **Drag del thumb**: implementar con `thumb:SetScript("OnMouseDown", ...)` y `thumb:SetScript("OnMouseUp", ...)`. Durante el drag, usar `OnUpdate` para leer `GetCursorPosition()` y calcular el valor proporcional. No usar el drag nativo del Slider (puede interferir con el thumb custom).
- **Tamaño durante drag**: en `OnMouseDown` del thumb, aumentar width/height en 2px con `thumb:SetSize(thumbSize+2, thumbSize+2)`. Restaurar en `OnMouseUp`.
- **Ring del thumb**: frame hermano del thumb (mismo parent), 2px outward. Mostrar en `thumb:OnEnter` y durante drag, ocultar en `thumb:OnLeave` (excepto si sigue en drag).
- **GetWidth del track**: el track puede no tener un width fijo en el momento de `Create` si depende del layout. Capturar `trackWidth` en `OnSizeChanged` del root o en el primer `OnUpdate`. Guardar en la tabla del componente para cálculos de posición/fill.
- **SetValueStep**: `Slider:SetValueStep(step)` hace que el Slider nativo solo acepte valores múltiplos del step. El thumb custom debe respetar esto — al calcular offset, usar `Slider:GetValue()` (ya snappeado) en lugar del cursor directo.
- **OnValueChanged loop**: `Slider:SetValue(n)` dispara `OnValueChanged`. Usar un flag de guard (`self._updating = true`) si se necesita prevenir recursión al llamar `SetValue` desde el callback.
