# Component: Separator

> Referencia shadcn: `separator` — https://ui.shadcn.com/docs/components/separator
> WoW frame base: `Frame` con una o más `Texture` hijas

## Propósito
Línea divisoria visual de 1px que separa secciones de contenido; soporta orientación horizontal y vertical, y una variante con label de texto centrado que interrumpe la línea.

## Jerarquía de frames WoW

**Sin label (horizontal):**
```
separator.frame       (Frame — nivel raíz, h=1px, w=parent width)
└── separator._line   (Texture — BACKGROUND) línea de 1px con color t.border
```

**Sin label (vertical):**
```
separator.frame       (Frame — nivel raíz, w=1px, h=parent height)
└── separator._line   (Texture — BACKGROUND) línea de 1px con color t.border
```

**Con label (horizontal):**
```
separator.frame       (Frame — nivel raíz, h=auto, w=parent width)
├── separator._lineL  (Texture — BACKGROUND) mitad izquierda de la línea
├── separator._label  (FontString — OVERLAY)  texto centrado con t.mutedForeground
└── separator._lineR  (Texture — BACKGROUND) mitad derecha de la línea
```

`separator.frame` es el contenedor raíz. En la variante sin label, `_line` rellena el frame completo. En la variante con label, `_lineL` y `_lineR` se anclan al label desde los lados; el label se centra en el frame. Todas las líneas tienen exactamente 1px de grosor.

## Dimensiones

### Tamaños
| Variante de tamaño | Alto (px) | Ancho (px)      | Pad H (px) | Pad V (px) | Fuente (px) | Ícono (px) |
|-------------------|-----------|-----------------|-----------|-----------|------------|-----------|
| horizontal        | 1         | 100% del parent | 0         | 0         | —          | —         |
| vertical          | 100% del parent | 1        | 0         | 0         | —          | —         |
| horizontal+label  | 11 (altura del texto fontSizeSm) | 100% del parent | 0 | 0 | 11 | — |

- En la variante `horizontal+label`, el alto del frame es el alto del FontString con `fontSizeSm` = 11px. Las líneas `_lineL` y `_lineR` tienen 1px de alto y se centran verticalmente en ese frame de 11px (offset vertical = 5px desde el top, o `SetPoint("LEFT", ..., "VCENTER")`).
- El gap entre cada extremo de la línea y el texto es `spacingSm` = 8px a cada lado.

### Variantes visuales
| Variante           | Línea       | Texto label         | Fondo texto         |
|--------------------|-------------|---------------------|---------------------|
| horizontal         | `t.border`  | —                   | —                   |
| vertical           | `t.border`  | —                   | —                   |
| horizontal + label | `t.border`  | `t.mutedForeground` | `t.background`¹     |

¹ El fondo del label no es una textura adicional — el texto se dibuja sobre la línea y el fondo del contenedor padre "rompe" visualmente la línea. No se necesita una textura de fondo explícita si el parent tiene un fondo sólido. En contenedores con fondo transparente esto puede requerir una textura de 1px de alto y ancho del label con el color del parent.

## Estados
| Estado  | Fondo       | Texto               | Borde  | Ring |
|---------|-------------|---------------------|--------|------|
| default | —           | `t.mutedForeground` | —      | —    |

El Separator no tiene estados de interacción. Es un elemento puramente decorativo y estático. No es focusable, hoverable ni clickeable.

## Mapa de tokens
| Elemento visual         | Token                |
|-------------------------|----------------------|
| Línea divisoria         | `t.border`           |
| Texto del label         | `t.mutedForeground`  |
| Fuente del label        | `t.font`             |
| Tamaño fuente del label | `t.fontSizeSm` (11px) |

## Config — `Create(parent, config)`
| Clave         | Tipo   | Default        | Descripción                                                                    |
|---------------|--------|----------------|--------------------------------------------------------------------------------|
| `orientation` | string | `"horizontal"` | `"horizontal"` o `"vertical"`.                                                 |
| `label`       | string | `nil`          | Texto opcional centrado en la línea. Solo aplica cuando `orientation="horizontal"`. |

## API pública
| Método                  | Firma            | Descripción                                                                      |
|-------------------------|------------------|----------------------------------------------------------------------------------|
| `SetOrientation(orient)` | `string → void` | Cambia la orientación. Reconfigura todos los `SetPoint` internos.                |
| `SetLabel(text)`        | `string → void`  | Establece o elimina el label. `nil` o `""` vuelve al modo línea simple.          |
| `GetFrame()`            | `→ Frame`        | Devuelve el frame WoW raíz para posicionamiento externo.                         |

## Notas de implementación

**Línea de 1px**: En WoW, una línea horizontal de 1px se crea con:
```lua
separator.frame:SetHeight(1)
separator._line:SetAllPoints(separator.frame)
separator._line:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)
```
Para una línea vertical de 1px:
```lua
separator.frame:SetWidth(1)
separator._line:SetAllPoints(separator.frame)
separator._line:SetColorTexture(t.border.r, t.border.g, t.border.b, t.border.a)
```
No usar `SetHeight(1)` + `SetWidth(0)` — WoW requiere dimensiones positivas para renderizar.

**Border con alpha en dark mode**: `t.border` en dark mode es `{r=1, g=1, b=1, a=0.1}`. Pasar los 4 valores a `SetColorTexture`: `SetColorTexture(1, 1, 1, 0.1)`. El alpha no se multiplica por el alpha del frame padre si el frame usa `SetAlpha(1)` por defecto.

**Variante con label — posicionamiento**: No usar Flex ni StackLayout. Posicionar manualmente con `SetPoint`:
```lua
-- Label centrado en el frame
separator._label:SetPoint("CENTER", separator.frame, "CENTER", 0, 0)

-- Línea izquierda: desde el borde izquierdo del frame hasta spacingSm antes del label
separator._lineL:SetPoint("LEFT", separator.frame, "LEFT", 0, 0)
separator._lineL:SetPoint("RIGHT", separator._label, "LEFT", -8, 0)  -- -spacingSm
separator._lineL:SetHeight(1)

-- Línea derecha: desde spacingSm después del label hasta el borde derecho del frame
separator._lineR:SetPoint("LEFT", separator._label, "RIGHT", 8, 0)   -- spacingSm
separator._lineR:SetPoint("RIGHT", separator.frame, "RIGHT", 0, 0)
separator._lineR:SetHeight(1)
```
Las líneas `_lineL` y `_lineR` se centran verticalmente respecto al label usando el offset Y del `SetPoint`. Si el frame raíz tiene 11px de alto (fontSizeSm) y la línea es de 1px, usar Y offset = 0 cuando ambos se anclan al centro vertical del frame.

**Ancho al 100% del parent**: Al crear el Separator, usar `SetPoint("LEFT", parent, "LEFT")` + `SetPoint("RIGHT", parent, "RIGHT")` en lugar de `SetWidth()` para que el ancho sea relativo y se adapte si el parent cambia de tamaño.

**Variante vertical — altura al 100%**: Análogamente, usar `SetPoint("TOP", parent, "TOP")` + `SetPoint("BOTTOM", parent, "BOTTOM")` para la altura. La variante vertical no soporta label.

**Label solo en horizontal**: Si se llama `SetLabel` con un texto mientras `orientation="vertical"`, ignorar silenciosamente (o loggear un warning). El label en vertical no está especificado y no debe implementarse.

**SetLabel(nil) — transición a línea simple**: Al quitar el label, ocultar `_lineL`, `_lineR` y `_label`; mostrar `_line` con `SetAllPoints`. Si `_line` no existe aún (porque el Separator fue creado con label), crearlo en este momento y anclarlo al frame completo.
