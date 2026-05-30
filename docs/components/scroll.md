# Component: Scroll

> Referencia shadcn: `scroll-area` — WoW frame base: `ScrollFrame` + `ScrollChild`

## Propósito

Área de contenido con scroll vertical (y opcionalmente horizontal), scrollbar custom con thumb arrastrable y soporte de rueda del mouse.

## Jerarquía de frames WoW

```
Frame (root)                              — contenedor exterior, define el tamaño visible
├── ScrollFrame                           — clipping area, mismo tamaño que root menos el ancho del scrollbar
│   └── Frame (scrollChild)              — contenido real, puede exceder la altura del ScrollFrame
├── Frame (scrollbarV)                    — scrollbar vertical, 8px ancho, anclado al borde derecho
│   ├── Texture (trackBg)               — BACKGROUND layer, transparent (sin color)
│   └── Slider (thumbSlider)            — vertical, thumb custom
│       └── Button (thumbBtn)           — OVERLAY layer, 6px ancho, thumb visual
│           └── Texture (thumbBg)       — BACKGROUND layer, t.secondary
└── Frame (scrollbarH)                    — scrollbar horizontal (opcional), 8px alto, anclado al borde inferior
    ├── Texture (trackBg)               — BACKGROUND layer, transparent
    └── Slider (thumbSliderH)           — horizontal, thumb custom
        └── Button (thumbBtnH)          — OVERLAY layer, 6px alto, thumb visual
            └── Texture (thumbBgH)      — BACKGROUND layer, t.secondary
```

## Dimensiones

### Scrollbar vertical

| Elemento     | Propiedad     | Valor                              |
|--------------|---------------|------------------------------------|
| Track        | Width         | 8px                                |
| Track        | Height        | igual al height del ScrollFrame    |
| Track        | Color         | Transparent (sin fondo visual)     |
| Thumb        | Width         | 6px (1px gap a cada lado vs track) |
| Thumb        | Min height    | 32px                               |
| Thumb        | Height calc   | `(visible/total) * trackHeight`, mínimo 32px |
| Gap track-thumb | Offset X   | 1px desde cada lado del track      |

### Scrollbar horizontal (cuando `horizontal=true`)

| Elemento     | Propiedad     | Valor                              |
|--------------|---------------|------------------------------------|
| Track        | Height        | 8px                                |
| Track        | Width         | igual al width del ScrollFrame     |
| Track        | Color         | Transparent                        |
| Thumb        | Height        | 6px                                |
| Thumb        | Min width     | 32px                               |
| Thumb        | Width calc    | `(visible/total) * trackWidth`, mínimo 32px |

### Espacio reservado para scrollbar dentro del root

| Configuración             | ScrollFrame width adjustment | ScrollFrame height adjustment |
|---------------------------|------------------------------|-------------------------------|
| Solo vertical (default)   | −8px del width total         | 0                             |
| Solo horizontal           | 0                            | −8px del height total         |
| Ambos                     | −8px width, −8px height      | −8px width, −8px height       |

### Dimensiones generales

| Config parámetro | Afecta                                     |
|------------------|--------------------------------------------|
| `width`          | Width del frame root (requerido)           |
| `height`         | Height del frame root (requerido)          |

## Variantes visuales

No hay variantes de color para el contenido. El scrollbar varía solo por estado del thumb.

## Estados

### Thumb del scrollbar

| Estado    | Thumb bg      | Notas                               |
|-----------|---------------|-------------------------------------|
| Default   | `t.secondary` | Visible solo si hay contenido que supera el área visible |
| Hover     | `t.accent`    | Mouse sobre el thumb Button         |
| Dragging  | `t.primary`   | Durante el drag del thumb           |

El scrollbar completo se oculta (`Hide()`) si el contenido no excede el área visible (`scrollRange == 0`). Se muestra (`Show()`) en cuanto el contenido supera el área.

## Mapa de tokens

| Elemento               | Token          |
|------------------------|----------------|
| Track bg               | Transparent    |
| Thumb bg default       | `t.secondary`  |
| Thumb bg hover         | `t.accent`     |
| Thumb bg dragging      | `t.primary`    |
| ScrollChild bg         | (ninguno — hereda del parent) |
| Root bg                | (ninguno — transparente por defecto) |

## Config — `Create(parent, config)`

| Parámetro    | Tipo       | Default   | Descripción                                                                    |
|--------------|------------|-----------|--------------------------------------------------------------------------------|
| `width`      | `number`   | requerido | Ancho total del componente en px                                               |
| `height`     | `number`   | requerido | Alto total del componente en px                                                |
| `horizontal` | `boolean`  | `false`   | Habilita el scrollbar horizontal adicional                                     |
| `onScroll`   | `function` | `nil`     | `fn(offsetV, offsetH)` — se dispara al cambiar cualquier scroll offset         |

## API pública

| Método                    | Descripción                                                                       |
|---------------------------|-----------------------------------------------------------------------------------|
| `SetScrollChild(frame)`   | Asigna el frame de contenido al ScrollFrame. Llama `ScrollFrame:SetScrollChild(frame)` |
| `GetScrollChild()`        | Retorna el frame de contenido actual                                              |
| `ScrollToTop()`           | Establece scroll vertical a 0 (`SetVerticalScroll(0)`)                           |
| `ScrollToBottom()`        | Establece scroll vertical al máximo (`GetVerticalScrollRange()`)                 |
| `SetScrollOffset(n)`      | Establece el scroll vertical a `n` px desde el top                               |
| `GetScrollOffset()`       | Retorna el offset vertical actual (`GetVerticalScroll()`)                        |
| `GetFrame()`              | Retorna el frame root del componente                                              |

## Notas de implementación

- **ScrollFrame nativo**: usar `CreateFrame("ScrollFrame", nil, parent)`. La API nativa provee `SetScrollChild(frame)`, `GetVerticalScroll()`, `SetVerticalScroll(n)`, `GetVerticalScrollRange()`, `GetHorizontalScroll()`, `SetHorizontalScroll(n)`, `GetHorizontalScrollRange()`.
- **ScrollChild height explícito**: el `scrollChild` debe tener `SetHeight` explícito para que WoW calcule correctamente el rango de scroll. Sin un height definido, `GetVerticalScrollRange()` retorna 0. El consumer del componente es responsable de llamar `scrollChild:SetHeight(contenidoTotal)` después de poblar el contenido, o de pasarle el frame ya dimensionado.
- **Mouse wheel**: habilitar con `ScrollFrame:EnableMouseWheel(true)`. El script:
  ```lua
  scrollFrame:SetScript("OnMouseWheel", function(self, delta)
      local current = self:GetVerticalScroll()
      local max = self:GetVerticalScrollRange()
      local new = math.max(0, math.min(max, current - delta * 20))
      self:SetVerticalScroll(new)
  end)
  ```
  El `delta` es `+1` (scroll up) o `-1` (scroll down). El factor `20` es el número de px por tick — ajustable.
- **Thumb height dinámica**: calcular en cada cambio de scroll y al redimensionar:
  ```lua
  local visible = scrollFrame:GetHeight()
  local total = scrollChild:GetHeight()
  local range = scrollFrame:GetVerticalScrollRange()
  if range == 0 then
      scrollbarV:Hide()
      return
  end
  scrollbarV:Show()
  local thumbH = math.max(32, (visible / total) * trackHeight)
  thumbBtn:SetHeight(thumbH)
  ```
- **Thumb Slider para drag**: usar un `Slider` vertical nativo para manejar el drag del thumb. Configurar `SetMinMaxValues(0, scrollRange)` y actualizar `SetValue` cuando cambia el scroll. En `OnValueChanged` del Slider, llamar `ScrollFrame:SetVerticalScroll(value)`. Esto evita implementar drag manual con `OnUpdate`.
- **Sincronización bidireccional**: al hacer scroll con la rueda (que llama `SetVerticalScroll` directamente), también actualizar el `Slider` del thumb con `thumbSlider:SetValue(newOffset)` para que el thumb se reposicione. Usar un flag de guard para evitar loops `OnValueChanged ↔ SetVerticalScroll`.
- **Thumb offset en el track**: el Slider vertical posiciona el thumb internamente. Para el gap de 1px a cada lado, anclar el `thumbSlider` con `SetPoint("TOPLEFT", trackFrame, "TOPLEFT", 1, 0)` y `SetPoint("BOTTOMRIGHT", trackFrame, "BOTTOMRIGHT", -1, 0)` — esto le da 6px de ancho al área del slider, que es el ancho del thumb.
- **Hover/drag del thumb**: los estados hover y dragging se manejan con `thumbBtn:SetScript("OnEnter", ...)`, `OnLeave`, `OnMouseDown`, `OnMouseUp`. Al hacer `OnMouseDown`, cambiar el color a `t.primary`. Al `OnMouseUp`, volver a `t.secondary` (o `t.accent` si el mouse sigue sobre el thumb). Al `OnEnter`, cambiar a `t.accent`.
- **Scrollbar horizontal**: mismo esquema pero con `Slider` horizontal (`SetOrientation("HORIZONTAL")`), `GetHorizontalScrollRange()` y `SetHorizontalScroll(n)`. El mouse wheel no afecta el scroll horizontal (es solo para vertical); el scroll horizontal requiere drag del thumb.
- **Ocultar scrollbars vacíos**: si `GetVerticalScrollRange() == 0` al asignar el scrollChild, llamar `scrollbarV:Hide()` y no reservar el espacio de 8px — opcionalmente expandir el ScrollFrame al ancho completo del root. Sin embargo, para simplicidad de implementación, es aceptable reservar siempre el espacio del scrollbar y simplemente ocultar el thumb.
- **Anclaje del scrollbar vertical**: `SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)` y `SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)`. Width fijo = 8px.
- **Anclaje del scrollbar horizontal**: `SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0)` y `SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -8, 0)` (el -8 es para no solapar con el scrollbar vertical si ambos están activos). Height fijo = 8px.
