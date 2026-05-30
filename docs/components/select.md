# Component: Select

> Referencia shadcn: `select` — WoW frame base: `Frame` (dropdown custom)

## Propósito

Selector de opción única con trigger visible y panel dropdown flotante, implementado completamente en Lua ya que WoW no provee un widget select nativo moderno.

## Jerarquía de frames WoW

```
Frame (trigger root)                — MEDIUM strata
├── Texture (bg)                    — BACKGROUND layer, t.input fill
├── Texture (border)                — BORDER layer, 1px, t.border
├── FontString (selectedLabel)      — OVERLAY layer, padding H izquierdo, truncado con "…"
├── Texture (chevronNormal)         — ARTWORK layer, 16×16px, spacingSm del borde derecho
├── Texture (chevronRotated)        — ARTWORK layer, 16×16px, misma posición, oculto por defecto
└── Frame (ring)                    — sibling del trigger, 2px outward, t.ring (visible cuando open)

Frame (dropdownPanel)               — TOOLTIP strata (siempre sobre otros frames)
├── Texture (bg)                    — BACKGROUND layer, t.card fill
├── Texture (border)                — BORDER layer, 1px, t.border
└── ScrollFrame (itemScroll)        — ARTWORK layer
    └── Frame (scrollChild)
        └── Frame (item) × N        — 32px alto cada uno
            ├── Texture (itemBg)    — BACKGROUND layer, transparent por defecto
            └── FontString (itemLabel) — OVERLAY layer, paddingH = spacing.md (12px)
```

## Dimensiones

### Tamaños del trigger

| Tamaño    | Height | Padding H izq | Chevron offset derecho |
|-----------|--------|---------------|------------------------|
| `sm`      | 32px   | 10px          | 8px desde borde        |
| `default` | 36px   | 12px          | 8px desde borde        |
| `lg`      | 40px   | 14px          | 8px desde borde        |

Width del trigger: 100% del parent por defecto (puede fijarse con `config.width`).

El `selectedLabel` se extiende desde `paddingH` izquierdo hasta `paddingH + iconSizeSm + spacing.sm` del borde derecho (reserva espacio para el chevron).

### Panel dropdown

| Propiedad            | Valor                                              |
|----------------------|----------------------------------------------------|
| Width                | igual al width del trigger                         |
| Height por item      | 32px                                               |
| Max items visibles   | 6 (max height = 192px)                             |
| Scroll               | `ScrollFrame` activo cuando items > 6              |
| Padding interno      | 4px top/bottom del panel (antes del primer item)   |

### Ring del trigger

| Propiedad   | Valor                                          |
|-------------|------------------------------------------------|
| Offset      | −2px en cada lado (2px outward del trigger)    |
| Width       | `focusRingWidth` = 2px                         |
| Color       | `t.ring`                                       |
| Visibilidad | `Show()` cuando panel open, `Hide()` cuando closed |

## Variantes visuales

| Elemento          | Estado default      | Estado open         | Estado disabled       |
|-------------------|---------------------|---------------------|-----------------------|
| Trigger bg        | `t.input`           | `t.input`           | `t.muted`             |
| Trigger border    | `t.border`          | `t.ring`            | `t.border`            |
| Trigger ring      | Oculto              | Visible (`t.ring`)  | Oculto                |
| selectedLabel     | `t.foreground`      | `t.foreground`      | `t.mutedForeground`   |
| Chevron           | Normal (0°)         | Rotado (180°)       | `t.mutedForeground`   |

## Estados

### Trigger

| Estado     | Bg         | Border    | Ring    | Label               | Chevron              |
|------------|------------|-----------|---------|---------------------|----------------------|
| Default    | `t.input`  | `t.border`| Oculto  | `t.foreground`      | Normal, `t.mutedForeground` |
| Hover      | `t.input` α85% | `t.border` | Oculto | `t.foreground` | Normal, `t.mutedForeground` |
| Open       | `t.input`  | `t.ring`  | Visible | `t.foreground`      | Rotado 180°, `t.foreground` |
| Disabled   | `t.muted`  | `t.border`| Oculto  | `t.mutedForeground` | `t.mutedForeground`  |

Placeholder (sin valor seleccionado): `selectedLabel` muestra `config.placeholder` con color `t.mutedForeground`.

### Items del dropdown

| Estado    | Bg              | Label color             |
|-----------|-----------------|-------------------------|
| Default   | Transparent     | `t.foreground`          |
| Hover     | `t.accent`      | `t.foreground`          |
| Selected  | `t.primary`     | `t.primaryForeground`   |

## Mapa de tokens

| Elemento                  | Token                        |
|---------------------------|------------------------------|
| Trigger bg                | `t.input`                    |
| Trigger border default    | `t.border`                   |
| Trigger border open       | `t.ring`                     |
| Ring frame                | `t.ring`                     |
| Label seleccionado        | `t.foreground`               |
| Placeholder label         | `t.mutedForeground`          |
| Chevron default           | `t.mutedForeground`          |
| Chevron open              | `t.foreground`               |
| Trigger bg disabled       | `t.muted`                    |
| Label disabled            | `t.mutedForeground`          |
| Panel bg                  | `t.card`                     |
| Panel border              | `t.border`                   |
| Item bg hover             | `t.accent`                   |
| Item bg selected          | `t.primary`                  |
| Item label selected       | `t.primaryForeground`        |

## Config — `Create(parent, config)`

| Parámetro    | Tipo       | Default     | Descripción                                                                 |
|--------------|------------|-------------|-----------------------------------------------------------------------------|
| `options`    | `table`    | `{}`        | Array de `{value, label}`. Ejemplo: `{{value="en", label="English"}, ...}`  |
| `value`      | `string`   | `nil`       | Valor inicial seleccionado. `nil` muestra el placeholder                    |
| `placeholder`| `string`   | `"Select…"` | Texto en `selectedLabel` cuando no hay valor seleccionado                   |
| `size`       | `string`   | `"default"` | `"sm"`, `"default"`, `"lg"`                                                 |
| `disabled`   | `boolean`  | `false`     | Deshabilita el trigger y cierra el panel si estaba abierto                  |
| `onSelect`   | `function` | `nil`       | `fn(value, label)` — se dispara al seleccionar un item                      |
| `width`      | `number`   | `nil`       | Ancho fijo en px. Si es nil, ocupa 100% del parent                          |

## API pública

| Método                  | Descripción                                                                    |
|-------------------------|--------------------------------------------------------------------------------|
| `SetValue(value)`       | Selecciona la opción con ese value. Actualiza `selectedLabel`. No dispara `onSelect` |
| `GetValue()`            | Retorna el value actualmente seleccionado, o `nil`                             |
| `SetOptions(options)`   | Reemplaza la lista de opciones. Cierra el panel si estaba abierto              |
| `SetEnabled(bool)`      | Habilita/deshabilita el componente                                             |
| `Open()`                | Abre el panel dropdown programáticamente                                       |
| `Close()`               | Cierra el panel dropdown                                                       |
| `GetFrame()`            | Retorna el frame trigger raíz                                                  |

## Notas de implementación

- **Sin widget nativo**: WoW no tiene un `DropdownMenu` moderno suficientemente personalizable. Todo el dropdown se construye con frames, texturas y FontStrings.
- **Strata del panel**: el `dropdownPanel` debe usar `SetFrameStrata("TOOLTIP")` para aparecer siempre sobre otros frames de la UI (barras de acción, otros paneles, etc).
- **Cierre al hacer click fuera**: registrar un frame invisible (`backdropCatcher`) de tamaño de pantalla completa en strata `DIALOG` pero debajo del panel. Al hacer click en él, cerrar el dropdown. Alternativa: hookear `WorldFrame` con `HookScript("OnMouseDown", ...)` y verificar si el click fue fuera del panel y el trigger. Usar `panel:IsMouseOver()` y `trigger:IsMouseOver()` para la comprobación.
- **Posición del panel**: anclar con `SetPoint("TOPLEFT", trigger, "BOTTOMLEFT", 0, -2)`. Si el panel se sale de la pantalla por abajo, anclar con `SetPoint("BOTTOMLEFT", trigger, "TOPLEFT", 0, 2)` en su lugar. Verificar con `GetBottom()` vs `GetScreenHeight() * 0` (0 = bottom de pantalla).
- **Rotación del chevron**: WoW no tiene rotación de texturas en tiempo real. Implementar con dos texturas: `chevronNormal` (0°) y `chevronRotated` (180°, textura pre-rotada o generada con `SetTexCoord`). Mostrar una, ocultar la otra según el estado del panel. Para simular 180°: `SetTexCoord(1, 0, 0, 1)` invierte horizontalmente — combinado con inversión vertical (`SetTexCoord(1, 0, 1, 1, 0, 0, 0, 1)`) equivale a 180°.
- **ScrollFrame de items**: cuando `#options > 6`, activar el `ScrollFrame` con altura fija de 192px. El `scrollChild` tiene `SetHeight(#options * 32)`. Cada item usa `SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i-1) * 32)`.
- **Item hover**: usar `OnEnter`/`OnLeave` en cada frame de item para cambiar el color del `itemBg`. El item selected se marca visualmente aunque el panel se cierre y reabra — recordar el índice seleccionado y aplicar color `t.primary` al crear los items.
- **Borde 1px trigger y panel**: mismo enfoque que Input — cuatro texturas de 1px o `SetBackdrop` con `edgeSize=1`.
- **Hover alpha trigger**: aplicar `SetAlpha(0.85)` a la textura `bg` del trigger en `OnEnter`, restaurar en `OnLeave`. No aplicar si `disabled` o si el panel está abierto.
- **Separación visual**: el panel abre con 2px de separación del trigger (`SetPoint("TOPLEFT", trigger, "BOTTOMLEFT", 0, -2)`).
