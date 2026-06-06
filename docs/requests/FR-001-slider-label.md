# FR-001 — Slider: soporte para `label` en config

**Reportado por:** Sentry (consumer addon)
**Componente:** `Craft/components/Slider.lua`
**Tipo:** Feature Request
**Prioridad:** Alta — bloquea usabilidad básica de formularios de configuración
**Estado:** ✅ Implementado como Craft extension (ver resolución al final)

---

## Problema

`Craft.Slider:Create(parent, config)` no soporta un parámetro `label` para mostrar texto descriptivo sobre el slider. El parámetro se ignora silenciosamente — no hay error, no hay texto.

El spec actual (`docs/components/slider.md § Config`) lista solo: `min`, `max`, `value`, `step`, `disabled`, `showValue`, `showMinMax`, `onChange`, `width`, `height`. Sin `label`.

Resultado en producción: los sliders aparecen sin contexto visual, el usuario no sabe qué controla cada uno.

**Screenshot del problema:**

```
Bar                 [Enabled ☑]
  [____________________]        ← input, OK
  ──●──────────────────         ← ¿qué slider es este?
  ──────────●──────────         ← ¿y este?
  [Emphasize ☑] ──●──────      ← ¿threshold de qué?
```

---

## Caso de uso (Sentry)

En `Config/Sidebar.lua`, cada spell tiene una página de configuración con múltiples sliders:

```lua
Craft.Slider:Create(c, {
    label    = "Duration override (0 = auto)",   -- IGNORADO
    min = 0, max = 30, step = 0.5,
    value    = 0,
    onChange = function(v) ... end,
})

Craft.Slider:Create(c, {
    label    = "Priority",                        -- IGNORADO
    min = 1, max = 10, step = 1,
    value    = 5,
    onChange = function(v) ... end,
})
```

Sin label, tenemos que agregar un `Craft.Label` manual antes de cada slider, lo que duplica el código y desincroniza el estilo si el tema cambia.

---

## Solución propuesta

### API

Agregar `label` como parámetro opcional en `Create`:

```lua
Craft.Slider:Create(parent, {
    label    = "Duration override (0 = auto)",   -- string, opcional
    min = 0, max = 30, step = 0.5,
    value    = 0,
    onChange = function(v) ... end,
})
```

### Comportamiento

- Si `label` está presente: renderizar un `FontString` encima del track con el texto dado.
- Si `label` es nil o `""`: comportamiento actual (sin cambio, backward-compatible).

### Layout sugerido (column)

```
┌─────────────────────────────────────────┐  ← root frame (altura += 20px)
│ Duration override (0 = auto)            │  ← FontString, t.foreground, fontSizeSm, TOP-LEFT
│ ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │  ← track (existente, desplazado 20px hacia abajo)
└─────────────────────────────────────────┘
```

### Altura del root frame con `label`

| Configuración                              | Height   |
|--------------------------------------------|----------|
| Sin label, sin showValue                   | 32px (actual) |
| Sin label, con showValue                   | 48px (actual) |
| **Con label, sin showValue**               | **52px** |
| **Con label, con showValue**               | **68px** |

### Tokens

| Elemento    | Token           | Notas                            |
|-------------|-----------------|----------------------------------|
| Label text  | `t.foreground`  | mismo que `valueLabel`           |
| Label font  | `t.fontSizeSm`  | 11px, consistente con otros labels |

### Implementación (referencia)

```lua
-- En Create(), después de crear el root frame:
if config.label and config.label ~= "" then
    self._label = self.frame:CreateFontString(nil, "OVERLAY")
    self._label:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    self._label:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
    self._label:SetHeight(16)
    self._label:SetJustifyH("LEFT")
    self._label:SetText(config.label)
    -- desplazar el track 20px hacia abajo
    -- (ajustar SetPoint del _slider y _fillTrack)
end

-- En _applyTheme():
if self._label then
    self._label:SetFont(t.font, t.fontSizeSm)
    self._label:SetTextColor(t.foreground.r, t.foreground.g, t.foreground.b)
end
```

### API pública adicional

| Método           | Descripción                       |
|------------------|-----------------------------------|
| `SetLabel(text)` | Actualiza el texto del label en runtime |

---

## Workaround actual (Sentry)

Por ahora, Sentry agrega un `Craft.Label` manual antes de cada slider:

```lua
local lbl = Craft.Label:Create(c, { text = "Duration override (0 = auto)" })
lbl:GetFrame():SetPoint("TOPLEFT", c, "TOPLEFT", PAD, y)
lbl:GetFrame():SetHeight(16)
lbl:GetFrame():SetWidth(300)
y = y - 20

local sl = Craft.Slider:Create(c, { min=0, max=30, step=0.5, value=0, onChange=... })
sl.frame:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, y)
sl.frame:SetWidth(300)
y = y - 36
```

Esto funciona pero genera ruido en el consumer y no aprovecha el sistema de theming de Craft para el label.

---

## Impacto

- **Sin breaking change**: `label` es opcional, el comportamiento existente no cambia.
- **Afecta altura del frame**: consumidores que usen altura fija (`SetHeight` manual) deben revalidar, pero la mayoría usa `SetWidth` solamente.
- **Alineación con otros componentes**: ~~`Craft.Input` ya soporta `label`~~ — incorrecto, `Craft.Input` no tiene parámetro `label`.

---

## Resolución — Implementado como Craft extension

### Contexto

El código oficial de shadcn confirma que `Label` y `Slider` son componentes independientes — el Slider no tiene prop `label`. Sin embargo, en WoW el consumer necesita calcular manualmente la altura del frame para posicionar sliders apilados, lo que genera errores cuando se combina con `showValue`, `showMinMax` o `config.height`. Se decidió implementar como **extensión Craft** para encapsular ese cálculo.

---

## Guía de uso para Sentry

### Config completa

```lua
local sl = Craft.Slider:Create(parent, {
    -- Rango y valor
    min      = 0,          -- default: 0
    max      = 100,        -- default: 100
    value    = 40,         -- default: min
    step     = 1,          -- default: 1

    -- Labels
    label     = "Volume",  -- [Craft extension] texto sobre el track, t.foreground
    showValue = true,      -- valor actual a la derecha del label (mismo row), t.mutedForeground
    showMinMax = true,     -- "0" y "100" debajo del track, t.mutedForeground

    -- Estado
    disabled = false,      -- deshabilita interacción, aplica colores muted

    -- Callback
    onChange = function(v) print("valor:", v) end,

    -- Dimensiones (opcionales)
    width  = 280,          -- si nil: 100% del parent
    height = nil,          -- si nil: calculado automáticamente (ver tabla abajo)
})
```

### Alturas de frame automáticas

Usar `sl:GetFrame():GetHeight()` para calcular posiciones — no hardcodear.

| Configuración                           | Height |
|-----------------------------------------|--------|
| Sin label, sin showMinMax               | 16px   |
| Sin label, con `showMinMax=true`        | 28px   |
| Con `label`/`showValue`, sin showMinMax | 30px   |
| Con `label`/`showValue` + `showMinMax`  | 42px   |

### Layout visual

```
"Volume"                                "40"   ← label + showValue (mismo row, justify-between)
━━━━━━━━━━━━━━━━━━━━━━━[■]━━━━━━━━━━━━━━━━   ← track full-width + thumb
"0"                                    "100"   ← showMinMax
```

- `label` y `showValue` comparten el row superior (justify-between) — igual que el demo de shadcn.
- El track arranca en `x=0` del root frame — **sin padding horizontal implícito**. Se puede colocar flush con el padding del form y se alineará con `Input`, `Label`, etc.

### Posicionamiento apilado (patrón recomendado)

```lua
local PAD = 16
local GAP = 8
local y   = -PAD

local sliders = {
    Craft.Slider:Create(parent, { label="Duration override", min=0, max=30, step=0.5, value=0, showValue=true, onChange=... }),
    Craft.Slider:Create(parent, { label="Priority",          min=1, max=10, step=1,   value=5, showValue=true, onChange=... }),
    Craft.Slider:Create(parent, { label="Threshold",         min=0, max=100,           value=50, showMinMax=true, onChange=... }),
}

for _, sl in ipairs(sliders) do
    sl:GetFrame():SetPoint("TOPLEFT",  parent, "TOPLEFT",  PAD, y)
    sl:GetFrame():SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, y)
    y = y - sl:GetFrame():GetHeight() - GAP
end
```

`GetHeight()` devuelve la altura correcta inmediatamente después de `Create` — no hace falta `OnUpdate` ni `OnShow`.

### API pública

| Método              | Descripción                                                              |
|---------------------|--------------------------------------------------------------------------|
| `SetValue(n)`       | Establece el valor. Actualiza fill, thumb y valueLabel.                  |
| `GetValue()`        | Retorna el valor actual.                                                 |
| `SetEnabled(bool)`  | Habilita/deshabilita. Aplica colores muted a track, fill y thumb.        |
| `SetRange(min, max)`| Actualiza el rango y reposiciona el thumb.                               |
| `SetLabel(text)`    | Actualiza el texto del label en runtime. Solo si `config.label` fue provisto. |
| `GetFrame()`        | Retorna el root frame para posicionamiento y `SetWidth`.                 |

### ✅ Resuelto: LibStub namespace collision

Craft y Sentry comparten la clave `"Craft-1.0"` en LibStub. Antes, el último addon en cargar (orden alfabético: **Sentry** carga después de Craft) sobreescribía `Craft.Slider` con su versión anterior, que **no soportaba `label`** → labels invisibles con Sentry activo.

**Fix aplicado:** versioned component registration. Cada copia de Craft registra sus componentes vía `Craft.register(name, impl, build)`, que sólo (re)asigna si el build entrante es estrictamente mayor. Una copia embebida más antigua que cargue después ya no puede pisar el `Craft.Slider` nuevo. Ya **no** es necesario deshabilitar Sentry. Ver `CLAUDE.md § Bugs encontrados en producción WoW #1`.
