# Component: Input

> Referencia shadcn: `input` — WoW frame base: `EditBox`

## Propósito

Campo de texto editable de una sola línea, con soporte de placeholder, estados de error, iconos leading/trailing y focus ring.

## Jerarquía de frames WoW

```
Frame (root)                        — BACKGROUND layer
├── Texture (bg)                    — BACKGROUND layer, input/30 fill
├── Texture (borderT/B/L/R)         — BORDER layer, 1px cada una (SetPixelHeight/Width), t.border
├── Texture (iconLeading)           — ARTWORK layer, 16×16px, visible si config.iconLeading
├── Texture (iconTrailing)          — ARTWORK layer, 16×16px, visible si config.iconTrailing
├── EditBox                         — OVERLAY layer, centrado verticalmente con insets
└── FontString (placeholder)        — OVERLAY layer, visible cuando EditBox vacío y sin foco
```

Sin frame `ring` separado — el focus se implementa como cambio de color en los 4 bordes existentes (ver estados).

> **Corrección post-testing en WoW:** El ring-1 de Lyra se implementa como cambio de color en los 4 bordes existentes (`t.ring`) en lugar de un frame adicional. `OnEditFocusGained` cambia los 4 bordes a color `t.ring`; `OnEditFocusLost` los restaura al color base del border. `SetTextInsets(left, right, 0, 0)` se usa para controlar la posición exacta del texto dentro del EditBox, reemplazando el padding via `SetPoint` que resultaba en spacing incorrecto por el margen interno del EditBox en WoW.

## CSS de referencia (Lyra)

```css
.cn-input {
  @apply dark:bg-input/30 border-input focus-visible:border-ring focus-visible:ring-ring/50
         aria-invalid:border-destructive dark:aria-invalid:border-destructive/50
         disabled:bg-input/50 dark:disabled:bg-input/80
         h-8 rounded-none border bg-transparent px-2.5 py-1 text-xs
         transition-colors focus-visible:ring-1 aria-invalid:ring-1;
}
```

## Dimensiones

### Tamaño del componente

Lyra define un único tamaño para `input` (`h-8`). No hay variantes sm/lg en el CSS real.

| Propiedad        | Valor  | Fuente Tailwind |
|------------------|--------|-----------------|
| Height           | 32px   | `h-8`           |
| Padding H        | 10px   | `px-2.5`        |
| Padding V        | 4px    | `py-1`          |
| Font size        | 12px   | `text-xs`       |
| Border radius    | 0      | `rounded-none`  |
| Border           | 1px    | `border`        |

Width: 100% del parent por defecto (puede fijarse con `config.width`).

### Ajuste de padding con iconos

| Condición         | Padding H lado afectado |
|-------------------|------------------------|
| Sin icono         | 10px base              |
| Con iconLeading   | left += 20px           |
| Con iconTrailing  | right += 20px          |

Posición del icono:
- Leading: x = `spacing.sm` (8px) desde el borde izquierdo, centrado verticalmente.
- Trailing: x = `spacing.sm` (8px) desde el borde derecho, centrado verticalmente.
- Tamaño del icono: `iconSizeSm` = 16×16px.

## Variantes visuales

| Variante  | Fondo                        | Border color    | Notas                                        |
|-----------|------------------------------|-----------------|----------------------------------------------|
| `default` | input/30 = {r=1,g=1,b=1,a=0.045} | `t.border` = {r=1,g=1,b=1,a=0.15} | Estado base          |
| `error`   | input/30 = {r=1,g=1,b=1,a=0.045} | `t.destructive` = {r=0.973,g=0.443,b=0.443} | Borde destructive |

## Estados

| Estado     | Fondo                         | Border color    | Texto               | Placeholder          |
|------------|-------------------------------|-----------------|---------------------|----------------------|
| Default    | {r=1,g=1,b=1,a=0.045}         | {r=1,g=1,b=1,a=0.15} | `t.foreground` | `t.mutedForeground`  |
| Focused    | {r=1,g=1,b=1,a=0.045}         | `t.ring`        | `t.foreground`      | Oculto               |
| Disabled   | {r=1,g=1,b=1,a=0.12}          | {r=1,g=1,b=1,a=0.15} | `t.mutedForeground` | `t.mutedForeground` |
| Error      | {r=1,g=1,b=1,a=0.045}         | `t.destructive` | `t.foreground`      | `t.mutedForeground`  |

Notas sobre estados:
- `disabled:bg-input/50` en light mode; `dark:disabled:bg-input/80` → {r=1,g=1,b=1,a=0.12} en dark mode.
- Focus ring: el `focus-visible:ring-1` de Lyra **sí se implementa** en WoW, pero como cambio de color en los 4 bordes existentes (no como frame adicional). `OnEditFocusGained` → bordes a `t.ring`; `OnEditFocusLost` → bordes a color base.
- El borde del input es **siempre visible** (no transparente como en Button). Usar `Craft.Theme.SetPixelHeight/Width` para el borde de 1px.
- Hover: no definido en el CSS de Lyra. Omitir efecto hover en esta versión.

## Mapa de tokens

| Elemento              | Token / Valor dark mode                    |
|-----------------------|---------------------------------------------|
| Fondo del input       | input/30 = {r=1,g=1,b=1,a=0.045}           |
| Borde default         | `t.border` = {r=1,g=1,b=1,a=0.15}          |
| Borde focused         | `t.ring`                                    |
| Borde error           | `t.destructive` = {r=0.973,g=0.443,b=0.443}|
| Texto ingresado       | `t.foreground` = {r=0.980,g=0.980,b=0.980} |
| Placeholder           | `t.mutedForeground` = {r=0.631,g=0.631,b=0.667} |
| Fondo disabled (dark) | input/80 = {r=1,g=1,b=1,a=0.12}            |
| Texto disabled        | `t.mutedForeground`                         |
| Icono leading/trailing| `t.mutedForeground` (tint)                  |

## Config — `Create(parent, config)`

| Parámetro       | Tipo       | Default     | Descripción                                                              |
|-----------------|------------|-------------|--------------------------------------------------------------------------|
| `placeholder`   | `string`   | `""`        | Texto gris visible cuando el campo está vacío y sin foco                 |
| `value`         | `string`   | `""`        | Valor inicial del EditBox                                                |
| `size`          | `string`   | `"default"` | Solo `"default"` (Lyra no define variantes sm/lg para input)             |
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
- **Insets del EditBox**: usar `EditBox:SetTextInsets(left, right, top, bottom)` para que el cursor y texto no toquen los bordes. Los valores de `left` y `right` son 10px (paddingH del tamaño único), más el delta de icono si aplica.
- **Borde 1px (pixel-perfect)**: el borde de 1px es siempre visible en el input. Usar `Craft.Theme.SetPixelHeight` y `Craft.Theme.SetPixelWidth` para las texturas de borde, **no** `SetHeight(1)` / `SetWidth(1)`. Esto garantiza exactamente 1px físico independientemente del UI scale.
- **Focus como cambio de color en bordes**: el `focus-visible:ring-1` de Lyra se implementa cambiando el color de los 4 bordes existentes a `t.ring` en `OnEditFocusGained`, y restaurándolos al color base en `OnEditFocusLost`. No se crea un frame `_ring` adicional.
- **Sin variantes de tamaño**: Lyra define un único tamaño (`h-8` = 32px). Eliminar la lógica de `sm`/`lg` si existe de implementaciones anteriores.
- **Disabled**: llamar `EditBox:EnableMouse(false)` y `EditBox:SetEnabled(false)`. El frame raíz también debe tener `EnableMouse(false)` para suprimir hover. Fondo disabled dark: {r=1,g=1,b=1,a=0.12} (`input/80`).
- **OnTextChanged**: el script recibe `(self, userInput)`. Solo disparar `onChange` si `userInput == true` para evitar loops al llamar `SetText` programáticamente.
- **Hover alpha**: aplicar `OnEnter`/`OnLeave` solo si `not self.disabled`. La textura de bg es la única que cambia de alpha — no el frame completo, para no afectar al texto.
