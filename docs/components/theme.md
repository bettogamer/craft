# Component: Theme

> Referencia shadcn: CSS Variables / ThemeProvider — Módulo Lua puro — sistema de theming con callbacks

## Propósito

Módulo central de tokens de diseño: gestiona el preset activo, construye la tabla de tokens resuelta con lazy caching, y notifica a todos los componentes registrados cuando el tema cambia para que se repinten in-place.

## Arquitectura del módulo

```
Craft.Theme
├── _active       (string)        — nombre del preset activo, e.g. "lyra-dark"
├── _resolved     (table | nil)   — tabla de tokens resuelta; nil hasta el primer get() o tras use()
├── _listeners    (table)         — array de {handle=int, fn=function} registrados por componentes
├── _handleCount  (number)        — contador autoincremental para generar handles únicos
└── _presets      (table)         — presets disponibles: CraftPresets + los registrados con register_preset()

CraftPresets  (global table)  — definida en theme/Presets.lua, cargada antes
              que Theme.lua en Craft.toc. Craft.Theme._presets apunta a ella.
              Nunca mutar CraftPresets directamente — usar register_preset().
```

`_presets` se inicializa como referencia directa a `CraftPresets` (de `theme/Presets.lua`) y se extiende con `register_preset()`. El preset activo nunca se muta — cada `extend()` retorna una tabla nueva.

## API pública

| Función                                  | Firma                             | Descripción                                                                                                            |
|------------------------------------------|-----------------------------------|------------------------------------------------------------------------------------------------------------------------|
| `Craft.Theme.use(preset, variant?)`      | `(string\|table, string?) → void` | Cambia el preset activo. `preset` puede ser el nombre de un preset registrado o una tabla custom. Invalida `_resolved` y notifica a todos los listeners. |
| `Craft.Theme.get()`                      | `() → table`                      | Retorna la tabla de tokens del preset activo. Lazy: construye `_resolved` en el primer llamado y lo cachea hasta el próximo `use()`. |
| `Craft.Theme.register(fn)`               | `(function) → handle`             | Registra un listener que recibe la tabla de tokens como argumento cada vez que el tema cambia. Retorna un handle opaco (entero). |
| `Craft.Theme.unregister(handle)`         | `(handle) → void`                 | Desregistra el listener por handle. **Debe llamarse en `Destroy()` de todo componente** para evitar memory leaks.      |
| `Craft.Theme.extend(base, overrides)`    | `(string, table) → table`         | Retorna una tabla nueva que mezcla el preset `base` con los `overrides`. No registra el resultado — usarlo con `use()` o `register_preset()`. |
| `Craft.Theme.register_preset(name, tbl)` | `(string, table) → void`          | Registra un preset con nombre para uso futuro con `use(name)`.                                                         |
| `Craft.Theme.getFont(weight?)`           | `("regular"\|"bold") → string`    | Shortcut de `get().font` / `get().fontBold`. Retorna la ruta de la fuente.                                            |
| `Craft.Theme.getPresets()`               | `() → string[]`                   | Lista los nombres de todos los presets disponibles (built-in + registrados).                                           |
| `Craft.Theme.px(n, frame?)`              | `(number, Frame?) → number`        | Convierte `n` píxeles físicos a UI units. Usa `PixelUtil` si disponible; si no, `math.max(n/scale, 0.5)`. `frame` es opcional — si se pasa, usa `frame:GetEffectiveScale()` en lugar de `UIParent`. |
| `Craft.Theme.SetPixelHeight(frame, n)`   | `(Frame, number) → void`           | Aplica altura de `n` píxeles físicos. `PixelUtil.SetHeight(frame, n, 1)` en Retail; fallback en Classic.              |
| `Craft.Theme.SetPixelWidth(frame, n)`    | `(Frame, number) → void`           | Ídem para ancho.                                                                                                       |
| `Craft.Theme.SetPixelSize(frame, w, h)`  | `(Frame, number, number) → void`   | Ídem para ancho y alto simultáneamente.                                                                                |
| `Craft.Theme.isPixelPerfect()`           | `() → boolean`                     | `true` si `UIParent:GetEffectiveScale() ≈ 1.0` (tolerancia 0.01).                                                    |

### Presets built-in

| Nombre        | Descripción |
|---------------|-------------|
| `"lyra-dark"` | **Único preset built-in.** Zinc-950 background, emerald-800 primary. |

> **¿Por qué solo dark?** WoW addon dev es dark-mode exclusivo — el juego y todos los
> addons populares (ElvUI, WeakAuras, Details!, Plater) usan fondos oscuros. Un preset
> `lyra-light` sería código muerto. Sus valores están en `docs/design-reference.md §3`
> como referencia. Addons que necesiten un tema claro pueden usar `register_preset()`.

## Comportamiento detallado

### `use(preset, variant?)`

1. Si `preset` es string: buscar en `_presets[preset]`. Si no existe, loguear una advertencia y retornar sin cambios.
2. Si `preset` es tabla: usarla directamente como definición del preset (preset custom anónimo).
3. Actualizar `_active` con el nombre (o `"custom"` si es tabla).
4. Invalidar `_resolved = nil`.
5. Llamar `get()` para construir el nuevo `_resolved` inmediatamente.
6. Iterar `_listeners` en orden de inserción y llamar `fn(_resolved)` en cada uno.
7. Los frames se actualizan in-place — no se destruyen ni recrean.

`variant?` está reservado para futuras extensiones (e.g., `use("lyra", "dark")`). En v1.0 se ignora si `preset` ya es el nombre completo.

### `get()`

- Si `_resolved ~= nil`: retornar `_resolved` directamente (cache hit — O(1)).
- Si `_resolved == nil`: copiar el preset activo de `_presets[_active]` en una tabla nueva (shallow copy), guardar en `_resolved`, retornar.

La tabla retornada por `get()` **no debe mutarse**. Los componentes deben tratar el valor retornado como read-only. Si un componente necesita valores derivados, calcularlos localmente.

**Shallow copy e inmutabilidad**: `get()` hace una copia shallow del preset activo —
los tokens escalares (números, strings) se copian por valor; los tokens de color
(`{r,g,b,a}`) se copian por referencia (misma tabla que en el preset). Por esto:

- Los componentes MUST tratar `t` como read-only. Nunca `t.primary.r = 0`.
- Mutación de un token de color corrompe el preset base permanentemente.
- Si se necesita un color derivado, calcularlo localmente:
  `local hoverR = t.primary.r` — correcto.
  `t.primary.r = 0.5` — INCORRECTO, corrompe el preset.

### `extend(base, overrides)`

```lua
-- Retorna una tabla nueva — no registra ni activa el preset
local myTheme = Craft.Theme.extend("lyra-dark", {
  primary = {r=0.5, g=0.0, b=0.5, a=1},  -- sobreescribir solo primary
})
Craft.Theme.use(myTheme)
```

Implementado como merge shallow: `for k, v in pairs(overrides) do result[k] = v end`. Las claves no presentes en `overrides` se heredan del preset base sin modificación.

**Tokens de color en overrides**: el merge es shallow. Si se sobreescribe un token
de color, la tabla override debe ser RGBA completa:

```lua
-- CORRECTO: tabla completa
Craft.Theme.extend("lyra-dark", { primary = {r=0.5, g=0.0, b=0.5, a=1} })

-- INCORRECTO: tabla parcial — g, b, a quedarán nil
Craft.Theme.extend("lyra-dark", { primary = {r=0.5} })  -- NO HACER
```

### `register(fn)` y `unregister(handle)`

```lua
-- _handleCount empieza en 0
Craft.Theme._handleCount = Craft.Theme._handleCount + 1
local handle = Craft.Theme._handleCount
table.insert(Craft.Theme._listeners, { handle = handle, fn = fn })
return handle
```

`unregister(handle)` itera `_listeners` buscando el handle y elimina la entrada con `table.remove`. Si el handle no se encuentra, no hace nada (no es un error).

## Flujo de un componente — ejemplo completo

Este es el patrón estándar que **todos los componentes de Craft deben seguir**:

```lua
-- ============================================================
-- Craft.Badge — ejemplo de componente que consume Craft.Theme
-- ============================================================

function Craft.Badge.Create(parent, config)
  local self = {}

  -- 1. Crear frames internos
  self.frame  = CreateFrame("Frame", nil, parent)
  self._bg    = self.frame:CreateTexture(nil, "BACKGROUND")
  self._label = self.frame:CreateFontString(nil, "OVERLAY")

  self._bg:SetAllPoints(self.frame)

  -- 2. Registrar listener de tema
  --    La función recibe la tabla de tokens resuelta cada vez que el tema cambia.
  self._themeHandle = Craft.Theme.register(function(t)
    self:_applyTheme(t)
  end)

  -- 3. Aplicar tema inicial inmediatamente (sin esperar un cambio)
  self:_applyTheme(Craft.Theme.get())

  -- 4. Aplicar config inicial (texto, variante, etc.)
  if config.text then self._label:SetText(config.text) end

  return self
end

function Craft.Badge:_applyTheme(t)
  -- Aplicar todos los tokens visuales del componente
  self._bg:SetColorTexture(t.secondary.r, t.secondary.g, t.secondary.b, t.secondary.a)
  self._label:SetFont(t.font, t.fontSizeSm)
  self._label:SetTextColor(t.secondaryForeground.r, t.secondaryForeground.g, t.secondaryForeground.b)
end

function Craft.Badge:Destroy()
  -- CRÍTICO: desregistrar el listener antes de destruir los frames.
  -- Si se omite, el listener queda activo y el próximo use() intentará
  -- acceder a frames ya destruidos → error de Lua o comportamiento indefinido.
  Craft.Theme.unregister(self._themeHandle)
  self._themeHandle = nil

  self.frame:Hide()
  self.frame:SetParent(nil)
  self.frame = nil
end
```

### Cambio de tema en runtime

```lua
-- Aplicar un tema personalizado registrado por el addon
Craft.Theme.use("mi-addon-dark")

-- Usar un preset custom (anónimo, no registrado con nombre)
local highContrast = Craft.Theme.extend("lyra-dark", {
  foreground = {r=1, g=1, b=1, a=1},
  background = {r=0, g=0, b=0, a=1},
})
Craft.Theme.use(highContrast)

-- Registrar un preset con nombre para reutilizarlo más tarde
Craft.Theme.register_preset("my-addon-dark", {
  -- tabla completa de tokens
})
Craft.Theme.use("my-addon-dark")
```

## Mapa de tokens — referencia rápida

Para completitud, los tokens que `get()` expone (definidos en `theme/Presets.lua`):

| Token                    | Tipo          | Descripción                                            |
|--------------------------|---------------|--------------------------------------------------------|
| `background`             | RGBA table    | Fondo de la aplicación                                 |
| `foreground`             | RGBA table    | Texto principal                                        |
| `card` / `cardForeground`| RGBA table    | Fondo y texto de tarjetas                              |
| `popover` / `popoverForeground` | RGBA table | Fondo y texto de tooltips y dropdowns             |
| `primary` / `primaryForeground` | RGBA table | Color de acento principal y su contraste          |
| `secondary` / `secondaryForeground` | RGBA table | Color secundario y su contraste               |
| `muted` / `mutedForeground` | RGBA table | Color apagado y su contraste (placeholder, disabled) |
| `accent` / `accentForeground` | RGBA table | Hover de ghost/outline, filas de tabla             |
| `destructive`            | RGBA table    | Color para acciones destructivas / errores             |
| `destructiveForeground`  | RGBA table    | Texto sobre fondo destructive                          |
| `border`                 | RGBA table    | Borde de todos los componentes (a=0.1 en dark)         |
| `input`                  | RGBA table    | Fondo de Input, Select trigger (a=0.15 en dark)        |
| `ring`                   | RGBA table    | Focus ring (zinc, no emerald)                          |
| `sidebar` / `sidebarForeground` | RGBA table | Tokens exclusivos del componente Sidebar          |
| `sidebarAccent` / `sidebarAccentForeground` | RGBA table | Hover y active items del Sidebar              |
| `sidebarPrimary` / `sidebarPrimaryForeground` | RGBA table | Item activo del Sidebar (emerald-500/950)     |
| `sidebarBorder`          | RGBA table    | Borde del Sidebar (blanco a=0.1 en dark)               |
| `sidebarRing`            | RGBA table    | Ring del Sidebar                                       |
| `radius`                 | number        | `0` — sin redondeo de esquinas (Lyra)                  |
| `font`                   | string        | Ruta Inter-Regular.ttf                                 |
| `fontBold`               | string        | Ruta Inter-Bold.ttf                                    |
| `fontSize`               | number        | `12` — tamaño base de texto (px WoW)                   |
| `fontSizeSm`             | number        | `11` — texto pequeño                                   |
| `fontSizeLg`             | number        | `14` — headings                                        |
| `spacingXs/Sm/Md/Lg/Xl` | number        | `4 / 8 / 12 / 16 / 24` px                             |
| `borderWidth`            | number        | `1`                                                    |
| `focusRingWidth`         | number        | `2`                                                    |
| `iconSizeSm`             | number        | `16`                                                   |
| `iconSizeMd`             | number        | `24`                                                   |

**t.fontSize vs tablas SIZES de componente**: los tokens `fontSize`, `fontSizeSm` y
`fontSizeLg` son para elementos de texto genérico que no tienen su propia tabla de
tamaños (Label, descripción de Card, texto de Tooltip). Los componentes con variantes
de tamaño propias (Button, Input, Select) usan sus tablas SIZES internas — no estos tokens.

## Notas de implementación

**Helpers de pixel-perfect (ADR-0011)**: los métodos `px()`, `SetPixelHeight()`, `SetPixelWidth()`, `SetPixelSize()` e `isPixelPerfect()` garantizan que los frames queden alineados a píxeles físicos sin sub-pixel blending. Implementación de referencia:

```lua
function Craft.Theme.px(n, frame)
    local scale = (frame or UIParent):GetEffectiveScale()
    return math.max(n / scale, 0.5)
end

function Craft.Theme.SetPixelHeight(frame, n)
    if PixelUtil then
        PixelUtil.SetHeight(frame, n, 1)
    else
        frame:SetHeight(Craft.Theme.px(n, frame))
    end
end

function Craft.Theme.SetPixelWidth(frame, n)
    if PixelUtil then
        PixelUtil.SetWidth(frame, n, 1)
    else
        frame:SetWidth(Craft.Theme.px(n, frame))
    end
end

function Craft.Theme.SetPixelSize(frame, w, h)
    if PixelUtil then
        PixelUtil.SetSize(frame, w, h, 1, 1)
    else
        frame:SetWidth(Craft.Theme.px(w, frame))
        frame:SetHeight(Craft.Theme.px(h, frame))
    end
end

function Craft.Theme.isPixelPerfect()
    return math.abs(UIParent:GetEffectiveScale() - 1.0) < 0.01
end
```

Ver también: `docs/pixel-perfect.md` para las reglas completas de ADR-0011 y los casos de uso de cada helper.

**Relación entre Presets.lua y Theme.lua**: `Presets.lua` define la tabla global `CraftPresets` con el preset built-in `lyra-dark`. `Theme.lua` la referencia en la inicialización: `T._presets = CraftPresets`. El orden en `Craft.toc` garantiza que `CraftPresets` existe cuando `Theme.lua` carga.

**Orden de carga en Craft.toc**: el orden correcto de archivos en el addon es:
```
libs/LibStub/LibStub.lua
Craft.lua            ← crea el namespace Craft via LibStub
theme/Presets.lua    ← define CraftPresets (global)
theme/Theme.lua      ← define Craft.Theme, referencia CraftPresets
icons/Atlas.lua      ← define Craft.Icons._atlas16/_atlas24
icons/Icons.lua      ← define Craft.Icons.Get/Apply/Has/List
layout/Flex.lua      ← define Craft.Flex
components/Button.lua
components/...       ← resto de componentes
```
Cualquier componente que cargue antes que `Theme.lua` fallará con "attempt to index a nil value (global 'Craft')".

**Memory leak por listeners no desregistrados**: Si un componente es destruido sin llamar `unregister()`, su función listener permanece en `_listeners`. En el próximo `use()`, el sistema intentará llamar la función, que puede acceder a `self.frame` ya destruido. En el mejor caso produce un error de Lua "attempt to index a nil value"; en el peor, accede a un frame de otro addon que reutilizó la memoria. Siempre llamar `unregister` en `Destroy()`.

**Handles son enteros simples**: No usar los handles como índices de tabla. El handle es solo un identificador opaco para buscar y eliminar de `_listeners`. Internamente, `_handleCount` es un contador global que solo crece — nunca se reutilizan handles.

**`use()` es sincrónico**: Todos los listeners se llaman en el mismo frame de CPU que `use()`. Si hay muchos componentes registrados, el cambio de tema puede causar un spike de tiempo de frame visible. Para addons con >100 componentes, considerar diferir la notificación con `C_Timer.After(0, fn)` para distribuirla.

**No llamar `use()` dentro de un listener**: Causaría re-entrada en la iteración de `_listeners`, con comportamiento indefinido. El módulo no protege contra esto — es responsabilidad del implementador.

**`get()` retorna siempre la misma tabla dentro de un ciclo de tema**: Dado que `_resolved` se cachea hasta el próximo `use()`, múltiples llamadas a `get()` en el mismo frame retornan la misma tabla Lua. Los componentes pueden guardar la referencia a `t = Craft.Theme.get()` al inicio de `_applyTheme()` y usarla libremente — no necesitan llamar `get()` repetidamente.

**Inicialización del preset por defecto**: Al cargar el addon, `_active = "lyra-dark"` y `_resolved = nil`. El primer componente que llame `Craft.Theme.get()` construirá `_resolved`. Si ningún componente llama `get()` antes de `use()`, no hay costo de construcción.
