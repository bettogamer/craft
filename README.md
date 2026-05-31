# Craft

**Librería de componentes UI para addons de World of Warcraft.**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Lua 5.1](https://img.shields.io/badge/Lua-5.1-blue.svg)](https://www.lua.org/versions.html#5.1)
[![WoW 11.x+](https://img.shields.io/badge/WoW-11.x%2B-orange.svg)](https://www.curseforge.com/wow/addons/craft)

Craft es una librería open source de componentes UI para WoW addons escrita en Lua 5.1. Resuelve el problema de tener que construir UI desde cero en cada addon — ofrece 16 componentes listos para usar con diseño consistente basado en [shadcn Lyra](https://ui.shadcn.com/themes) (zinc + emerald, radius=0). A diferencia de AceGUI, Craft está diseñado con tokens semánticos de diseño, sistema de theming con live-switching y fuente Inter bundled — sin dependencias externas.

---

## Ver Craft en acción

Instala **[Craft Browser](https://www.curseforge.com/wow/addons/craft-browser)** desde CurseForge — un addon showcase que demuestra los 16 componentes interactivamente dentro de WoW. Usa `/craft` para abrirlo.

---

## Usar Craft en tu addon

**1. Descargar Craft**

Ve a [github.com/bettogamer/craft/releases](https://github.com/bettogamer/craft/releases) y descarga `Craft.zip` de la última versión.

**2. Copiar en tu addon**

Extrae y copia la carpeta `Craft/` en el directorio `libs/` de tu addon:

```
MyAddon/
└── libs/
    └── Craft/
```

**3. Listar los archivos en tu `.toc`**

```
libs\Craft\libs\LibStub.lua
libs\Craft\Craft.lua
libs\Craft\theme\Presets.lua
libs\Craft\theme\Theme.lua
libs\Craft\icons\Atlas.lua
libs\Craft\icons\Icons.lua
libs\Craft\layout\Flex.lua
libs\Craft\components\Button.lua
libs\Craft\components\Input.lua
# ... agrega solo los componentes que uses
```

**4. Obtener la librería**

```lua
local Craft = LibStub("Craft-1.0")
```

**4. Crear tu primer componente**

```lua
local btn = Craft.Button:Create(UIParent, {
  label = "Hola Craft",
  onClick = function() print("click!") end,
})
btn.frame:SetPoint("CENTER")
```

**5. Limpiar al cerrar**

```lua
btn:Destroy()  -- desregistra listeners del tema y libera el frame
```

---

## Ejemplo de uso

```lua
local Craft = LibStub("Craft-1.0")

-- Panel raíz
local panel = Craft.Panel:Create(UIParent, { width = 320, height = 200 })
panel.frame:SetPoint("CENTER")

-- Layout vertical con Flex
local flex = Craft.Flex:Create(panel.frame, {
  direction = "column",
  gap = 8,
  padding = 12,
})

-- Input de texto
local input = Craft.Input:Create(flex.frame, {
  placeholder = "Buscar...",
  width = 280,
})

-- Botón de acción
local btn = Craft.Button:Create(flex.frame, {
  label = "Buscar",
  variant = "default",   -- "default" | "secondary" | "ghost" | "destructive"
  width = 280,
  onClick = function()
    print("Buscando:", input:GetValue())
  end,
})

-- Flex posiciona los hijos automáticamente
flex:Layout()
```

---

## Componentes

| Componente | Descripción |
|---|---|
| `Button` | Botón con 4 variantes de estilo |
| `Checkbox` | Casilla con estado on/off |
| `Dialog` | Modal con header y footer |
| `Flex` | Motor de layout tipo flexbox |
| `Icons` | Íconos Lucide desde atlas TGA |
| `Input` | Campo de texto con placeholder |
| `Label` | Texto semántico con variantes |
| `Panel` | Contenedor base con fondo |
| `Scroll` | Panel con scroll vertical |
| `Select` | Dropdown de opciones |
| `Separator` | Línea divisoria horizontal/vertical |
| `Sidebar` | Panel de navegación lateral |
| `Slider` | Control deslizante de valor |
| `Tabs` | Pestañas con contenido intercambiable |
| `Theme` | Sistema de theming con live-switching |
| `Tooltip` | Globo de ayuda contextual |

---

## Theming

Craft incluye el preset `lyra-dark` por defecto. Puedes extenderlo o crear el tuyo:

```lua
local Craft = LibStub("Craft-1.0")

-- Cambiar a un preset registrado
Craft.Theme.use("mi-tema")

-- Extender lyra-dark con valores propios
Craft.Theme.extend("mi-tema", "lyra-dark", {
  primary = { 0.2, 0.6, 0.9, 1 },          -- RGBA
  primaryForeground = { 1, 1, 1, 1 },
})

-- Activar el tema extendido
Craft.Theme.use("mi-tema")
```

Los componentes ya registrados reciben el nuevo tema automáticamente (live-switching). No necesitas recrearlos.

Los tokens disponibles son: `background`, `foreground`, `primary`, `primaryForeground`, `secondary`, `muted`, `mutedForeground`, `border`, `input`, `ring`, `destructive`, `card`, `accent`, y tokens específicos de `sidebar`.

---

## Craft_Browser

Craft incluye un addon showcase — **Craft_Browser** — que muestra todos los componentes en juego con sus variantes y estados.

Instala `Craft_Browser` desde CurseForge/Wago y usa el comando de chat:

```
/craft
```

Se abre un panel interactivo donde puedes explorar cada componente, cambiar de tema en tiempo real y ver el código de ejemplo correspondiente.

---

## Desarrollo

Requisitos: `luacheck`, `busted`, Lua 5.1.

```bash
# Lint — debe pasar sin warnings nuevos
luacheck Craft/ --config .luacheckrc

# Tests unitarios headless
busted tests/

# Incrementar CRAFT_BUILD antes de un release
bash scripts/bump-build.sh
```

El CI en GitHub Actions ejecuta lint + tests en cada push y PR.

---

## Contribuir

Lee [CONTRIBUTING.md](CONTRIBUTING.md) antes de abrir un PR.

Puntos clave: todos los componentes deben seguir el contrato de componente (ver `AGENTS.md §5`), los colores siempre via tokens semánticos `t.*`, sin border radius, sin TypeScript/TSTL.

---

## Licencia

MIT — ver [LICENSE](LICENSE).
