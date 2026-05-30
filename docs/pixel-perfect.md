# Pixel Perfect y UI Scale — Craft

> Referencia técnica para el sistema de coordenadas de WoW, conversión de píxeles a UI units, y cómo Craft maneja la escala. Adapatado de `CraftUI/docs/wow-units.md`.

---

## 1. Lo fundamental: WoW no usa píxeles

`frame:SetSize(32, 32)` no crea un frame de 32 píxeles. Crea un frame de **32 UI units**.

Un **UI unit** es la unidad interna del sistema de coordenadas de WoW. Cuántos píxeles físicos equivale 1 UI unit depende del **UI scale** y la resolución del monitor.

---

## 2. La fórmula central

```lua
píxeles_de_render_por_UI_unit = UIParent:GetEffectiveScale()
```

| Resolución | WoW default scale | 1 UI unit = | Resultado visual |
|---|---|---|---|
| 1080p | ~1.41 | 1.41 px | Bordes levemente borrosos |
| 1080p (pixel-perfect) | 1.0 | 1 px exacto | Nítido |
| 1440p | ~1.88 | 1.88 px | Componentes grandes |
| 4K | ~2.81 | 2.81 px | Componentes muy grandes |
| 720p | ~0.94 | 0.94 px | Bordes borrosos por sub-pixel |

---

## 3. Conversiones

```lua
-- UI units → píxeles de render
render_px = ui_units × UIParent:GetEffectiveScale()

-- píxeles de render → UI units (p.ej. posición del cursor)
ui_units = render_px / UIParent:GetEffectiveScale()
```

### Posición del cursor (SIEMPRE convertir)

`GetCursorPosition()` devuelve píxeles de render. Para operar con frames:

```lua
local cx, cy = GetCursorPosition()
local eff = UIParent:GetEffectiveScale()
local x_ui = cx / eff   -- posición en UI units relativa a UIParent
local y_ui = cy / eff
```

Si el frame tiene `SetScale()` propio, usar `frame:GetEffectiveScale()` en lugar de `UIParent`:

```lua
-- Para Slider, Scroll, ColorPicker con escala propia:
local eff = self._trackFrame:GetEffectiveScale()
local cx = GetCursorPosition() / eff
```

---

## 4. El problema del borde de 1px

Cuando `GetEffectiveScale() > 1` (caso más común), un borde de 1 UI unit renderiza como múltiples píxeles (borroso). La solución es expresar el borde en píxeles físicos, no en UI units:

```lua
-- MAL: borde en UI units (puede ser 1.41px o 2.81px)
border:SetHeight(1)

-- BIEN: borde en píxeles físicos convertidos a UI units
border:SetHeight(1 / UIParent:GetEffectiveScale())
-- Pero si scale < 1 (720p), 1/scale > 1 y puede quedar sub-visible...
```

El clamp mínimo evita bordes invisibles:

```lua
local function pixel(n, frame)
    local scale = (frame or UIParent):GetEffectiveScale()
    return math.max(n / scale, 0.5)  -- 0.5 UI units es el mínimo visible en WoW
end
```

---

## 5. La API nativa: PixelUtil (solo Retail Dragonflight+)

WoW Retail incluye `PixelUtil`, que hace el snap automático a la grilla de píxeles:

```lua
PixelUtil.SetHeight(frame, 1)          -- exactamente 1 px físico
PixelUtil.SetWidth(frame, 1)           -- ídem
PixelUtil.SetSize(frame, 200, 1)       -- 200 × 1 px
PixelUtil.SetPoint(frame, "TOPLEFT", parent, "TOPLEFT", 4, -4)  -- offsets snapped
```

**Disponibilidad:**
- ✅ WoW Retail (Dragonflight 10.x+, actual 11.x)
- ❌ WoW Classic (todas las versiones) — usar fallback manual

---

## 6. La estrategia de Craft

Craft distingue tres categorías de valores de dimensión:

### Categoría A — Spacing y sizing de componentes

Los valores del design system (`h-8=32`, `gap-1.5=6`, `px-2.5=10`) se usan **directamente como UI units**. No se convierten.

```lua
-- CORRECTO para Craft — spacing en UI units
button.frame:SetHeight(32)    -- h-8 del design
button.frame:SetWidth(label_width + 20)
```

**Justificación**: visualmente los componentes se verán ligeramente más grandes o más pequeños según el scale del usuario, pero la proporción relativa entre componentes se mantiene. Es el mismo comportamiento de cualquier aplicación web en monitores con distintos DPIs.

### Categoría B — Elementos de exactamente 1px

Bordes, separators, underlines de link, scrollbar tracks — deben ser exactamente 1 píxel físico. **Siempre usar `Craft.Theme.SetPixelHeight/Width`.**

```lua
-- CORRECTO para borders de 1px
Craft.Theme.SetPixelHeight(border_frame, 1)
Craft.Theme.SetPixelWidth(border_frame, 1)

-- O directamente:
Craft.Theme.px(1)  -- retorna la conversión correcta
```

### Categoría C — Posición del cursor

Para componentes con drag (Slider, Scroll) **siempre dividir por la escala del frame**:

```lua
local cx = GetCursorPosition() / self._trackFrame:GetEffectiveScale()
```

---

## 7. API de Craft.Theme para escala

Estos helpers van en `Craft/theme/Theme.lua`:

```lua
-- Convertir n píxeles físicos a UI units (con clamp mínimo de 0.5)
function Craft.Theme.px(n, frame)
    local scale = (frame or UIParent):GetEffectiveScale()
    return math.max(n / scale, 0.5)
end

-- Aplicar altura en píxeles físicos
function Craft.Theme.SetPixelHeight(frame, n)
    if PixelUtil then
        PixelUtil.SetHeight(frame, n, 1)
    else
        frame:SetHeight(Craft.Theme.px(n, frame))
    end
end

-- Aplicar ancho en píxeles físicos
function Craft.Theme.SetPixelWidth(frame, n)
    if PixelUtil then
        PixelUtil.SetWidth(frame, n, 1)
    else
        frame:SetWidth(Craft.Theme.px(n, frame))
    end
end

-- Aplicar tamaño completo en píxeles físicos
function Craft.Theme.SetPixelSize(frame, w, h)
    if PixelUtil then
        PixelUtil.SetSize(frame, w, h, 1, 1)
    else
        frame:SetWidth(Craft.Theme.px(w, frame))
        frame:SetHeight(Craft.Theme.px(h, frame))
    end
end

-- Detectar si el usuario está en pixel-perfect
function Craft.Theme.isPixelPerfect()
    return math.abs(UIParent:GetEffectiveScale() - 1.0) < 0.01
end
```

---

## 8. Popups y dropdowns — corrección de escala

Cuando un popup (Select dropdown, Tooltip, ContextMenu) se posiciona relativo a `UIParent` pero su frame padre tiene escala distinta, hay que corregir:

```lua
-- Select dropdown: asegurar que aparece sin distorsión de escala
local triggerEff  = self.frame:GetEffectiveScale()
local uiParentEff = UIParent:GetEffectiveScale()
self._dropdown:SetScale(triggerEff / uiParentEff)
```

Esto es necesario cuando:
- El addon usa `Craft_Browser` que puede correr a 0.75x scale
- El desarrollador aplica `SetScale()` a su frame padre

---

## 9. Qué componentes necesitan manejo de escala

| Componente | Qué necesita |
|---|---|
| **Separator** | Todo: `Craft.Theme.SetPixelHeight(frame, 1)` |
| **Panel** | Bordes perimetrales: `SetPixelHeight/Width(border, 1)` |
| **Dialog** | Bordes perimetrales + separador bajo title bar |
| **Input** | Borde de 1px + ring de 1px al hacer clic (OnEditFocusGained) |
| **Button** (link) | Underline: `SetPixelHeight(_underline, 1)` |
| **Tabs** | Indicador activo: `SetPixelHeight(_indicator, 2)` — 2px |
| **Slider** | Drag: `GetCursorPosition() / frame:GetEffectiveScale()` |
| **Scroll** | Drag scrollbar: mismo patrón |
| **Select** | Dropdown scale correction |
| **Tooltip** | Borders + posicionamiento cursor |

---

## 10. Flex y offsets fraccionarios

`Craft.Flex` calcula posiciones con aritmética de punto flotante. Los offsets fraccionarios (e.g., `SetPoint("TOPLEFT", f, "TOPLEFT", 5.333, 0)`) producen sub-pixel blending idéntico al de los tamaños fraccionarios.

**Regla**: redondear offsets de Flex con `math.floor()` antes de aplicar `SetPoint`:

```lua
-- En Flex.lua — al aplicar posiciones calculadas
local x = math.floor(calculated_x)
local y = math.floor(calculated_y)
frame:SetPoint("TOPLEFT", container, "TOPLEFT", x, -y)
```

---

## 11. Registro de cambios

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| v0.1 | 30/05/2026 | Alberto Gomez | Versión inicial. Adaptado de CraftUI/docs/wow-units.md con estrategia específica de Craft. |
