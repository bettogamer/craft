# Component: Tooltip

> Referencia shadcn: `tooltip` — WoW frame base: `Frame` custom (NO usar GameTooltip de WoW — tiene estilos propios que contradicen Lyra)

## Propósito

Etiqueta informativa flotante que aparece al hacer hover sobre cualquier frame ancla, con delay configurable y posicionamiento automático relativo a la pantalla.

## Jerarquía de frames WoW

```
Craft.Tooltip._frame        (Frame — TOOLTIP strata, singleton compartido por toda la UI)
├── _frame._bg              (Texture — BACKGROUND layer) fondo sólido t.popover
├── _frame._border          (Texture — BORDER layer)     borde 1px, t.border
├── _frame._icon            (Texture — ARTWORK layer)    ícono Lucide 16×16, oculto si no hay icon
└── _frame._text            (FontString — OVERLAY layer) texto del tooltip, t.popoverForeground
```

El tooltip es un **singleton**: existe un único frame `Craft.Tooltip._frame` reutilizado por todos los anchors. No se crea un frame nuevo por cada uso — solo se reposiciona y actualiza el contenido en cada Show(). El borde se implementa con `SetBackdrop` (edgeSize=1, bgFile vacío, edgeFile) o como cuatro texturas de 1px (top, right, bottom, left), una en cada lado del frame.

## Dimensiones / Comportamiento

| Propiedad               | Valor                                                      |
|-------------------------|------------------------------------------------------------|
| Padding horizontal      | 8px (spacingSm) en cada lado                               |
| Padding vertical        | 6px en cada lado                                           |
| Max width               | 240px — el texto wraps con `:SetWordWrap(true)` si supera  |
| Min width               | automático — igual al ancho del texto corto                |
| Offset desde el anchor  | 4px de separación entre el anchor y el tooltip             |
| Ícono                   | 16×16px (iconSizeSm), gap ícono→texto: 8px (spacingSm)     |
| Delay de aparición      | 300ms por defecto (configurable por anchor)                |
| Strata                  | TOOLTIP — aparece sobre todos los frames excepto UIParent  |
| Font size               | `t.fontSize` (12px)                                        |

### Posicionamiento automático

1. **Por defecto**: el tooltip aparece **arriba** del anchor — `SetPoint("BOTTOM", anchor, "TOP", 0, 4)`.
2. **Sin espacio arriba**: si `anchor:GetTop() + tooltipHeight > UIParent:GetHeight()`, mostrar **abajo** — `SetPoint("TOP", anchor, "BOTTOM", 0, -4)`.
3. **Sin espacio arriba ni abajo**: preferir abajo igualmente.
4. **Clampeo horizontal**: si el borde derecho del tooltip supera `UIParent:GetWidth()`, desplazar a la izquierda. Si el borde izquierdo cae por debajo de 0, desplazar a la derecha. Usar `_frame:GetRight()` / `_frame:GetLeft()` tras el primer SetPoint para detectar desbordamiento y corregir con un segundo SetPoint.

El cálculo de posición ocurre **cada vez** que el tooltip se muestra — no se cachea, dado que el anchor puede moverse.

## API pública

| Función                            | Firma                              | Descripción                                                                                     |
|------------------------------------|------------------------------------|-------------------------------------------------------------------------------------------------|
| `Craft.Tooltip.Attach(frame, cfg)` | `(Frame, table) → void`            | Adjunta un tooltip a `frame` via OnEnter/OnLeave. Sobreescribe cualquier attachment previo.     |
| `Craft.Tooltip.Detach(frame)`      | `(Frame) → void`                   | Elimina los scripts OnEnter/OnLeave de tooltip del frame. No afecta otros scripts del frame.    |
| `Craft.Tooltip.Show(anchor, cfg)`  | `(Frame, table) → void`            | Muestra el tooltip manualmente sobre `anchor` con la config dada. Ignora el delay.             |
| `Craft.Tooltip.Hide()`             | `() → void`                        | Oculta el tooltip activo y cancela cualquier timer de delay pendiente.                          |

### Config (para `Attach` y `Show`)

| Clave      | Tipo     | Default  | Descripción                                                              |
|------------|----------|----------|--------------------------------------------------------------------------|
| `text`     | string   | —        | Texto visible del tooltip. Requerido.                                    |
| `icon`     | string   | `nil`    | Nombre Lucide (e.g. `"info"`, `"alert-triangle"`). Usa `Craft.Icons`.   |
| `delay`    | number   | `300`    | Milisegundos antes de que el tooltip aparezca tras OnEnter.              |
| `maxWidth` | number   | `240`    | Ancho máximo en px antes de hacer wrap del texto.                        |

## Notas de implementación

**Singleton pattern**: `Craft.Tooltip._frame` se crea una sola vez en `Craft.Tooltip._init()`, llamado al cargar el addon. Los consumidores nunca crean ni destruyen el frame — solo llaman a `Attach` / `Show` / `Hide`.

**Delay con C_Timer**: El delay se gestiona con `C_Timer.After(delay / 1000, fn)`. La función `fn` verifica que el anchor todavía esté bajo el cursor antes de mostrar (`anchor:IsMouseOver()`). La referencia al timer se guarda en `Craft.Tooltip._pendingTimer` para poder cancelarlo en `Hide()` o en OnLeave. Cancelar con `_pendingTimer:Cancel()` si el timer aún no disparó.

```lua
-- Cancelar timer pendiente al salir del anchor antes del delay
frame:SetScript("OnLeave", function()
  if Craft.Tooltip._pendingTimer then
    Craft.Tooltip._pendingTimer:Cancel()
    Craft.Tooltip._pendingTimer = nil
  end
  Craft.Tooltip.Hide()
end)
```

**Attach no sobreescribe otros scripts**: Usar `HookScript` en lugar de `SetScript` para OnEnter y OnLeave, de modo que otros scripts existentes en el frame no se pierdan. Si el frame ya tiene un attachment previo de Craft.Tooltip, desregistrar los hooks anteriores antes de agregar nuevos — guardar las funciones de hook en una tabla indexada por frame (`Craft.Tooltip._hooks[frame]`).

**Tamaño del frame tras actualizar texto**: Después de llamar `_text:SetText(config.text)`, calcular el ancho resultante con `_text:GetStringWidth()`. El ancho del frame = `min(config.maxWidth, textWidth) + paddingH * 2 + (icon ? iconSize + gap : 0)`. La altura = `_text:GetStringHeight() + paddingV * 2`. Llamar `_frame:SetSize(w, h)` antes del SetPoint para que el clamping de pantalla use las dimensiones correctas.

**Ícono opcional**: Si `config.icon` es nil, `_icon:Hide()` y el texto ancla desde `paddingH` del borde izquierdo. Si `config.icon` existe, `_icon:Show()`, posicionarlo con `SetPoint("LEFT", _frame, "LEFT", paddingH, 0)`, y el texto con `SetPoint("LEFT", _icon, "RIGHT", gap, 0)`.

**Borde 1px**: Usar `SetBackdrop` con `edgeFile = "Interface\\BUTTONS\\WHITE8X8"` y `edgeSize = 1`, o cuatro texturas de 1px. La textura de borde se colorea con `SetBackdropBorderColor(t.border.r, t.border.g, t.border.b, t.border.a)`. En dark mode, `t.border = {r=1, g=1, b=1, a=0.1}`.

**TOOLTIP strata**: garantiza visibilidad sobre casi todo. El único nivel superior en WoW es `UIParent` mismo. Los tooltips del juego (GameTooltip) también usan esta strata — no hay conflicto porque Craft.Tooltip se oculta antes de que GameTooltip aparezca en frames de items de inventario.

**Re-theme**: registrar `Craft.Theme.register` para actualizar los colores del `_frame` singleton cuando el tema cambia, igual que cualquier otro componente.
