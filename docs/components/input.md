# Component: Input

> Referencia shadcn: `input` — WoW frame base: `EditBox`

## Propósito

Campo de texto editable de una sola línea, con soporte de placeholder, estados de error, iconos leading/trailing y focus ring.

## Jerarquía de frames WoW

```
Frame (root)                        — BACKGROUND layer
├── Texture (bg)                    — BACKGROUND layer, t.input fill
├── Texture (border)                — BORDER layer, 1px, t.border
├── Frame (ring)                    — sibling del root, 2px outward, t.ring (visible solo en foco)
├── Texture (iconLeading)           — ARTWORK layer, 16×16px, visible si config.iconLeading
├── Texture (iconTrailing)          — ARTWORK layer, 16×16px, visible si config.iconTrailing
├── EditBox                         — OVERLAY layer, centrado verticalmente con insets
└── FontString (placeholder)        — OVERLAY layer, visible cuando EditBox vacío y sin foco
```

## Dimensiones

### Tamaños del componente

| Tamaño    | Height | Padding H | Font size | EditBox inset top/bottom |
|-----------|--------|-----------|-----------|--------------------------|
| `sm`      | 32px   | 10px      | 11px      | 8px                      |
| `default` | 36px   | 12px      | 12px      | 10px                     |
| `lg`      | 40px   | 14px      | 12px      | 12px                     |

Width: 100% del parent por defecto (puede fijarse con `config.width`).

### Ajuste de padding con iconos

| Condición         | Padding H lado afectado |
|-------------------|------------------------|
| Sin icono         | valor base del tamaño  |
| Con iconLeading   | left += 20px           |
| Con iconTrailing  | right += 20px          |

Posición del icono:
- Leading: x = `spacing.sm` (8px) desde el borde izquierdo, centrado verticalmente.
- Trailing: x = `spacing.sm` (8px) desde el borde derecho, centrado verticalmente.
- Tamaño del icono: `iconSizeSm` = 16×16px.

### Dimensiones del ring frame

| Propiedad | Valor                                       |
|-----------|---------------------------------------------|
| Offset    | −2px en cada lado (2px outward del root)    |
| Width     | `focusRingWidth` = 2px                      |
| Color     | `t.ring`                                    |
| Visibilidad | `Show()` en foco, `Hide()` fuera de foco  |

## Variantes visuales

| Variante  | Fondo      | Border color    | Notas                                       |
|-----------|------------|-----------------|---------------------------------------------|
| `default` | `t.input`  | `t.border`      | Estado base                                 |
| `error`   | `t.input`  | `t.destructive` | Borde cambia a destructive, fondo sin cambio |

## Estados

| Estado          | Fondo      | Border color    | Ring       | Texto               | Placeholder          |
|-----------------|------------|-----------------|------------|---------------------|----------------------|
| Default         | `t.input`  | `t.border`      | Oculto     | `t.foreground`      | `t.mutedForeground`  |
| Focused         | `t.input`  | `t.ring`        | Visible    | `t.foreground`      | Oculto               |
| Disabled        | `t.muted`  | `t.border`      | Oculto     | `t.mutedForeground` | `t.mutedForeground`  |
| Error           | `t.input`  | `t.destructive` | Oculto     | `t.foreground`      | `t.mutedForeground`  |
| Error + Focused | `t.input`  | `t.destructive` | Visible    | `t.foreground`      | Oculto               |

Hover (sobre el frame raíz): alpha blend al 85% sobre el fondo — aplicar `SetAlpha(0.85)` a la textura `bg` al hacer `OnEnter`, restaurar a `1.0` en `OnLeave`. No aplica en estado disabled.

## Mapa de tokens

| Elemento              | Token                        |
|-----------------------|------------------------------|
| Fondo del input       | `t.input`                    |
| Borde default         | `t.border`                   |
| Borde focused         | `t.ring`                     |
| Borde error           | `t.destructive`              |
| Ring frame            | `t.ring`                     |
| Texto ingresado       | `t.foreground`               |
| Placeholder           | `t.mutedForeground`          |
| Fondo disabled        | `t.muted`                    |
| Texto disabled        | `t.mutedForeground`          |
| Icono leading/trailing| `t.mutedForeground` (tint)   |

## Config — `Create(parent, config)`

| Parámetro       | Tipo       | Default     | Descripción                                                              |
|-----------------|------------|-------------|--------------------------------------------------------------------------|
| `placeholder`   | `string`   | `""`        | Texto gris visible cuando el campo está vacío y sin foco                 |
| `value`         | `string`   | `""`        | Valor inicial del EditBox                                                |
| `size`          | `string`   | `"default"` | `"sm"`, `"default"`, `"lg"`                                              |
| `disabled`      | `boolean`  | `false`     | Deshabilita el EditBox y suprime eventos de hover/click                  |
| `error`         | `boolean`  | `false`     | Activa variante error (borde destructive)                                |
| `maxLetters`    | `number`   | `0`         | Límite de caracteres; `0` = sin límite                                   |
| `iconLeading`   | `string`   | `nil`       | Path de textura del icono izquierdo (16px). Ajusta padding automáticamente |
| `iconTrailing`  | `string`   | `nil`       | Path de textura del icono derecho (16px). Ajusta padding automáticamente |
| `onChange`      | `function` | `nil`       | `fn(value)` — se dispara en `OnTextChanged`                              |
| `onEnterPressed`| `function` | `nil`       | `fn(value)` — se dispara en `OnEnterPressed` del EditBox                 |
| `width`         | `number`   | `nil`       | Ancho fijo en px. Si es nil, ocupa 100% del parent                       |

## API pública

| Método                   | Descripción                                                                 |
|--------------------------|-----------------------------------------------------------------------------|
| `SetValue(value)`        | Establece el texto del EditBox. Oculta/muestra placeholder según corresponda |
| `GetValue()`             | Retorna el texto actual del EditBox                                          |
| `SetEnabled(bool)`       | Habilita/deshabilita el campo. Aplica estilos de disabled                    |
| `SetError(bool)`         | Activa/desactiva variante error y actualiza color del borde                  |
| `SetPlaceholder(text)`   | Actualiza el texto del placeholder                                           |
| `GetFrame()`             | Retorna el frame raíz del componente                                         |

## Notas de implementación

- **EditBox nativo**: WoW provee `EditBox` con cursor y selección propios. No sobreescribir ni reimplementar la lógica de cursor/selección — solo configurar vía la API nativa.
- **MaxLetters**: usar `EditBox:SetMaxLetters(n)`. Con `n=0` no hay límite.
- **AutoFocus**: siempre llamar `EditBox:SetAutoFocus(false)` para evitar que tome foco automáticamente al mostrarse.
- **Placeholder**: mostrar `placeholder FontString` cuando `EditBox:GetText() == ""` y el EditBox no tiene foco. Ocultar en `OnEditFocusGained`. Mostrar en `OnEditFocusLost` si el texto queda vacío.
- **Insets del EditBox**: usar `EditBox:SetTextInsets(left, right, top, bottom)` para que el cursor y texto no toquen los bordes. Los valores de `left` y `right` son el `paddingH` del tamaño elegido (más el delta de icono si aplica).
- **Ring frame**: es un `Frame` separado, hermano del root (mismo parent), con `SetFrameLevel` un nivel mayor. Se posiciona con `SetPoint("TOPLEFT", root, "TOPLEFT", -2, 2)` y `SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 2, -2)`. Pintar solo el borde con una textura de 2px usando `SetBackdrop` o cuatro texturas de borde manual.
- **Borde 1px**: dibujar el borde como cuatro texturas de 1px (top, bottom, left, right) o via `SetBackdrop` con `edgeSize=1`. Con `SetBackdrop` usar `{bgFile="", edgeFile="...", edgeSize=1, insets={...}}`.
- **Disabled**: llamar `EditBox:EnableMouse(false)` y `EditBox:SetEnabled(false)`. El frame raíz también debe tener `EnableMouse(false)` para suprimir hover.
- **OnTextChanged**: el script recibe `(self, userInput)`. Solo disparar `onChange` si `userInput == true` para evitar loops al llamar `SetText` programáticamente.
- **Hover alpha**: aplicar `OnEnter`/`OnLeave` solo si `not self.disabled`. La textura de bg es la única que cambia de alpha — no el frame completo, para no afectar al texto.
