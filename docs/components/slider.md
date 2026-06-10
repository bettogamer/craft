# Component: Slider

> Referencia shadcn: `slider` — WoW frame base: **pure-custom** (`Frame` + `Button`, sin widget `Slider` nativo)
>
> ⚠️ **No usar el widget `Slider` nativo de WoW.** Su bounding box invisible se
> extiende más allá del track visual de 4px y ocluye FontStrings del frame padre
> sin importar el `FrameLevel` (bug de producción #3 — ver CLAUDE.md). La
> implementación es 100% custom: `Frame` para el track/fill + `Button` para el thumb.

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
Frame (root)                  — contenedor, height según config de labels; OnMouseDown/Wheel
├── FontString (label)        — OVERLAY, BOTTOMLEFT→trackFrame.TOPLEFT, fontSizeSm, t.foreground [Craft ext]
├── FontString (valueLabel)   — OVERLAY, BOTTOMRIGHT→trackFrame.TOPRIGHT, fontSizeSm, t.mutedForeground
├── Frame (trackFrame, fl+1)  — height=4px, full-width del root (sin inset)
│   └── Texture (trackBg)     — BACKGROUND, t.muted fill
├── Frame (fill, fl+2)        — anclado a trackFrame.TOPLEFT, width = posX (driven by value)
│   └── Texture (fillBg)      — BACKGROUND, t.primary fill, height=4px
├── Frame (thumbRing, fl+3)   — sibling anclado al thumb, 4 texturas 1px outward, t.ring/50 (hover/drag)
├── Button (thumb, fl+4)      — 12×12px; SetHitRectInsets(-8) para agarre fácil
│   ├── Texture (thumbBg)     — BACKGROUND, blanco {r=1,g=1,b=1,a=1}
│   └── Texture (thumbBorder×4)— BORDER, 1px cada arista, t.ring
├── FontString (minLabel)     — OVERLAY, TOPLEFT→trackFrame.BOTTOMLEFT, fontSizeSm, t.mutedForeground
└── FontString (maxLabel)     — OVERLAY, TOPRIGHT→trackFrame.BOTTOMRIGHT, fontSizeSm, t.mutedForeground
```

Frame levels explícitos (fl+1..fl+4) garantizan z-order: track < fill < ring < thumb.
Todos los labels usan **ancla única** al `trackFrame` (no doble ancla) para evitar el
bug #2 de FontStrings (texto invisible hasta `/reload` si el padre tiene width 0).

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
| Border          | `t.ring` = {r=0.452, g=0.452, b=0.452, a=1}      |
| Ring hover/drag | `t.ring` a=0.5 = {r=0.452, g=0.452, b=0.452, a=0.5} (`ring-ring/50`) |
| Forma           | `rounded-none` (cuadrado)                         |

No hay variantes de tamaño (`lg` no existe en Lyra slider). El thumb es siempre 12×12px.

El thumb es un `Button` posicionado con:
```lua
local thumbCenterX = THUMB_SZ / 2 + ratio * (trackW - THUMB_SZ)
thumb:SetPoint("CENTER", trackFrame, "LEFT", thumbCenterX, 0)
```
donde `ratio = (value - min) / (max - min)`.

El `trackFrame` es **full-width** del root frame (sin inset horizontal). La fórmula constraina el thumb para que su borde LEFT quede flush con el root frame en `min`, y su borde RIGHT flush en `max`. No hay padding implícito — el slider se comporta igual que los demás componentes al posicionarlo en un form.

### Altura total del root frame

Layout simétrico: todos los labels se anclan al `trackFrame`. El gap se deriva de shadcn:
shadcn usa `gap-2` (8px) entre el label component y el slider, donde el slider comienza en el thumb.
El thumb se extiende `THUMB_SZ/2 − TRACK_H/2 = 4px` sobre el track → `LABEL_PAD = 8 + 4 = 12px`.

`topPad = hasHeader ? (LABEL_H + LABEL_PAD_TOP) : THUMB_SZ/2` — `botPad = showMinMax ? (LABEL_H + LABEL_PAD_BOT) : THUMB_SZ/2`
`frameH = topPad + TRACK_H + botPad`

| Configuración                                    | Height | topPad | botPad | Gap top↕thumb | Gap thumb↕bottom |
|--------------------------------------------------|--------|--------|--------|----------------|------------------|
| Sin label, sin showMinMax                        | 16px   | 6      | 6      | —              | —                |
| Sin label, solo `showMinMax=true`                | 28px   | 6      | 18     | —              | 2px              |
| Con label/value, sin showMinMax                  | 30px   | 20     | 6      | 4px            | —                |
| **Con label/value + `showMinMax=true`**          | **42px** | 20   | 18     | 4px            | 2px              |

`LABEL_H = 12` · `LABEL_PAD_TOP = 8` · `LABEL_PAD_BOT = 6` · `THUMB_SZ = 12` · `TRACK_H = 4`

> **[Craft design decision]** Los gaps son intencionalmente asimétricos y más ajustados que el `gap-2` de shadcn.
> shadcn muestra asimetría en su demo porque la fila superior usa `text-2xl` para el valor (fila alta), mientras min/max usa `cn-field-description` (compacto). Craft usa `fontSizeSm` para ambos, así que los gaps se definen directamente por la distancia visual al thumb:
> - `LABEL_PAD_TOP = 8` → **4px** visual (label bottom → thumb top): label/valor es contenido primario.
> - `LABEL_PAD_BOT = 6` → **2px** visual (thumb bottom → min/max top): min/max es referencia secundaria, se acerca al track.

### Labels

Todos los labels se anclan al `trackFrame` (no al root frame), con `LABEL_PAD = 12px` simétrico.
Esto replica el `gap-2` de shadcn en ambos lados: label/value arriba, min/max abajo.

| Label        | Anchor                                                              | Font size         | Color               | Origen |
|--------------|---------------------------------------------------------------------|-------------------|---------------------|--------|
| `label`      | `BOTTOMLEFT` de `trackFrame.TOPLEFT` + `(0, LABEL_PAD_TOP)` — L-align | `fontSizeSm` 11px | `t.foreground`      | **Craft extension** |
| `valueLabel` | `BOTTOMRIGHT` de `trackFrame.TOPRIGHT` + `(0, LABEL_PAD_TOP)` — R-align | `fontSizeSm` 11px | `t.mutedForeground` | shadcn |
| `minLabel`   | `TOPLEFT` de `trackFrame.BOTTOMLEFT` + `(0, -LABEL_PAD_BOT)`      | `fontSizeSm` 11px | `t.mutedForeground` | shadcn |
| `maxLabel`   | `TOPRIGHT` de `trackFrame.BOTTOMRIGHT` + `(0, -LABEL_PAD_BOT)`    | `fontSizeSm` 11px | `t.mutedForeground` | shadcn |

Cuando `label` y `showValue` están presentes simultáneamente, forman un row justify-between justo encima del track, replicando el demo oficial de shadcn.

## Variantes visuales

No hay variantes de tamaño ni color. El slider tiene un único tamaño (thumb 12×12px).

## Estados

| Estado     | Track fill  | Track bg    | Thumb bg                 | Thumb border | Thumb ring                      |
|------------|-------------|-------------|--------------------------|--------------|----------------------------------|
| Default    | `t.primary` | `t.muted`   | Blanco {r=1,g=1,b=1,a=1} | `t.ring`     | Oculto                           |
| Hover      | `t.primary` | `t.muted`   | Blanco {r=1,g=1,b=1,a=1} | `t.ring`     | Visible, `t.ring` a=0.5 (1px outward) |
| Dragging   | `t.primary` | `t.muted`   | Blanco {r=1,g=1,b=1,a=1} | `t.ring`     | Visible, `t.ring` a=0.5 (1px outward) |
| Disabled   | `t.primary` | `t.muted`   | Blanco {r=1,g=1,b=1,a=1} | `t.ring`     | Oculto — todo a `SetAlpha(0.5)` |

**Nota sobre el ring en hover**: `hover:ring-1` en CSS corresponde a `OnEnter` del mouse en WoW — es hover de mouse, NO keyboard focus. Según ADR-0011 (WoW es mouse-only), el ring de hover SÍ se implementa: mostrar el thumbRing en `thumb:SetScript("OnEnter", ...)` y ocultarlo en `"OnLeave"` (excepto durante drag activo). El ring tiene 1px de grosor — usar `Craft.Theme.SetPixelHeight/Width(thumbRing, 1)`.

En estado disabled (shadcn `disabled:opacity-50`): `frame:SetAlpha(0.5)` + `frame:EnableMouse(false)` + `thumb:EnableMouse(false)`. **No** se recolorean track/fill/thumb — solo se atenúa todo el frame al 50%.

## Mapa de tokens

| Elemento                  | Token / Valor                                          |
|---------------------------|--------------------------------------------------------|
| Track bg                  | `t.muted`                                              |
| Fill track                | `t.primary`                                            |
| Thumb bg                  | Blanco {r=1, g=1, b=1, a=1}                           |
| Thumb border              | `t.ring` = {r=0.452, g=0.452, b=0.452, a=1}           |
| Thumb ring (hover/drag)   | `t.ring` a=0.5 = {r=0.452, g=0.452, b=0.452, a=0.5}  |
| Thumb bg disabled         | `t.muted`                                              |
| Track bg disabled         | `t.muted`                                              |
| Fill track disabled       | `t.muted`                                              |
| Value label               | `t.mutedForeground`                                    |
| Min/max labels            | `t.mutedForeground`                                    |

## Config — `Create(parent, config)`

| Parámetro    | Tipo       | Default   | Descripción                                                                  |
|--------------|------------|-----------|------------------------------------------------------------------------------|
| `min`        | `number`   | `0`       | Valor mínimo del rango                                                       |
| `max`        | `number`   | `100`     | Valor máximo del rango                                                       |
| `value`      | `number`   | `min`     | Valor inicial (default = `min`)                                              |
| `step`       | `number`   | `1`       | Incremento mínimo por paso                                                   |
| `disabled`   | `boolean`  | `false`   | Deshabilita la interacción                                                   |
| `showValue`  | `boolean`  | `false`   | Muestra el valor actual en el header row (TOPRIGHT), `t.mutedForeground`. Si `label` también está presente, comparten el mismo row (justify-between). |
| `showMinMax` | `boolean`  | `false`   | Muestra `minLabel` y `maxLabel` en los extremos del track                    |
| `onChange`   | `function` | `nil`     | `fn(value)` — se dispara al cambiar el valor (click/rueda/drag)             |
| `width`      | `number`   | `nil`     | Ancho fijo en px. Si es nil, ocupa 100% del parent                           |
| `height`     | `number`   | `nil`     | Altura del frame root en px. Si es nil usa el valor por defecto (ver tabla de alturas). **Corrección post-testing en WoW:** necesario para embeber el slider en containers con altura variable (e.g. footer del Browser). |
| `label`      | `string`   | `nil`     | **Craft extension** — texto descriptivo sobre el track. Agrega 20px al `topPad` (LABEL_H=12 + LABEL_PAD_TOP=8). No está en shadcn Lyra; shadcn usa `<Label>` externo. |

No hay parámetro `size` — el slider tiene un único tamaño de thumb (12×12px).

## API pública

| Método                  | Descripción                                                                   |
|-------------------------|-------------------------------------------------------------------------------|
| `SetValue(n)`           | Establece el valor. Actualiza fill track, posición del thumb y valueLabel     |
| `GetValue()`            | Retorna el valor actual                                                       |
| `SetEnabled(bool)`      | Habilita/deshabilita. `SetAlpha(0.5)` en el frame + corta el mouse (no recolorea) |
| `SetRange(min, max)`    | Actualiza `self._min`/`_max`, reclampa el valor y reposiciona el thumb (`_updateVisuals`) |
| `SetLabel(text)`        | **Craft extension** — actualiza el texto del label en runtime. Solo funciona si `config.label` fue provisto en `Create`. |
| `GetFrame()`            | Retorna el frame root del componente                                          |

## Notas de implementación

- **Pure-custom (NO Slider nativo)**: el bug #3 (CLAUDE.md) — el bounding box invisible del `Slider` nativo ocluye FontStrings del padre sin importar el `FrameLevel` — obliga a una implementación 100% custom. El track y el fill son `Frame`s; el thumb es un `Button`. No usar `CreateFrame("Slider", …)` ni `SetThumbTexture`/`SetMinMaxValues`/`SetValueStep`/`OnValueChanged`.
- **trackFrame full-width**: `Frame` (fl+1) anclado `TOPLEFT`/`TOPRIGHT` al root, height 4px, sin inset horizontal. El thumb se constraina por fórmula (abajo), no por padding del track.
- **Fill**: `Frame` (fl+2) anclado a `trackFrame.TOPLEFT`, height 4px, width = `posX`. Se oculta cuando `ratio == 0`.
- **Posición del thumb** (en `_updateVisuals`):
  ```lua
  local ratio = (value - min) / (max - min)
  local posX  = THUMB_SZ / 2 + ratio * (trackW - THUMB_SZ)
  thumb:SetPoint("CENTER", trackFrame, "LEFT", posX, 0)
  ```
  La fórmula constraina el thumb a `[THUMB_SZ/2, trackW - THUMB_SZ/2]` → borde LEFT flush en min, RIGHT flush en max.
- **Interacción**: click en el track (`frame:OnMouseDown`) salta al valor bajo el cursor (ignorando la fila de labels); rueda (`OnMouseWheel`) incrementa por `step`; drag del thumb (`thumb:OnMouseDown`+`OnUpdate` leyendo `GetCursorPosition()`, fin en `OnMouseUp`). Todo vía `_updateFromCursor`, que snapea al `step`.
- **Hit area del thumb**: `thumb:SetHitRectInsets(-8, -8, -8, -8)` agranda el área de click 8px por lado (réplica de `after:-inset-2`) para que el thumb de 12px sea fácil de agarrar.
- **Ring del thumb (hover/drag)**: `hover:ring-1`/`active:ring-1` = `OnEnter`/drag en WoW (mouse-only, ADR-0011). `thumbRing` es un `Frame` hermano (fl+3) anclado al thumb con −1px por lado; 4 aristas de 1px vía `Craft.Theme.SetPixelHeight/Width`, color `t.ring` a=0.5. Visible en hover y durante drag; oculto al salir si no se está arrastrando.
- **trackW tardío**: `trackFrame:GetWidth()` puede ser 0 en `Create` (el ancho se resuelve después). `_updateVisuals` reintenta vía `OnUpdate` hasta que el width sea > 0.
- **Labels con ancla única**: anclar cada FontString a un solo punto del `trackFrame` (p.ej. `BOTTOMLEFT`→`trackFrame.TOPLEFT`), nunca doble ancla horizontal — evita el bug #2 (texto invisible hasta `/reload`).
