# Craft_Browser — Spec

> Addon de showcase in-game que demuestra los 16 componentes MVP de Craft
> usando los propios componentes de la librería. ADR-0004.
>
> **Stack interno:** Craft.Sidebar, Craft.Scroll, Craft.Slider,
> Craft.Label, Craft.Separator, Craft.Flex + frames nativos WoW para
> la ventana principal y el toolbar.

---

## 1. Estructura de archivos

```
Craft_Browser/
├── Craft_Browser.toc
├── Browser.lua           ← ventana, toolbar, nav, SavedVariables
└── pages/
    ├── Button.lua
    ├── Checkbox.lua
    ├── Dialog.lua
    ├── Flex.lua
    ├── Icons.lua
    ├── Input.lua
    ├── Label.lua
    ├── Panel.lua
    ├── Scroll.lua
    ├── Select.lua
    ├── Separator.lua
    ├── Sidebar.lua
    ├── Slider.lua
    ├── Tabs.lua
    ├── Theme.lua
    └── Tooltip.lua
```

---

## 2. Craft_Browser.toc

```
## Interface: 120000
## Title: Craft Browser
## Notes: Interactive showcase of Craft UI components
## Author: bettogamer
## Version: @project-version@
## X-License: MIT
## SavedVariables: CraftBrowserDB
# Note: Craft embedded in libs/Craft/ (generated in CI — see ADR-0012)

Browser.lua
pages\Button.lua
pages\Checkbox.lua
pages\Dialog.lua
pages\Flex.lua
pages\Icons.lua
pages\Input.lua
pages\Label.lua
pages\Panel.lua
pages\Scroll.lua
pages\Select.lua
pages\Separator.lua
pages\Sidebar.lua
pages\Slider.lua
pages\Tabs.lua
pages\Theme.lua
pages\Tooltip.lua
```

---

## 3. SavedVariables — CraftBrowserDB

```lua
-- Defaults (se aplican si la key no existe)
CraftBrowserDB = CraftBrowserDB or {}
CraftBrowserDB.x      = CraftBrowserDB.x      or nil    -- nil = centrar en pantalla
CraftBrowserDB.y      = CraftBrowserDB.y      or nil
CraftBrowserDB.width  = CraftBrowserDB.width  or 800
CraftBrowserDB.height = CraftBrowserDB.height or 600
CraftBrowserDB.scale  = CraftBrowserDB.scale  or 100    -- porcentaje 50–150
CraftBrowserDB.page   = CraftBrowserDB.page   or "Button"
```

Guardar en `OnDragStop` y en el callback de resize del handle.

---

## 4. Layout general

```
┌──────────────┬──────────────────────────────────────────┐  800×600
│ Craft Browser│  Button · Elemento interactivo...         │  ← demoHeader 40px
│           ✕  ├──────────────────────────────────────────┤
├──────────────┤                                           │
│ Form Controls│         DEMO AREA                         │
│  Button      │         Craft.Scroll                      │
│  Checkbox    │                                           │
│  Input       │                                           │
│  Select      │                                           │
│  Slider      │                                           │
│ Layout       │                                           │
│  Flex        │                                           │
│  ...         │                                       ◢  │
├──────────────┤                                           │
│ ━━●━━━  100%│                                           │  ← SidebarFooter
└──────────────┴──────────────────────────────────────────┘
  ↑ SidebarRail (6px, colapsa el sidebar)
```

**Dimensiones:**
- Ventana: 800×600 default, min 600×400, sin max
- Header: 40px de alto
- Sidebar: 200px de ancho fijo (`shrink=0` en Flex)
- Demo area: ancho restante (`grow=1` en Flex)
- Resize handle: 16×16px en la esquina bottom-right

**Layout del contenido (Craft.Flex):**
```lua
local mainFlex = Craft.Flex.new(contentFrame, {
    direction = "row",
    gap       = 0,
})
mainFlex:Add(sidebar:GetFrame(), { basis = 200, shrink = 0, grow = 0 })
mainFlex:Add(scrollFrame,        { grow  = 1 })
mainFlex:Layout()
-- Re-layout en OnSizeChanged de contentFrame
```

---

## 5. Header / Toolbar

Frame nativo de 40px de alto, anclado arriba de la ventana.

**Elementos (izquierda → derecha):**
```
[Title "Craft Browser"]  ·····  [Slider 50-150%]  [Label "100%"]  [✕]
```

| Elemento | Implementación | Detalles |
|---|---|---|
| Título | `Craft.Label` | "Craft Browser", fontBold, fontSizeLg=14, foreground |
| Slider de escala | `Craft.Slider` | min=50, max=150, step=5, showValue=false |
| Label de valor | `Craft.Label` | "100%", se actualiza con el slider |
| Botón cerrar | Button nativo + ícono `x` | 24×24px, top-right |

**Comportamiento del slider de escala:**
- El valor afecta solo al `demoFrame` (el Frame dentro de Craft.Scroll)
- `demoFrame:SetScale(scale / 100)`
- El sidebar y el toolbar NO se escalan
- El valor se guarda en `CraftBrowserDB.scale`

**Drag:** el header es el drag handle de la ventana principal:
```lua
header:SetScript("OnMouseDown", function() mainFrame:StartMoving() end)
header:SetScript("OnMouseUp",   function()
    mainFrame:StopMovingOrSizing()
    -- Guardar posición
    CraftBrowserDB.x = mainFrame:GetLeft()
    CraftBrowserDB.y = mainFrame:GetTop() - UIParent:GetHeight()
end)
```

---

## 6. Navegación — Craft.Sidebar

```lua
local nav = Craft.Sidebar:Create(navFrame, {
    size         = "default",
    activeItem   = CraftBrowserDB.page,
    -- Grupos por categoría
})
-- Form Controls
nav:AddSection("Form Controls")
nav:AddItem({ id="Button",    label="Button",    section="Form Controls" })
nav:AddItem({ id="Checkbox",  label="Checkbox",  section="Form Controls" })
nav:AddItem({ id="Input",     label="Input",     section="Form Controls" })
nav:AddItem({ id="Select",    label="Select",    section="Form Controls" })
nav:AddItem({ id="Slider",    label="Slider",    section="Form Controls" })
-- Layout
nav:AddSection("Layout")
nav:AddItem({ id="Flex",      label="Flex",      section="Layout" })
nav:AddItem({ id="Panel",     label="Panel",     section="Layout" })
nav:AddItem({ id="Scroll",    label="Scroll",    section="Layout" })
nav:AddItem({ id="Separator", label="Separator", section="Layout" })
-- Navigation
nav:AddSection("Navigation")
nav:AddItem({ id="Dialog",    label="Dialog",    section="Navigation" })
nav:AddItem({ id="Sidebar",   label="Sidebar",   section="Navigation" })
nav:AddItem({ id="Tabs",      label="Tabs",      section="Navigation" })
-- Display
nav:AddSection("Display")
nav:AddItem({ id="Icons",     label="Icons",     section="Display" })
nav:AddItem({ id="Label",     label="Label",     section="Display" })
nav:AddItem({ id="Theme",     label="Theme",     section="Display" })
nav:AddItem({ id="Tooltip",   label="Tooltip",   section="Display" })
```

Al hacer clic en un item: cargar la página correspondiente y guardar en `CraftBrowserDB.page`.

---

## 7. Demo area — Craft.Scroll + demoFrame escalable

```lua
local demoScroll = Craft.Scroll:Create(demoContainer, {
    width  = demoContainer:GetWidth(),
    height = demoContainer:GetHeight(),
})

local demoFrame = demoScroll:GetScrollChild()
demoFrame:SetScale(CraftBrowserDB.scale / 100)
```

Cada página de componente recibe `demoFrame` como parent y popula su contenido usando el patrón estándar de sección.

---

## 8. Patrón de sección en cada página

Todas las páginas usan este patrón:

```lua
-- Helper disponible para todas las páginas
local function Section(parent, title, yOffset)
    local label = Craft.Label:Create(parent, {
        text  = title,
        color = { r=t.mutedForeground.r, g=t.mutedForeground.g,
                  b=t.mutedForeground.b, a=1 },
    })
    label:GetFrame():SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -(yOffset + 8))

    local sep = Craft.Separator:Create(label:GetFrame())
    -- posicionado bajo el label
    return sep, yOffset + 24
end

-- Flex para los elementos de la sección
local function SectionFlex(parent, yAnchor)
    return Craft.Flex.new(parent, {
        direction = "row",
        wrap      = "wrap",
        gap       = 8,
        paddingH  = 16,
        paddingV  = 8,
    })
end
```

---

## 9. Contenido de cada página

### Button.lua
```
── Variantes ─────────────────
[Default] [Destructive] [Outline] [Secondary] [Ghost] [Link]

── Tamaños ───────────────────
[xs] [sm] [Default] [lg]

── Con ícono ─────────────────
[◀ Left] [Right ▶] [✓] [×]

── Solo ícono ────────────────
[icon-xs] [icon-sm] [icon] [icon-lg]

── Disabled ──────────────────
[Default dis.] [Destructive dis.] [Outline dis.]
```

### Checkbox.lua
```
── Estados ───────────────────
○ Unchecked    ✓ Checked    ─ Indeterminate

── Con label ─────────────────
✓ Acepto los términos

── Disabled ──────────────────
○ (disabled)   ✓ (disabled)
```

### Input.lua
```
── Default ───────────────────
[                    ]

── Con placeholder ───────────
[Escribe algo...     ]

── Con íconos ────────────────
[🔍                  ]   [                  👁]

── Error ─────────────────────
[Campo requerido     ]  ← borde rojo

── Disabled ──────────────────
[                    ]  ← opacidad 50%
```

### Select.lua
```
── Default ───────────────────
[Selecciona...   ▼]

── Tamaño sm ─────────────────
[Selecciona...   ▼]  (más pequeño)

── Disabled ──────────────────
[Selecciona...   ▼]  ← opacidad 50%
```

### Slider.lua
```
── Default ───────────────────
0 ━━━━●━━━━━━━━━━━ 100

── Con valor ─────────────────
0 ━━━━━━●━━━━━━━━ 100
            60

── Con min/max labels ────────
0          ━━━●━━━          100

── Disabled ──────────────────
0 ━━━━━━━━━━━━━━━━ 100  ← opacidad 50%
```

### Separator.lua
```
── Horizontal ────────────────
────────────────────────────

── Vertical ──────────────────
│ (dentro de un flex row)
```

### Label.lua
```
── Variantes ─────────────────
Texto normal (foreground)
Texto muted (mutedForeground)
Texto clickeable (primary, con hover)

── Con maxWidth ──────────────
Este texto es muy larg...
```

### Panel.lua
```
┌─────────────────┐
│ Título del panel│
│ Descripción     │
│                 │
│ Contenido aquí  │
│─────────────────│
│ Footer          │
└─────────────────┘
```

### Dialog.lua
```
── Abrir Dialog ──────────────
[Abrir Dialog →]

(Al hacer clic abre un Dialog de demo con título, contenido y botones)
```

### Tabs.lua
```
[Tab 1] [Tab 2] [Tab 3]
───────────────────────
Contenido del tab activo
```

### Scroll.lua
```
┌─────────────────┐
│ Item 1          │
│ Item 2          │  ← scroll area 150px
│ Item 3          │    con 20 items
│ ...             │
└─────────────────┘
```

### Sidebar.lua
```
(Preview de un Craft.Sidebar dentro del demo)
── Componentes ───
  Button
  Input
  ─────────────
── Utilidades ────
  Theme
  Flex
```

### Tooltip.lua
```
── Attach a botón ────────────
[Hover aquí]  ← tooltip aparece encima

── Con ícono ─────────────────
[Hover aquí]  ← tooltip con ícono info
```

### Flex.lua
```
── Row (gap 8) ───────────────
[A] [B] [C] [D]

── Column (gap 8) ────────────
[A]
[B]
[C]

── Row wrap ──────────────────
[A] [B] [C]
[D] [E]

── Grow ──────────────────────
[A] [━━━━B━━━━] [C]
     (grow=1)
```

### Icons.lua
```
── Sistema (requeridos) ──────
[✓] [─] [⌄] [›] [∧] [✕] [👁] [👁]
check minus chev-down ...

── Conveniencia ──────────────
[ℹ] [✓○] [!○] [△!] [↻] [🔍] [+]
info circle-check ...
```

### Theme.lua
```
── Tokens de color ───────────
● background    #09090b
● foreground    #fafafa
● primary       #065f46
● secondary     #27272a
...

── Espaciado ─────────────────
spacingXs = 4px  [████]
spacingSm = 8px  [████████]
...
```

---

## 10. Slash commands

```lua
SLASH_CRAFT1 = "/craft"
SlashCmdList["CRAFT"] = function(msg)
    if msg == "" then
        CraftBrowser.Toggle()
    else
        CraftBrowser.Open()
        CraftBrowser.Navigate(msg)  -- "/craft button" → navega a Button
    end
end
```

---

## 11. Resize handle

Frame de 16×16px anclado en `BOTTOMRIGHT` de la ventana.

```lua
local resizeHandle = CreateFrame("Frame", nil, mainFrame)
resizeHandle:SetSize(16, 16)
resizeHandle:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, 0)
resizeHandle:EnableMouse(true)
resizeHandle:SetScript("OnMouseDown", function()
    mainFrame:StartSizing("BOTTOMRIGHT")
end)
resizeHandle:SetScript("OnMouseUp", function()
    mainFrame:StopMovingOrSizing()
    -- Guardar tamaño
    CraftBrowserDB.width  = mainFrame:GetWidth()
    CraftBrowserDB.height = mainFrame:GetHeight()
    -- Re-layout
    CraftBrowser._relayout()
end)
-- Textura de flecha ◢
local tex = resizeHandle:CreateTexture(nil, "OVERLAY")
tex:SetAllPoints(resizeHandle)
Craft.Icons.Apply(tex, "grip-vertical", 16)
local t = Craft.Theme.get()
tex:SetVertexColor(t.mutedForeground.r, t.mutedForeground.g, t.mutedForeground.b, 1)
```

---

## 13. SidebarRail

El Craft.Sidebar incluye un rail de 6px en el borde derecho (SidebarRail).
En Craft_Browser, habilitar el colapso para que el dev pueda ver el demo
más amplio:

    nav:SetCollapsible(true)

Cuando el sidebar está colapsado, solo el rail de 6px es visible.
El demo area ocupa el ancho completo (mainFlex re-layoutea automáticamente
porque el sidebar frame cambia de ancho).

---

## 14. Demo area header

Barra de 40px encima del Craft.Scroll con el nombre y descripción
del componente activo:

    ┌─────────────────────────────────┐
    │ Button  ·  Elemento interactivo │  40px, Craft.Label + Craft.Separator
    └─────────────────────────────────┘

Implementación en Browser.lua:
    self._demoTitle = Craft.Label:Create(demoHeader, {
        text  = "Button",
        color = { r=t.foreground.r, g=t.foreground.g, b=t.foreground.b, a=1 },
    })
    self._demoDesc = Craft.Label:Create(demoHeader, {
        text  = "Elemento interactivo que ejecuta una acción",
        color = { r=t.mutedForeground.r, g=t.mutedForeground.g, b=t.mutedForeground.b, a=1 },
    })
    self._demoSep = Craft.Separator:Create(demoHeader)

Cada página define su metadata:
    -- En pages/Button.lua
    return {
        title = "Button",
        desc  = "Elemento interactivo que ejecuta una acción al clic",
        render = function(parent) ... end,
    }

---

## 12. Registro de cambios

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| v0.1 | 31/05/2026 | Alberto Gomez | Spec inicial — layout, SavedVariables, páginas de demo, slash commands |
| v0.2 | 31/05/2026 | Alberto Gomez | Grupos de navegación por categoría; SidebarRail con colapso; demo area header con título y descripción |
