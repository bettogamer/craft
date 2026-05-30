# Craft — Instrucciones para Claude Code

Craft es una librería de componentes UI para addons de World of Warcraft escrita en Lua 5.1. Se distribuye como addon instalable (modelo Ace3/LibStub) en CurseForge y Wago. Diseño basado en shadcn Lyra. **Dark mode únicamente** — WoW es dark-mode exclusivo.

## Documentación de referencia

Antes de cualquier tarea no trivial, leer en orden:

1. `AGENTS.md` — contexto completo del proyecto y reglas de dominio
2. `docs/adr/` — **11** decisiones arquitectónicas que definen el proyecto
3. `docs/FSD_v0.1.md` — especificación funcional y contrato de API
4. `docs/design-reference.md` — fuente de verdad de tokens de color (CSS exacto de shadcn Lyra)
5. `docs/pixel-perfect.md` — reglas de escala WoW para 1px y cursor drag

## Estructura clave

```
Craft/                  ← la librería (lo que se distribuye)
├── Craft.lua           ← entry point, LibStub:NewLibrary("Craft-1.0", BUILD)
├── theme/Theme.lua     ← Craft.Theme — sistema de theming con live-switching
├── theme/Presets.lua   ← lyra-dark (único preset — dark mode solo)
├── layout/Flex.lua     ← Craft.Flex — Flexbox en Lua
├── icons/Icons.lua     ← Craft.Icons.Get/Apply/Has/List
├── components/         ← 13 componentes UI (Button, Checkbox, Dialog, Input,
│                          Label, Panel, Scroll, Select, Separator, Sidebar,
│                          Slider, Tabs, Tooltip) + Icons/Flex/Theme como módulos
└── media/              ← Inter.ttf + lucide-*.tga bundled (sin addon companion)

Craft_Browser/          ← addon showcase in-game (pendiente)
tests/                  ← busted + mock_wow.lua (pendiente)
docs/                   ← BRD, MRD, PRD, FSD, DTI, ADRs, design-reference, pixel-perfect
```

## Contrato de componente — el patrón más importante

Todo componente DEBE seguir este contrato exacto:

```lua
local Btn = {}
Btn.__index = Btn

function Btn:Create(parent, config)
  local self = setmetatable({}, Btn)
  -- crear frames aquí
  self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
  self:_applyTheme(Craft.Theme.get())
  return self
end

function Btn:_applyTheme(t)
  -- usar t.primary, t.border, t.background, etc.
  -- NUNCA colores hardcodeados, NUNCA Craft.Theme.get() aquí
end

function Btn:Destroy()
  Craft.Theme.unregister(self._themeHandle)  -- CRÍTICO: evita memory leak
  self.frame:Hide()
  self.frame = nil
end
```

## Decisiones no negociables (de las ADRs)

- **LibStub**: `LibStub:NewLibrary("Craft-1.0", BUILD)` — BUILD es integer incremental
- **Lyra dark only**: Base=Zinc, Accent=Emerald, `radius=0` — sin rounded corners. Solo dark mode. Sin `lyra-light`.
- **Assets bundled**: Inter.ttf y atlas Lucide en `Craft/media/` — sin addon companion
- **Sin TSTL**: no `.d.ts`, no TypeScript
- **Sin portal web**: docs en GitHub, distribución en CurseForge/Wago
- **Anti-taint**: ningún componente puede contaminar Secure Frames de WoW
- **WoW es mouse-only**: sin focus rings por teclado. Input EditBox muestra ring en OnEditFocusGained (click), no por Tab.
- **Pixel-perfect para 1px**: `Craft.Theme.SetPixelHeight/Width(frame, 1)` — nunca `SetHeight(1)` directo

## Tokens del tema — referencia

Usar siempre vía `t.*` en `_applyTheme(t)`. **Fuente de verdad**: `docs/design-reference.md`.

```
t.background        t.foreground
t.card              t.cardForeground
t.popover           t.popoverForeground
t.primary           t.primaryForeground      ← emerald-800 (dark)
t.secondary         t.secondaryForeground
t.muted             t.mutedForeground        ← muted=fondo, mutedForeground=texto
t.accent            t.accentForeground
t.destructive       t.destructiveForeground  ← tinte sutil (bg/20), texto=destructive
t.border            t.input                  ← blanco con alpha en dark
t.ring                                       ← zinc (GRIS), no emerald/primary
t.sidebar           t.sidebarForeground
t.sidebarAccent     t.sidebarAccentForeground ← active/hover de Sidebar items
t.font              t.fontBold               ← rutas Inter bundled
t.fontSize=12       t.fontSizeLg=14          ← text-xs / text-sm de Lyra
t.radius=0          t.borderWidth=1
```

> `t.ring` es zinc (gris), **NO** emerald. En Lyra el ring es un tono neutro.

## Comandos

```bash
luacheck Craft/ --config .luacheckrc   # lint — debe pasar sin warnings nuevos
busted tests/                           # tests unitarios headless
bash scripts/bump-build.sh              # incrementar CRAFT_BUILD antes de release
```

**Slash commands:**

```
/check-traceability        # revisa gaps en BRD→MRD→PRD→FSD
/update-design-tokens      # actualiza tokens desde CSS shadcn + revisa layouts
```

## Convenciones de código

- **Idioma del código**: inglés
- **Idioma de documentación y commits**: español
- **Commits**: Conventional Commits — `feat:`, `fix:`, `docs:`, `refactor:`, `test:`
- **No hacer push**: el maintainer (Alberto Gomez) hace push manualmente
- **Globals WoW**: declarar en `.luacheckrc`, no en el código

## Versioning

`MAJOR.MINOR.PATCH` (SemVer) en git tags + LibStub build number en `Craft.lua`.
Breaking change de API → `"Craft-2.0"` con BUILD=1.
Ver `docs/adr/0010-estrategia-versioning.md`.
