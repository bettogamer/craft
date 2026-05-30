# Component: Separator

> Referencia shadcn: `separator` — https://ui.shadcn.com/docs/components/separator
> WoW frame base: `Frame` con una o más `Texture` hijas

## CSS de referencia (Lyra)

```css
.cn-separator {
  @apply bg-border shrink-0;
}
.cn-separator-horizontal {
  @apply h-px w-full;
}
.cn-separator-vertical {
  @apply h-full w-px;
}
```

## Propósito
Línea divisoria visual de 1px que separa secciones de contenido; soporta orientación horizontal y vertical. Es un elemento puramente decorativo: sin label, sin interacción.

## Jerarquía de frames WoW

**Horizontal:**
```
separator.frame       (Frame — nivel raíz, h=1px via SetPixelHeight, w=100% del parent)
└── separator._line   (Texture — BACKGROUND) línea de 1px con color t.border
```

**Vertical:**
```
separator.frame       (Frame — nivel raíz, w=1px via SetPixelWidth, h=100% del parent)
└── separator._line   (Texture — BACKGROUND) línea de 1px con color t.border
```

`separator.frame` es el contenedor raíz. `_line` rellena el frame completo con `SetAllPoints`. La dimensión crítica (1px) se establece con `Craft.Theme.SetPixelHeight` o `Craft.Theme.SetPixelWidth`, no con `SetHeight(1)` / `SetWidth(1)`.

**Nota**: la variante con label de texto no existe en el CSS de Lyra. El Separator es solo una línea. Si el dev necesita texto entre separadores, lo implementa manualmente con dos separadores y un label posicionados externamente.

## Dimensiones

| Orientación  | Dimensión crítica | Otra dimensión   | Método pixel-perfect              |
|--------------|-------------------|------------------|-----------------------------------|
| horizontal   | height = 1px      | width = 100%     | `Craft.Theme.SetPixelHeight(frame, 1)` |
| vertical     | width = 1px       | height = 100%    | `Craft.Theme.SetPixelWidth(frame, 1)`  |

- `h-px` y `w-px` en Tailwind = 1px físico. En WoW esto requiere `SetPixelHeight/Width`, **no** `SetHeight(1)` / `SetWidth(1)`.
- `w-full` / `h-full` = 100% del padre; implementar con `SetPoint` relativo al parent (no con `SetWidth`/`SetHeight`).
- Sin padding, sin fuente, sin ícono.

## Variantes visuales

| Orientación  | Color de línea                                  |
|--------------|-------------------------------------------------|
| horizontal   | `t.border` = {r=1,g=1,b=1,a=0.10}              |
| vertical     | `t.border` = {r=1,g=1,b=1,a=0.10}              |

Lyra no define variante con label de texto. El Separator es siempre una línea simple.

## Estados

El Separator no tiene estados. Es un elemento puramente decorativo y estático. No es focusable, hoverable ni clickeable.

## Mapa de tokens

| Elemento visual | Token / Valor dark mode               |
|-----------------|---------------------------------------|
| Línea           | `t.border` = {r=1,g=1,b=1,a=0.10}    |

## Config — `Create(parent, config)`

| Clave         | Tipo   | Default        | Descripción                      |
|---------------|--------|----------------|----------------------------------|
| `orientation` | string | `"horizontal"` | `"horizontal"` o `"vertical"`.   |

## API pública

| Método                   | Firma            | Descripción                                                       |
|--------------------------|------------------|-------------------------------------------------------------------|
| `SetOrientation(orient)` | `string → void`  | Cambia la orientación. Reconfigura todos los `SetPoint` internos. |
| `GetFrame()`             | `→ Frame`        | Devuelve el frame WoW raíz para posicionamiento externo.          |

## Notas de implementación

**Pixel-perfect (ADR-0011)**: El 1px del Separator es su dimensión principal — toda su utilidad depende de que sea exactamente 1px físico. **Obligatorio** usar `Craft.Theme.SetPixelHeight` o `Craft.Theme.SetPixelWidth`; nunca `SetHeight(1)` / `SetWidth(1)` directamente.

```lua
-- Horizontal (pixel-perfect)
Craft.Theme.SetPixelHeight(separator.frame, 1)
separator._line:SetAllPoints(separator.frame)
separator._line:SetColorTexture(1, 1, 1, 0.10)  -- t.border dark mode

-- Vertical (pixel-perfect)
Craft.Theme.SetPixelWidth(separator.frame, 1)
separator._line:SetAllPoints(separator.frame)
separator._line:SetColorTexture(1, 1, 1, 0.10)  -- t.border dark mode
```

**Border con alpha en dark mode**: `t.border` en dark mode es `{r=1, g=1, b=1, a=0.10}`. Pasar los 4 valores a `SetColorTexture`. El alpha no se multiplica por el alpha del frame padre si el frame usa `SetAlpha(1)` por defecto.

**Ancho al 100% del parent**: Usar `SetPoint("LEFT", parent, "LEFT")` + `SetPoint("RIGHT", parent, "RIGHT")` en lugar de `SetWidth()` para que el ancho sea relativo y se adapte si el parent cambia de tamaño.

**Altura al 100% del parent (vertical)**: Análogamente, usar `SetPoint("TOP", parent, "TOP")` + `SetPoint("BOTTOM", parent, "BOTTOM")` para la altura.

**Sin variante con label**: El Separator de Lyra es solo una línea. Si el dev necesita texto entre separadores, lo implementa manualmente posicionando dos `Separator` y un `Label` desde el contenedor padre.
