# Component: Button

> Referencia shadcn: `button` — https://ui.shadcn.com/docs/components/button
> WoW frame base: `Button`

## Propósito
Elemento interactivo que ejecuta una acción al hacer clic, con soporte para múltiples variantes visuales (relleno, contorno, fantasma, destructivo, link) y estados de interacción completos.

## Jerarquía de frames WoW

```
button.frame          (Button — nivel raíz, recibe eventos OnClick, OnEnter, OnLeave)
├── button._bg        (Texture — BACKGROUND) fondo principal sólido del botón
├── button._border    (Texture — BORDER)     borde de 1px, visible según variante
├── button._ring      (Frame — OVERLAY)      focus ring de 2px, oculto por defecto
│   └── _ring._tex    (Texture — OVERLAY)    textura del ring coloreada con t.ring
├── button._icon      (Texture — ARTWORK)    ícono Lucide 16×16, visible si config.icon
└── button._label     (FontString — OVERLAY) texto del botón
```

`button.frame` es un frame nativo `Button` de WoW, lo que le da `OnClick` sin código extra. `_bg` y `_border` son texturas separadas para poder cambiar colores independientemente según estado y variante. `_ring` es un Frame hijo ligeramente más grande que el padre (expandido 2px en cada lado) para lograr el efecto outward. `_icon` se posiciona a la izquierda o derecha del label según `iconPosition`.

## Dimensiones

### Tamaños
| Variante de tamaño | Alto (px) | Pad H (px) | Pad V (px) | Fuente (px) | Ícono (px) |
|-------------------|-----------|-----------|-----------|------------|-----------|
| xs               | 24        | 8         | 4         | 11         | 16        |
| sm               | 28        | 10        | 6         | 11         | 16        |
| default          | 36        | 12        | 8         | 12         | 16        |
| lg               | 40        | 16        | 10        | 14         | 16        |
| icon-sm          | 24        | 4         | 4         | —          | 16        |
| icon-default     | 36        | 8         | 8         | —          | 16        |

- `icon-sm` y `icon-default` son cuadrados (ancho = alto). No tienen label.
- El ancho de los tamaños no-icono es dinámico: `pad_h * 2 + label_width + (icon ? icon_size + spacingXs : 0)`.
- Gap entre ícono y texto: `spacingXs` = 4px.

### Variantes visuales
| Variante    | Fondo            | Texto                    | Borde         | Hover fondo                    |
|-------------|------------------|--------------------------|---------------|-------------------------------|
| default     | `t.primary`      | `t.primaryForeground`    | —             | `t.primary` a=0.85            |
| destructive | `t.destructive`  | `t.foreground`           | —             | `t.destructive` a=0.85        |
| outline     | transparente     | `t.foreground`           | `t.border`    | `t.accent` a=1                |
| secondary   | `t.secondary`    | `t.secondaryForeground`  | —             | `t.secondary` a=0.85          |
| ghost       | transparente     | `t.foreground`           | —             | `t.accent` a=1                |
| link        | transparente     | `t.primary`              | —             | transparente (underline hover) |

## Estados
| Estado   | Fondo                          | Texto                   | Borde         | Ring               |
|----------|--------------------------------|-------------------------|---------------|--------------------|
| default  | según variante                 | según variante          | según variante | —                 |
| hover    | según variante (alpha reducido o accent) | según variante | según variante | —          |
| focus    | según variante                 | según variante          | según variante | `t.ring` 2px outward |
| disabled | `t.muted` a=0.5                | `t.mutedForeground`     | `t.border`    | —                  |

- En estado **disabled** el fondo muestra `t.muted` con alpha 0.5 independientemente de la variante, y el borde siempre usa `t.border`.
- Para `link` en hover no hay cambio de fondo; se simula subrayado configurando el FontString con una textura de línea de 1px bajo el texto (Frame hijo `_underline`, oculto por defecto, visible en OnEnter).
- El `_ring` frame solo se muestra en focus (Tab-navegación o foco programático); los botones normalmente no muestran ring en hover.

## Mapa de tokens
| Elemento visual          | Token                    |
|--------------------------|--------------------------|
| Fondo (default)          | `t.primary`              |
| Fondo (destructive)      | `t.destructive`          |
| Fondo (secondary)        | `t.secondary`            |
| Fondo hover (ghost/outline) | `t.accent`            |
| Texto (default)          | `t.primaryForeground`    |
| Texto (secondary)        | `t.secondaryForeground`  |
| Texto (outline/ghost)    | `t.foreground`           |
| Texto (link)             | `t.primary`              |
| Texto (disabled)         | `t.mutedForeground`      |
| Fondo (disabled)         | `t.muted` a=0.5          |
| Borde (outline)          | `t.border`               |
| Borde (disabled)         | `t.border`               |
| Focus ring               | `t.ring`                 |
| Fuente base              | `t.font` / `t.fontSize`  |

## Config — `Create(parent, config)`
| Clave          | Tipo     | Default      | Descripción                                              |
|----------------|----------|--------------|----------------------------------------------------------|
| `text`         | string   | `""`         | Texto visible del botón.                                 |
| `size`         | string   | `"default"`  | `"xs"`, `"sm"`, `"default"`, `"lg"`, `"icon-sm"`, `"icon-default"`. |
| `variant`      | string   | `"default"`  | `"default"`, `"destructive"`, `"outline"`, `"secondary"`, `"ghost"`, `"link"`. |
| `disabled`     | boolean  | `false`      | Si `true`, suprime OnClick/OnEnter y aplica estilo disabled. |
| `icon`         | string   | `nil`        | Nombre del ícono Lucide (e.g. `"check"`, `"x"`). Requiere atlas. |
| `iconPosition` | string   | `"left"`     | `"left"` o `"right"`. Ignorado si `icon` es nil.        |
| `onClick`      | function | `nil`        | Callback `function(self)` ejecutado en OnClick.          |

## API pública
| Método                    | Firma                     | Descripción                                                    |
|---------------------------|---------------------------|----------------------------------------------------------------|
| `SetText(text)`           | `string → void`           | Cambia el texto del label y recalcula el ancho del frame.      |
| `SetEnabled(enabled)`     | `boolean → void`          | Activa o desactiva el botón; aplica/quita estilo disabled.     |
| `SetVariant(variant)`     | `string → void`           | Cambia la variante visual y repinta todos los tokens.          |
| `GetFrame()`              | `→ Frame`                 | Devuelve el frame WoW raíz para posicionamiento externo.       |

## Notas de implementación

**OnClick nativo de Button**: WoW's `Button` frame tiene `SetScript("OnClick", fn)` incorporado. No es necesario crear un frame `Frame` con detección manual de clics. Usar `button:SetScript("OnClick", config.onClick)` directamente.

**Texto en Button**: Los frames `Button` de WoW tienen `button:SetText()` nativo, pero Craft debe usar su propio FontString hijo (`_label`) para control total sobre fuente, tamaño y color vía `t.font`. Crear con `button.frame:CreateFontString("$parent_label", "OVERLAY")` y llamar `_label:SetFont(t.font, t.fontSize)`.

**Ícono Lucide**: Los íconos se renderizan como texturas de atlas. El atlas `lucide-16.tga` contiene todos los íconos de 16px. Usar `_icon:SetAtlas("lucide-" .. config.icon)` o, si el atlas no está disponible, `_icon:SetTexture(...)` con coordenadas UV calculadas. Posicionar con `SetPoint("LEFT", _label, "LEFT", -(iconSize + spacingXs), 0)` para `iconPosition="left"` o `SetPoint("RIGHT", _label, "RIGHT", iconSize + spacingXs, 0)` para `"right"`.

**Variante link — cursor hand**: En OnEnter para la variante `link`, llamar `SetCursor("Interface\\CURSOR\\Point")`. En OnLeave, `SetCursor(nil)` para restaurar el cursor por defecto.

**Variante link — subrayado**: Crear un Frame hijo `_underline` con altura 1px y anchura igual al texto. Posicionarlo `SetPoint("TOPLEFT", _label, "BOTTOMLEFT", 0, 0)`. Usar `_underline._tex:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 1)`. Mostrar en OnEnter, ocultar en OnLeave.

**Focus ring outward**: El frame `_ring` debe tener `SetPoint("TOPLEFT", button.frame, "TOPLEFT", -2, 2)` y `SetPoint("BOTTOMRIGHT", button.frame, "BOTTOMRIGHT", 2, -2)`, con una textura de borde (no relleno). Implementar como 4 texturas de 2px (top, right, bottom, left) dentro del `_ring` frame, todas con color `t.ring`.

**Disabled — suprimir eventos**: Llamar `button.frame:EnableMouse(false)` y `button.frame:SetScript("OnClick", nil)` cuando `disabled=true`. Restaurar con `EnableMouse(true)` y reasignar el callback cuando `disabled=false`.

**Hover alpha blend**: Para variantes con fondo sólido (default, destructive, secondary), el hover reduce el alpha del fondo al 85%: `_bg:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 0.85)`. No cambiar el RGB — solo el alpha.
