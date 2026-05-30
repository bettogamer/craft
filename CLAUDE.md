# Craft — Instrucciones para Claude Code

Craft es una librería de componentes UI para addons de World of Warcraft escrita en Lua 5.1. Se distribuye como addon instalable (modelo Ace3/LibStub) en CurseForge y Wago. Diseño basado en shadcn Lyra.

## Documentación de referencia

Antes de cualquier tarea no trivial, leer en orden:

1. `AGENTS.md` — contexto completo del proyecto y reglas de dominio
2. `docs/adr/` — 10 decisiones arquitectónicas que definen el proyecto
3. `docs/FSD_v0.1.md` — especificación funcional y contrato de API

## Estructura clave

```
Craft/                  ← la librería (lo que se distribuye)
├── Craft.lua           ← entry point, LibStub:NewLibrary("Craft-1.0", BUILD)
├── theme/Theme.lua     ← Craft.Theme — sistema de theming con live-switching
├── theme/Presets.lua   ← tokens Lyra (Zinc base, Emerald accent, Radius=0)
├── layout/Flex.lua     ← Craft.Flex — Flexbox en Lua
├── icons/Icons.lua     ← Craft.Icons.Get(name)
├── components/         ← 16 componentes MVP
└── media/              ← Inter.ttf + lucide-*.tga bundled (sin addon companion)

Craft_Browser/          ← addon showcase in-game
tests/                  ← busted + mock_wow.lua
docs/                   ← BRD, MRD, PRD, FSD, DTI, ADRs (no se distribuye)
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
  Craft.Theme.unregister(self._themeHandle)
  self.frame:Hide()
  self.frame = nil
end
```

## Decisiones no negociables (de las ADRs)

- **LibStub**: `LibStub:NewLibrary("Craft-1.0", BUILD)` — BUILD es integer incremental
- **Lyra**: Base=Zinc, Accent=Emerald, `radiusBase = 0` — sin rounded corners, sin 9-slice TGA
- **Assets bundled**: Inter.ttf y atlas Lucide van en `Craft/media/` — sin addon companion externo
- **Sin TSTL**: no `.d.ts`, no TypeScript, no comentarios para TSTL
- **Sin portal web**: docs en GitHub, distribución en CurseForge/Wago
- **Anti-taint**: ningún componente puede contaminar Secure Frames de WoW

## Tokens del tema — referencia

Usar siempre vía `t.*` en `_applyTheme(t)`:

`t.background` `t.foreground` `t.primary` `t.primaryForeground`
`t.secondary` `t.muted` `t.mutedForeground` `t.border` `t.input`
`t.ring` `t.destructive` `t.card` `t.font` `t.fontBold`

## Comandos

```bash
luacheck Craft/ --config .luacheckrc   # lint — debe pasar sin warnings nuevos
busted tests/                           # tests unitarios headless
bash scripts/bump-build.sh              # incrementar CRAFT_BUILD antes de release
```

## Convenciones de código

- **Idioma del código**: inglés
- **Idioma de documentación y commits**: español
- **Commits**: Conventional Commits — `feat:`, `fix:`, `docs:`, `refactor:`, `test:`
- **No hacer push**: el maintainer (Alberto Gomez) hace push manualmente
- **Globals WoW**: declarar en `.luacheckrc`, no en el código

## Versioning

`MAJOR.MINOR.PATCH` (SemVer) en git tags + LibStub build number integer en `Craft.lua`.
Breaking change de API → `"Craft-2.0"` con BUILD=1.
Ver `docs/adr/0010-estrategia-versioning.md` para la tabla completa.
