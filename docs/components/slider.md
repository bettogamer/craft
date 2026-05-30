# Component: Slider

> Referencia shadcn: `slider` — WoW frame base: `Slider`

## CSS de referencia (Lyra)

```css
.cn-slider-track {
  @apply bg-muted rounded-none data-horizontal:h-1 data-horizontal:w-full;
}
.cn-slider-range {
  @apply bg-primary;
}
.cn-slider-thumb {
  @apply border-ring ring-ring/50 relative size-3 rounded-none border bg-white
         hover:ring-1 active:ring-1;
}
```

## Propósito

Control deslizante horizontal para seleccionar un valor numérico dentro de un rango, con track, fill proporcional, thumb cuadrado y labels opcionales de valor/rango.

## Jerarquía de frames WoW

```
Frame (root)                            — contenedor, height según config de labels
├── Slider (track nativo)               — BACKGROUND layer, height=4px, ancho completo
│   └── Texture (trackBg)              — BACKGROUND layer, t.muted fill
├── Frame (fillTrack)                   — BACKGROUND layer, mismo SetPoint left que track
│   └── Texture (fillBg)               — BACKGROUND layer, t.primary fill, height=4px
├── Button (thumb)                      — OVERLAY layer, 12×12px
│   ├── Texture (thumbBg)              — BACKGROUND layer, blanco {r=1,g=1,b=1,a=1}
│   └── Frame (thumbRing)              — sibling del thumb, 1px outward, t.ring/50 (en OnEnter/drag)
├── FontString (valueLabel)             — OVERLAY layer, sobre el thumb, fontSizeSm, t.foreground
├── FontString (minLabel)               — OVERLAY layer, extremo izquierdo del track, t.mutedForeground, fontSizeSm
└── FontString (maxLabel)               — OVERLAY layer, extremo derecho del track, t.mutedForeground, fontSizeSm
```

## Dimensiones

### Track

| Propiedad    | Valor               |
|--------------|---------------------|
| Height       | 4px (`h-1`)         |
| Width        | 100% del root frame |
| Color        | `t.muted`           |
| Fill color   | `t.primary`         |

### Thumb

| Propiedad       | Valor                                             |
|-----------------|---------------------------------------------------|
| Tamaño          | 12×12px (`size-3`) — único tamaño, sin variantes  |
| Color           | Blanco {r=1, g=1, b=1, a=1} (`bg-white`)         |
| Border          | `t.ring` = {r=0.443, g=0.443, b=0.478, a=1}      |
| Ring hover/drag | `t.ring` a=0.5 = {r=0.443, g=0.443, b=0.478, a=0.5} (`ring-ring/50`) |
| Forma           | `rounded-none` (cuadrado)                         |

No hay variantes de tamaño (`lg` no existe en Lyra slider). El thumb es siempre 12×12px.

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

No hay variantes de tamaño ni color. El slider tiene un único tamaño (thumb 12×12px).

## Estados

| Estado     | Track fill  | Track bg    | Thumb bg                 | Thumb border | Thumb ring                      |
|------------|-------------|-------------|--------------------------|--------------|----------------------------------|
| Default    | `t.primary` | `t.muted`   | Blanco {r=1,g=1,b=1,a=1} | `t.ring`     | Oculto                           |
| Hover      | `t.primary` | `t.muted`   | Blanco {r=1,g=1,b=1,a=1} | `t.ring`     | Visible, `t.ring` a=0.5 (1px outward) |
| Dragging   | `t.primary` | `t.muted`   | Blanco {r=1,g=1,b=1,a=1} | `t.ring`     | Visible, `t.ring` a=0.5 (1px outward) |
| Disabled   | `t.muted`   | `t.muted`   | `t.muted`                | `t.muted`    | Oculto                           |

**Nota sobre el ring en hover**: `hover:ring-1` en CSS corresponde a `OnEnter` del mouse en WoW — es hover de mouse, NO keyboard focus. Según ADR-0011 (WoW es mouse-only), el ring de hover SÍ se implementa: mostrar el thumbRing en `thumb:SetScript("OnEnter", ...)` y ocultarlo en `"OnLeave"` (excepto durante drag activo). El ring tiene 1px de grosor — usar `Craft.Theme.SetPixelHeight/Width(thumbRing, 1)`.

En estado disabled: `Slider:EnableMouse(false)`, `thumb:EnableMouse(false)`. Fill track y thumb usan `t.muted`.

## Mapa de tokens

| Elemento                  | Token / Valor                                          |
|---------------------------|--------------------------------------------------------|
| Track bg                  | `t.muted`                                              |
| Fill track                | `t.primary`                                            |
| Thumb bg                  | Blanco {r=1, g=1, b=1, a=1}                           |
| Thumb border              | `t.ring` = {r=0.443, g=0.443, b=0.478, a=1}           |
| Thumb ring (hover/drag)   | `t.ring` a=0.5 = {r=0.443, g=0.443, b=0.478, a=0.5}  |
| Thumb bg disabled         | `t.muted`                                              |
| Track bg disabled         | `t.muted`                                              |
| Fill track disabled       | `t.muted`                                              |
| Value label               | `t.foreground`                                         |
| Min/max labels            | `t.mutedForeground`                                    |

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
| `onChange`   | `function` | `nil`     | `fn(value)` — se dispara en `OnValueChanged` del Slider nativo              |
| `width`      | `number`   | `nil`     | Ancho fijo en px. Si es nil, ocupa 100% del parent                           |

No hay parámetro `size` — el slider tiene un único tamaño de thumb (12×12px).

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
- **Ocultar thumb nativo**: el Slider nativo tiene un thumb visual propio. Ocultarlo asignando una textura invisible: `slider:SetThumbTexture("")`. El thumb personalizado es un `Button` separado de 12×12px.
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
- **Ring del thumb en hover (OnEnter)**: el CSS indica `hover:ring-1` — en WoW esto es `OnEnter/OnLeave` del mouse, no keyboard focus. SÍ implementar: mostrar `thumbRing` en `thumb:SetScript("OnEnter", ...)`, ocultar en `"OnLeave"` (salvo durante drag). El ring tiene 1px de grosor: usar `Craft.Theme.SetPixelHeight/Width(thumbRing, 1)`. Color: {r=0.443, g=0.443, b=0.478, a=0.5}. También visible durante drag activo.
- **Ring del thumb — pixel-perfect**: el thumbRing es un frame hermano de 12×12px posicionado 1px outward (SetPoint con −1px en cada lado). Sus cuatro aristas de 1px se crean con `Craft.Theme.SetPixelHeight/Width` conforme ADR-0011.
- **GetWidth del track**: el track puede no tener un width fijo en el momento de `Create` si depende del layout. Capturar `trackWidth` en `OnSizeChanged` del root o en el primer `OnUpdate`. Guardar en la tabla del componente para cálculos de posición/fill.
- **SetValueStep**: `Slider:SetValueStep(step)` hace que el Slider nativo solo acepte valores múltiplos del step. El thumb custom debe respetar esto — al calcular offset, usar `Slider:GetValue()` (ya snappeado) en lugar del cursor directo.
- **OnValueChanged loop**: `Slider:SetValue(n)` dispara `OnValueChanged`. Usar un flag de guard (`self._updating = true`) si se necesita prevenir recursión al llamar `SetValue` desde el callback.
