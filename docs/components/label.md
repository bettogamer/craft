# Component: Label

> Referencia shadcn: `label` — https://ui.shadcn.com/docs/components/label
> WoW frame base: `FontString` (o `Frame` con FontString hijo si se requiere fondo o padding)

## Propósito
Componente de texto puro para etiquetas, títulos de sección, captions y texto auxiliar; sin fondo ni borde por defecto, con variantes de peso, tamaño y color.

## Jerarquía de frames WoW

```
label.frame           (Frame — nivel raíz, solo necesario si onClick o maxWidth están presentes)
└── label._text       (FontString — OVERLAY) texto renderizado con la fuente y variante configurada
```

**Caso simple (sin onClick ni maxWidth)**: `label.frame` puede omitirse y `label._text` puede ser un FontString directamente anclado al parent. La función `Create` siempre devuelve un objeto con `GetFrame()` que expone el FontString raíz.

**Caso con onClick**: Se necesita un Frame padre para recibir `OnEnter`/`OnLeave`/`OnMouseDown`, ya que los FontStrings no pueden registrar eventos de ratón en WoW.

**Caso con maxWidth**: El FontString se configura con `_text:SetWidth(maxWidth)` y `_text:SetNonSpaceWrap(false)` para truncar con "..." automáticamente vía `SetWordWrap(false)`.

## Dimensiones

### Tamaños
| Variante de tamaño | Alto (px)     | Pad H (px) | Pad V (px) | Fuente (px)  | Ícono (px) |
|-------------------|---------------|-----------|-----------|-------------|-----------|
| sm (caption)      | auto          | 0         | 0         | 11          | —         |
| default           | auto          | 0         | 0         | 12          | —         |
| lg (heading)      | auto          | 0         | 0         | 14          | —         |

- El alto es siempre `auto` — el FontString crece con el contenido.
- Sin padding por defecto; el espaciado lo gestiona el contenedor padre.
- Cuando `onClick` está presente, el Frame padre tiene el mismo tamaño que el FontString (sin padding extra).

### Variantes visuales
| Variante  | Fuente              | Tamaño (px) | Color texto           | Hover (si onClick)     |
|-----------|---------------------|-------------|-----------------------|------------------------|
| default   | `t.font` (regular)  | 12          | `t.foreground`        | `t.primary`            |
| muted     | `t.font` (regular)  | 12          | `t.mutedForeground`   | `t.primary`            |
| heading   | `t.fontBold` (bold) | 14          | `t.foreground`        | `t.primary`            |
| caption   | `t.font` (regular)  | 11          | `t.mutedForeground`   | `t.primary`            |

## Estados
| Estado           | Fondo      | Texto                 | Borde | Ring               |
|------------------|------------|-----------------------|-------|--------------------|
| default          | —          | según variante        | —     | —                  |
| hover (onClick)  | —          | `t.primary`           | —     | —                  |
| focus (onClick)  | —          | `t.primary`           | —     | `t.ring` 2px outward |
| disabled         | —          | `t.mutedForeground`   | —     | —                  |

- Los estados de interacción solo aplican cuando `onClick` está configurado.
- No hay estado hover visible cuando no hay `onClick` — el Label es puramente decorativo.
- El estado `focus` aplica solo cuando el Label es navegable por Tab (cuando `onClick` está presente).

## Mapa de tokens
| Elemento visual              | Token                  |
|------------------------------|------------------------|
| Texto (default)              | `t.foreground`         |
| Texto (muted / caption)      | `t.mutedForeground`    |
| Texto (heading)              | `t.foreground`         |
| Texto hover (onClick)        | `t.primary`            |
| Texto disabled               | `t.mutedForeground`    |
| Fuente regular               | `t.font`               |
| Fuente negrita (heading)     | `t.fontBold`           |
| Focus ring (onClick)         | `t.ring`               |

## Config — `Create(parent, config)`
| Clave      | Tipo     | Default      | Descripción                                                                                      |
|------------|----------|--------------|--------------------------------------------------------------------------------------------------|
| `text`     | string   | `""`         | Texto a mostrar.                                                                                 |
| `variant`  | string   | `"default"`  | `"default"`, `"muted"`, `"heading"`, `"caption"`.                                               |
| `maxWidth` | number   | `nil`        | Ancho máximo en px. Si el texto supera este ancho, se trunca con "..." al final.                  |
| `onClick`  | function | `nil`        | Callback `function(self)`. Activa cursor hand en hover y color `t.primary` en hover.             |

## API pública
| Método              | Firma            | Descripción                                                                           |
|---------------------|------------------|---------------------------------------------------------------------------------------|
| `SetText(text)`     | `string → void`  | Cambia el texto. Respeta el `maxWidth` si está configurado.                           |
| `SetVariant(variant)` | `string → void` | Cambia variante: fuente, tamaño y color. Repinta el FontString inmediatamente.       |
| `GetFrame()`        | `→ Frame`        | Devuelve el frame WoW raíz (Frame o FontString) para posicionamiento externo.         |

## Notas de implementación

**FontString puro vs. Frame contenedor**: Si `config.onClick == nil` y `config.maxWidth == nil`, el objeto puede exponer directamente un `FontString` sin Frame padre. Esto reduce el overhead de frames en layouts densos con muchos Labels. Si cualquiera de las dos opciones está presente, crear siempre un Frame padre.

**Truncado con maxWidth**: Configurar `_text:SetWidth(config.maxWidth)` y `_text:SetWordWrap(false)`. WoW truncará el texto automáticamente con "..." cuando supere el ancho. Importante: `SetNonSpaceWrap(false)` evita que palabras largas sin espacios rompan el truncado.

**Cursor hand en onClick**: En `OnEnter`, llamar `SetCursor("Interface\\CURSOR\\Point")`. En `OnLeave`, llamar `SetCursor(nil)`. Simultáneamente cambiar `_text:SetTextColor(t.primary.r, t.primary.g, t.primary.b)` en `OnEnter` y restaurar el color de la variante en `OnLeave`.

**Focus ring**: Cuando `onClick` está presente y el Label es navegable por Tab, el `_ring` frame se posiciona `SetPoint("TOPLEFT", label.frame, "TOPLEFT", -2, 2)` y `SetPoint("BOTTOMRIGHT", label.frame, "BOTTOMRIGHT", 2, -2)`. Normalmente los Labels no son Tab-focusables; activar solo si el diseño lo requiere explícitamente.

**Heading bold**: La variante `heading` usa `t.fontBold` = `Inter-Bold.ttf`. Llamar `_text:SetFont(t.fontBold, t.fontSizeLg)` — no intentar usar flags `OUTLINE` o `THICKOUTLINE` de WoW, que distorsionan Inter.

**SetTextColor vs. SetVertexColor**: Para cambiar el color del texto usar `FontString:SetTextColor(r, g, b, a)`. No usar `SetVertexColor` en un FontString, ya que afecta la opacidad global incluyendo la textura interna y puede producir resultados inesperados.

**Integración con Input y otros componentes**: El Label se usa habitualmente como etiqueta de campos. El posicionamiento relativo al campo (encima o a la izquierda) es responsabilidad del contenedor padre, no del Label. El Label no tiene conocimiento de su campo asociado.
