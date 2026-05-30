# Contrato de Componente — Craft

> **Fuente de verdad del patrón de implementación** para todos los componentes de Craft.
> Todo componente en `Craft/components/` DEBE seguir este contrato sin excepción.
> Referencias: `AGENTS.md §5`, `docs/components/theme.md §Flujo de un componente`.

---

## 1. Estructura obligatoria

```lua
-- Craft/components/MyComponent.lua

local MyComponent = {}
MyComponent.__index = MyComponent

-- ─── Create ────────────────────────────────────────────────────────────────
function MyComponent:Create(parent, config)
    local self = setmetatable({}, MyComponent)

    config = config or {}

    -- 1. Guardar config
    self._cfg = { ... }

    -- 2. Crear frames WoW
    self.frame = CreateFrame("Frame", nil, parent)
    -- ... más frames hijos

    -- 3. Registrar listener de tema — SIEMPRE al final de la construcción
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)

    -- 4. Aplicar tema inicial
    self:_applyTheme(Craft.Theme.get())

    return self
end

-- ─── _applyTheme ───────────────────────────────────────────────────────────
function MyComponent:_applyTheme(t)
    -- REGLAS ABSOLUTAS:
    -- ✅ Usar SOLO t.* — t.primary, t.background, t.border, etc.
    -- ✅ Para 1px: Craft.Theme.SetPixelHeight/Width(frame, 1) — nunca SetHeight(1)
    -- ❌ NUNCA llamar Craft.Theme.get() aquí → causa re-entrancia
    -- ❌ NUNCA hardcodear valores RGBA como {r=0.024, ...}
    -- ❌ NUNCA crear focus rings → WoW es mouse-only
end

-- ─── Destroy ───────────────────────────────────────────────────────────────
function MyComponent:Destroy()
    -- CRÍTICO: sin unregister → memory leak permanente
    Craft.Theme.unregister(self._themeHandle)
    self._themeHandle = nil

    self.frame:Hide()
    self.frame:SetParent(nil)
    self.frame = nil
end

-- ─── API pública ───────────────────────────────────────────────────────────
function MyComponent:GetFrame()
    return self.frame
end
-- ... otros métodos públicos según el spec del componente
```

---

## 2. Reglas por sección

### Create()

| Regla | Razón |
|-------|-------|
| `setmetatable({}, MyComponent)` como primer paso | Garantiza que `self` tiene acceso a todos los métodos |
| Frames creados **antes** de `register()` | Si `register()` se llama primero y hay un `use()` inmediato, `_applyTheme` puede ejecutarse antes de que los frames existan |
| `register()` **antes** de `_applyTheme()` inicial | El handle debe existir antes de aplicar el primer tema |
| `_applyTheme(Craft.Theme.get())` al final | El componente debe quedar visualmente correcto al retornar de Create |
| Retornar `self` siempre | El dev necesita la referencia para llamar métodos y `Destroy()` |

### _applyTheme(t)

| Regla | Razón |
|-------|-------|
| Solo leer `t.*`, nunca llamar `Craft.Theme.get()` | Re-entrancia: `get()` puede reconstruir `_resolved`, causando comportamiento indefinido |
| Todos los colores de `t.*` | `t` es read-only pero sus campos siempre son válidos en el momento de la llamada |
| `Craft.Theme.SetPixelHeight/Width(frame, 1)` para 1px | `SetHeight(1)` en UI units ≠ 1 píxel físico a escalas distintas de 1.0 (ADR-0011) |
| No crear focus rings | WoW addon UI es mouse-only; `focus-visible:ring` de shadcn no aplica |
| Los tokens `t.sidebar*` solo en `Craft.Sidebar` | Los demás componentes usan los tokens sin prefijo |

### Destroy()

| Regla | Razón |
|-------|-------|
| `unregister(self._themeHandle)` **siempre** | Sin unregister, el listener queda activo indefinidamente; en el próximo `Craft.Theme.use()` intentará acceder a frames destruidos → error o comportamiento indefinido |
| `self._themeHandle = nil` después de unregister | Permite que el GC libere la referencia |
| `self.frame:SetParent(nil)` | Desacopla el frame de su padre; permite que el GC lo libere |
| Nulificar `self.frame = nil` | Marca el componente como destruido; errores claros si se usa después |

---

## 3. Ejemplo completo — componente mínimo

```lua
-- Craft/components/Badge.lua
-- Componente mínimo que sigue el contrato completo.

local Badge = {}
Badge.__index = Badge

function Badge:Create(parent, config)
    local self = setmetatable({}, Badge)

    config      = config or {}
    self._cfg   = { text = config.text or "" }

    -- Frames
    self.frame  = CreateFrame("Frame", nil, parent)
    self._bg    = self.frame:CreateTexture(nil, "BACKGROUND")
    self._label = self.frame:CreateFontString(nil, "OVERLAY")

    self._bg:SetAllPoints(self.frame)

    -- Tema
    self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
    self:_applyTheme(Craft.Theme.get())

    -- Config inicial
    self._label:SetText(self._cfg.text)

    return self
end

function Badge:_applyTheme(t)
    self._bg:SetColorTexture(t.secondary.r, t.secondary.g, t.secondary.b, 1)
    self._label:SetFont(t.font, t.fontSizeSm)
    self._label:SetTextColor(t.secondaryForeground.r, t.secondaryForeground.g, t.secondaryForeground.b)
end

function Badge:Destroy()
    Craft.Theme.unregister(self._themeHandle)
    self._themeHandle = nil
    self.frame:Hide()
    self.frame:SetParent(nil)
    self.frame = nil
end

function Badge:SetText(text)
    self._cfg.text = text
    self._label:SetText(text)
end

function Badge:GetFrame()
    return self.frame
end
```

---

## 4. Checklist de merge para un componente nuevo

Antes de mergear un PR con un componente nuevo:

- [ ] `Create()` retorna `self`
- [ ] `self._themeHandle` asignado en `Create()`
- [ ] `_applyTheme(t)` no llama `Craft.Theme.get()`
- [ ] `_applyTheme(t)` no tiene valores RGBA hardcodeados
- [ ] `Destroy()` llama `Craft.Theme.unregister(self._themeHandle)`
- [ ] `Destroy()` nulifica `self.frame`
- [ ] Bordes de 1px usan `Craft.Theme.SetPixelHeight/Width(frame, 1)`
- [ ] No hay focus rings implementados (WoW mouse-only)
- [ ] `Craft.Icons.Apply(tex, name)` para íconos — no rutas TGA directas
- [ ] `Craft.Theme.getFont()` para fuentes — no rutas TTF directas
- [ ] `radius = 0` — sin rounded corners
- [ ] `GetFrame()` retorna el frame raíz
- [ ] Spec en `docs/components/<nombre>.md` creado o actualizado
- [ ] Entrada añadida en `Craft/Craft.toc`
- [ ] `luacheck Craft/ --config .luacheckrc` pasa sin warnings nuevos

---

## 5. Anti-patrones frecuentes

```lua
-- ❌ MAL: Craft.Theme.get() dentro de _applyTheme
function Component:_applyTheme(t)
    local theme = Craft.Theme.get()  -- re-entrancia potencial
    self._bg:SetColorTexture(theme.primary.r, ...)
end

-- ✅ BIEN: usar t directamente
function Component:_applyTheme(t)
    self._bg:SetColorTexture(t.primary.r, t.primary.g, t.primary.b, 1)
end

-- ❌ MAL: color hardcodeado
function Component:_applyTheme(t)
    self._bg:SetColorTexture(0.024, 0.373, 0.275, 1)  -- emerald-800 hardcodeado
end

-- ❌ MAL: borde de 1px sin pixel-perfect
self._border:SetHeight(1)  -- 1 UI unit ≠ 1 pixel físico

-- ✅ BIEN: borde pixel-perfect
Craft.Theme.SetPixelHeight(self._border, 1)

-- ❌ MAL: olvidar unregister en Destroy
function Component:Destroy()
    self.frame:Hide()  -- listener queda activo para siempre
end

-- ✅ BIEN: unregister siempre
function Component:Destroy()
    Craft.Theme.unregister(self._themeHandle)
    self._themeHandle = nil
    self.frame:Hide()
    self.frame:SetParent(nil)
    self.frame = nil
end
```

---

## 6. Tokens disponibles — referencia

Ver `docs/design-reference.md` para valores exactos. Ver `Craft/theme/Presets.lua` para la implementación.

| Token | Tipo | Uso habitual |
|-------|------|-------------|
| `t.background` | RGBA | Fondo de contenedores grandes |
| `t.foreground` | RGBA | Texto principal |
| `t.primary` | RGBA | Emerald-800 — botones, active states |
| `t.primaryForeground` | RGBA | Texto sobre primary |
| `t.secondary` | RGBA | Botones secundarios, tab list |
| `t.muted` | RGBA | Fondos apagados |
| `t.mutedForeground` | RGBA | Placeholders, texto disabled |
| `t.border` | RGBA | Bordes (blanco a=0.1 en dark) |
| `t.input` | RGBA | Fondo de Input/Select |
| `t.ring` | RGBA | Zinc (gris) — solo Input EditBox |
| `t.destructive` | RGBA | Tinte de error |
| `t.font` | string | Ruta Inter-Regular.ttf |
| `t.fontBold` | string | Ruta Inter-Bold.ttf |
| `t.fontSize` | number | 12 (text-xs base de Lyra) |
| `t.fontSizeLg` | number | 14 (text-sm — títulos) |
| `t.radius` | number | 0 — sin redondeo |
| `t.sidebar*` | RGBA | Exclusivos de Craft.Sidebar |

> `t.ring` es **zinc** (gris), no emerald/primary. Solo aplica en Input EditBox al hacer clic (mouse, no teclado).
