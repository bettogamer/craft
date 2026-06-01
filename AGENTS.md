# AGENTS.md — Craft

> README para agentes de IA. Leer antes de cualquier tarea. Sincronizado con `docs/DTI_v0.1.md`.

---

## 1. Identidad del producto

- **Nombre**: Craft
- **Dominio**: WoW Addon Development — librería de componentes UI
- **Resumen**: librería open source de componentes UI para addons de World of Warcraft. Librería embebible — developers descargan `Craft.zip` de GitHub Releases y lo colocan en `libs/` de su addon. Craft_Browser es el único addon en CurseForge/Wago. Diseño basado en shadcn Lyra (Zinc + Emerald, Radius=0) con íconos Lucide y fuente Inter bundled en `Craft/media/`. **Dark mode únicamente** — WoW addon dev es dark-mode exclusivo. Ver ADR-0012.
- **DTI**: `docs/DTI_v0.1.md`
- **FSD**: `docs/FSD_v0.1.md`
- **BRD**: `docs/BRD_v0.1.md`
- **ADRs**: `docs/adr/` — leer todos antes de tomar decisiones arquitectónicas

---

## 2. Contexto que el agente MUST leer antes de actuar

En orden:

1. **Este archivo completo** (AGENTS.md).
2. `docs/adr/` — las 12 ADRs definen todas las decisiones no negociables.
3. `docs/FSD_v0.1.md` §4 y §5 — casos de uso y contrato de componente.
4. `docs/DTI_v0.1.md` §3 y §5 — arquitectura de módulos y patrón de componente.
5. `docs/design-reference.md` — fuente de verdad de tokens de color (CSS exacto de shadcn Lyra).
6. `docs/pixel-perfect.md` — reglas de escala WoW (ADR-0011).

Si la tarea toca un componente específico: leer también `docs/components/<nombre>.md`.

---

## 3. Estructura del repositorio

```
/
├── AGENTS.md               ← este archivo
├── CLAUDE.md               ← instrucciones para Claude Code
├── CHANGELOG.md
├── .gitignore
├── .luacheckrc             ← linter Lua con globals WoW
├── .pkgmeta                ← bigwigsmods/packager config
├── .github/workflows/
│   ├── ci.yml              ← lint + test en cada push/PR
│   └── release.yml         ← package + upload en tags v*
├── .claude/commands/
│   ├── check-traceability.md   ← /check-traceability
│   └── update-design-tokens.md ← /update-design-tokens
│
├── Craft/                  ← LA LIBRERÍA (lo que se distribuye)
│   ├── Craft.toc
│   ├── Craft.lua           ← entry point, LibStub:NewLibrary("Craft-1.0", BUILD)
│   ├── libs/LibStub/LibStub.lua  ← para desarrollo standalone
│   ├── theme/
│   │   ├── Theme.lua       ← Craft.Theme (register, use, get, extend)
│   │   └── Presets.lua     ← lyra-dark (único preset built-in, dark mode solo)
│   ├── layout/Flex.lua     ← Craft.Flex (motor CSS Flexbox en Lua)
│   ├── icons/
│   │   ├── Icons.lua       ← Craft.Icons.Get/Apply/Has/List
│   │   └── Atlas.lua       ← coordenadas UV del atlas TGA
│   ├── components/         ← 13 componentes UI + 3 módulos = 16 MVP
│   │   ├── Button.lua      ├── Checkbox.lua  ├── Dialog.lua
│   │   ├── Input.lua       ├── Label.lua     ├── Panel.lua
│   │   ├── Scroll.lua      ├── Select.lua    ├── Separator.lua
│   │   ├── Sidebar.lua     ├── Slider.lua    ├── Tabs.lua
│   │   └── Tooltip.lua     (Icons, Flex, Theme son módulos en sus propias carpetas)
│   └── media/              ← assets bundled
│       ├── Inter-Regular.ttf
│       ├── Inter-Bold.ttf
│       ├── lucide-16.tga
│       └── lucide-24.tga
│
├── Craft_Browser/          ← addon showcase in-game ✅
│   ├── Craft_Browser.toc
│   ├── Browser.lua
│   └── pages/              ← 16 páginas de demo
├── tests/                  ← unit tests con busted + mock WoW API
│   ├── mock_wow.lua        ← WoW API mock (no es test, no ejecutar directo)
│   └── test_button.lua
├── scripts/
│   ├── export-icons.py     ← genera lucide-*.tga
│   └── bump-build.sh       ← incrementa CRAFT_BUILD en Craft.lua
│
└── docs/
    ├── design-reference.md ← FUENTE DE VERDAD de tokens de color (CSS shadcn Lyra)
    ├── pixel-perfect.md    ← reglas de escala WoW (ADR-0011)
    ├── BRD_v0.1.md  ├── MRD_v0.1.md  ├── PRD_v0.1.md
    ├── FSD_v0.1.md  └── DTI_v0.1.md
    ├── components/         ← spec de cada componente
    └── adr/
        ├── 0001-arquitectura-libreria-libstub.md
        ├── 0002-sistema-diseno-shadcn-lyra.md
        ├── 0003-iconos-lucide-first-class.md
        ├── 0004-craft-browser-showcase.md
        ├── 0005-sistema-de-theming.md
        ├── 0006-craft-flex-motor-layout.md
        ├── 0007-exclusion-tstl.md
        ├── 0008-exclusion-portal-web.md
        ├── 0009-pipeline-ci-cd.md
        ├── 0010-estrategia-versioning.md
        ├── 0011-pixel-perfect-estrategia.md
        └── 0012-craft-libreria-embebible.md
```

### Modelo de branches

```
main          ← producción — siempre estable, protegida (requiere PR + CI verde)
dev           ← integración — recibe features, genera dev builds automáticos
feat/*        ← features nuevas → PR hacia dev
hotfix/*      ← fixes críticos → PR hacia main + backport a dev
```

**Flujo normal:**
```
feat/mi-feature → PR → dev → (build automático) → PR → main → tag v1.x.x → CurseForge
```

**Flujo hotfix:**
```
hotfix/fix-critico → PR → main → tag v1.0.x → CurseForge
                          ↘ PR → dev (backport obligatorio)
```

**CI por branch:**
| Branch/evento | ci.yml | package.yml | release.yml |
|---|---|---|---|
| push `dev` | ✅ lint+test | ✅ .zip artefacto | — |
| push `main` | ✅ lint+test | ✅ .zip artefacto | — |
| PR → `main` | ✅ lint+test | — | — |
| tag `v*` | — | — | ✅ CurseForge+Wago |

El agente **MUST NOT** hacer push ni crear PRs — el maintainer (Alberto Gomez) lo hace manualmente.

---

## 4. Stack tecnológico autoritativo

| Capa | Tecnología | Notas |
|------|------------|-------|
| Lenguaje | Lua 5.1 | WoW sandbox — sin librerías externas |
| Librería compartida | LibStub | `LibStub:NewLibrary("Craft-1.0", BUILD)` |
| Diseño | shadcn Lyra dark | Base=Zinc, Theme=Emerald, Radius=0. Ver ADR-0002 |
| Íconos | Lucide (atlas TGA bundled) | Ver ADR-0003 |
| Fuente | Inter (TTF bundled) | `Craft/media/Inter-Regular.ttf` |
| Linter | luacheck | `.luacheckrc` con globals WoW |
| Tests | busted | Headless con `tests/mock_wow.lua` |
| Packaging | bigwigsmods/packager | ADR-0009 |
| CI | GitHub Actions | `ci.yml` + `package.yml` (push) + `release.yml` (tags v*) |
| Distribución | GitHub Releases (Craft.zip) + CurseForge/Wago (Craft_Browser) | ADR-0012: Craft es embebible, solo Craft_Browser en CurseForge |

**MUST NOT** introducir dependencias fuera de este stack sin ADR aprobado.

---

## 5. Contrato de componente — regla de dominio más crítica

Todo componente Craft **MUST** implementar este contrato exacto:

```lua
local MyComponent = {}
MyComponent.__index = MyComponent

function MyComponent:Create(parent, config)
  local self = setmetatable({}, MyComponent)
  -- crear frames WoW aquí
  self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
  self:_applyTheme(Craft.Theme.get())
  return self
end

function MyComponent:_applyTheme(t)
  -- SOLO usar t.* — NUNCA llamar Craft.Theme.get() aquí (re-entrancia)
  -- NUNCA hardcodear colores RGBA
end

function MyComponent:Destroy()
  Craft.Theme.unregister(self._themeHandle)  -- CRÍTICO: evita memory leak
  self.frame:Hide()
  self.frame = nil
end
```

**Violaciones MUST NOT:**
- Llamar `Craft.Theme.get()` dentro de `_applyTheme()` → re-entrancia.
- Omitir `unregister()` en `Destroy()` → memory leak de listeners.
- Hardcodear colores RGBA → siempre usar `t.*`.
- Usar `radius > 0` → Lyra usa Radius=0, `SetColorTexture()` es suficiente.
- Crear focus rings → WoW es mouse-only, sin navegación por teclado.

---

## 6. Reglas de dominio invariantes

- **MUST**: todo componente implementa el contrato §5 completo.
- **MUST**: los valores visuales de un componente (tamaños, paddings, colores, variantes) se derivan **exclusivamente** de `docs/components/<nombre>.md` y `docs/design-reference.md`. Nunca usar conocimiento de entrenamiento sobre shadcn, Tailwind o Lyra como fuente — ese conocimiento puede estar desactualizado o ser incorrecto. Si un valor no está en los docs, ejecutar `/update-design-tokens` o preguntar al maintainer antes de asumir.
- **MUST**: `CRAFT_BUILD` se incrementa antes de cada release (`scripts/bump-build.sh`).
- **MUST**: colores desde tokens semánticos del tema, nunca hardcodeados.
- **MUST**: usar `Craft.Icons.Apply(tex, name)` para íconos — nunca rutas TGA directas.
- **MUST**: usar `Craft.Theme.getFont()` para fuentes — nunca rutas TTF directas.
- **MUST**: elementos de 1px (bordes, separadores, underlines) usar `Craft.Theme.SetPixelHeight/Width(frame, 1)` — nunca `SetHeight(1)` directo (ADR-0011).
- **MUST**: posición del cursor en drag usar `GetCursorPosition() / frame:GetEffectiveScale()` (ADR-0011).
- **MUST NOT**: contaminar Secure Frames (anti-taint) — verificar con `Blizzard_DebugTools`.
- **MUST NOT**: globales Lua no declaradas en `.luacheckrc`.
- **MUST NOT**: soporte TypeScriptToLua — rechazar PRs con `.d.ts` (ADR-0007).
- **MUST NOT**: addon companion para assets — todo en `Craft/media/` (ADR-0003).
- **MUST NOT**: `radius > 0` — Lyra usa Radius=0 (ADR-0002).
- **MUST NOT**: modificar ADRs aceptados — crear un nuevo ADR que los superede.
- **MUST NOT**: crear `lyra-light` ni ningún preset de tema claro — WoW es dark-mode exclusivo.

---

## 7. Seguridad y restricciones del sandbox WoW

- **Sin filesystem**: `io.*` no existe en WoW.
- **Sin red**: `socket.*`, `http.*` no existen.
- **Sin `os.time()`**: usar `GetTime()` de WoW.
- **Globales**: evitar — todo en `Craft.*`. Los globales contaminan el entorno WoW.
- **Mouse-only**: WoW addon UI es exclusivamente mouse. No implementar focus rings por teclado ni navegación por Tab. Los rings de Input (EditBox) sí aplican — son activados por click (OnEditFocusGained), no por teclado.

---

## 8. Guardrails del agente

### Sin aprobación:
- Leer cualquier archivo.
- Implementar un componente siguiendo §5.
- Agregar/modificar tests.
- Corregir bugs (PATCH, sin cambio de API).
- Actualizar `CHANGELOG.md`.

### Requiere aprobación del maintainer:
- Cambiar API pública de un componente.
- Agregar componente nuevo (requiere `.toc`, tests, docs, ADR si aplica).
- Cambiar `Craft/theme/Presets.lua` (tokens de color).
- Cambiar `.github/workflows/`.
- Breaking change de API (MAJOR → `"Craft-2.0"`, `BUILD=1`).

### MUST NOT sin excepción:
- `git push` — el maintainer pushea manualmente.
- Modificar ADRs aceptados.
- `require()` de módulos externos al sandbox WoW.
- Archivos `.d.ts` o artefactos TSTL.
- Directorio `Craft_SharedMedia/`.
- Preset `lyra-light` u otro tema claro.

---

## 9. Errores comunes — lecciones de testing en WoW real

Estos bugs se cometieron durante desarrollo y se corrigieron tras testing en WoW. Documentados para evitar repetirlos.

### WoW API — comportamientos no obvios

**`GetCursorPosition()` devuelve `x, y` — siempre usar `select(2, ...)`**
```lua
-- MAL: divide solo por x (primer retorno)
local y = GetCursorPosition() / frame:GetEffectiveScale()

-- BIEN: extraer y explícitamente
local y = select(2, GetCursorPosition()) / frame:GetEffectiveScale()
```
Afecta: Slider drag, Scroll thumb drag, Sidebar scrollbar drag. En todos los componentes con drag vertical.

**`EditBox` tiene margen interno propio — usar `SetTextInsets`**
WoW `EditBox` aplica padding interno que NO se puede eliminar solo con `SetPoint`. El texto y cursor aparecen más a la derecha de lo esperado. Solución: posicionar el EditBox cubriendo el área completa y controlar el texto con `SetTextInsets(left, right, 0, 0)`.
```lua
self._edit:SetPoint("TOPLEFT",     self.frame, "TOPLEFT",     0, -PAD_V)
self._edit:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0,  PAD_V)
self._edit:SetTextInsets(self:_leftPad(), self:_rightPad(), 0, 0)
```

**`FontString:SetText()` antes de `SetFont()` → error en WoW**
Si un componente llama `SetText` en `Create()` ANTES de que `_applyTheme()` haya ejecutado `SetFont`, WoW lanza error silencioso y el texto no aparece. El patrón correcto:
```lua
self._themeHandle = Craft.Theme.register(function(t) self:_applyTheme(t) end)
self:_applyTheme(Craft.Theme.get())  -- SetFont ocurre aquí
self._label:SetText(self._cfg.text)  -- SetText DESPUÉS de SetFont
```
Afecta: Label, Button, Checkbox, Dialog, Input placeholder. Aplicar en cualquier componente que tenga FontStrings con texto inicial.

**FontString sin `RIGHT` anchor → ancho 0, texto invisible**
Un FontString con solo `TOPLEFT` tiene ancho 0. El texto se clipea a invisible. Siempre añadir anchor derecho o llamar `SetWidth()`:
```lua
label:SetPoint("TOPLEFT",  parent, "TOPLEFT",  16, -y)
label:SetPoint("RIGHT",    parent, "RIGHT",    -16, 0)  -- OBLIGATORIO
label:SetHeight(14)
```

**Frame hijo con height=0 clipea sus FontStrings a invisible**
Si un Frame contenedor (e.g. `_header` en Panel) no tiene altura definida, WoW clipea todos sus children a 0 — incluidos FontStrings. Siempre dar `SetHeight()` explícito o BOTTOM anchor a frames que contienen texto.

**`frame:EnableMouse(true)` es obligatorio para bloquear eventos**
Un frame con fondo visible NO bloquea clics/hover por defecto. Sin `EnableMouse(true)`, los eventos pasan al juego debajo. Aplicar en el frame raíz de cualquier ventana o panel que actúe como superficie interactiva.

### Craft.Flex — comportamientos a respetar

**`basis="auto"` + `OnSizeChanged` → encogimiento acumulativo**
Si `Layout()` se llama múltiples veces (e.g. durante resize de ventana), `basis="auto"` lee el ancho actual del frame — que ya fue modificado por el `Layout()` anterior. Resultado: cada llamada encoge los items más. La solución es capturar `_naturalBasis` en `Add()`. Ver `docs/components/flex.md` §Notas.

**Button en Flex con `grow=1` colapsa en hover**
`_applyTheme` de Button llama `_recalcWidth()` que llama `frame:SetWidth(textWidth)`, sobreescribiendo el ancho que Flex asignó. La guarda `_intrinsicWidth` evita esto. Ver `docs/components/button.md` §Notas.

**Containers Flex deben tener solo anchors TOP, no BOTTOM**
Para páginas con scroll, anclar el contenedor con `TOPLEFT + TOPRIGHT` (sin BOTTOM) y dejar que el contenido crezca hacia abajo. Un anchor BOTTOM limitaría la altura y causaría que el contenido se clipee.

### Craft.mediaPath — rutas de assets

**Nunca hardcodear rutas a `Craft/media/`**
Usar siempre `Craft.mediaPath` que detecta si Craft es standalone o embedded:
```lua
-- MAL:
local font = "Interface\\AddOns\\Craft\\media\\Inter-Regular.ttf"

-- BIEN:
local font = Craft.mediaPath .. "Inter-Regular.ttf"
```
Ver ADR-0012 §6 para el mecanismo de detección.

### Destroy() — guarda contra double-free

**Todos los `Destroy()` deben tener guarda `if not self.frame then return end`**
Los componentes pueden ser destruidos más de una vez si las páginas de Craft_Browser navegan entre ellas. Sin la guarda, el segundo `Destroy()` hace nil de un frame ya nil y puede causar errores. El patrón:
```lua
function MyComponent:Destroy()
    if not self.frame then return end   -- guarda OBLIGATORIA
    Craft.Theme.unregister(self._themeHandle)
    self.frame:Hide()
    self.frame = nil
end
```

---

## 10. Flujo de trabajo estándar

```mermaid
flowchart TD
  A[Recibir tarea] --> B[Leer AGENTS.md + ADRs relevantes]
  B --> C[Leer docs/components/<nombre>.md si aplica]
  C --> D[Implementar siguiendo contrato §5]
  D --> E[luacheck Craft/ — sin warnings nuevos]
  E --> F[busted tests/ — todos verdes]
  F --> G{¿Tarea completa?}
  G -- no --> D
  G -- sí --> H[Reportar cambios al maintainer]
```

---

## 10. Comandos de verificación y slash commands

```bash
# Lint — MUST pasar sin warnings nuevos
luacheck Craft/ --config .luacheckrc

# Tests unitarios headless
busted tests/

# Generar atlas TGA de Lucide (requiere Python + Pillow)
python3 scripts/export-icons.py

# Incrementar LibStub build antes de release
bash scripts/bump-build.sh
```

**Slash commands de Claude Code** (invocar con `/nombre`):

| Comando | Descripción |
|---------|-------------|
| `/check-traceability` | Revisa la cadena BRD→MRD→PRD→FSD e identifica gaps |
| `/update-design-tokens` | Actualiza tokens desde CSS de shadcn y revisa layouts de componentes |

---

## 11. Tokens de diseño — referencia rápida

Todos los componentes usan `t.*` en `_applyTheme(t)`. **Fuente de verdad**: `docs/design-reference.md`.

### Colores core

| Token | Tipo | Uso |
|-------|------|-----|
| `t.background` | RGBA | Fondo de Panel, Dialog, Scroll |
| `t.foreground` | RGBA | Texto principal |
| `t.card` / `t.cardForeground` | RGBA | Fondo/texto de cards anidadas |
| `t.popover` / `t.popoverForeground` | RGBA | Fondo/texto de tooltips y dropdowns |
| `t.primary` / `t.primaryForeground` | RGBA | Emerald-800 — botones default, active states |
| `t.secondary` / `t.secondaryForeground` | RGBA | Botones secundarios, tab list bg |
| `t.muted` / `t.mutedForeground` | RGBA | `muted` = fondo apagado; `mutedForeground` = texto placeholder, labels disabled |
| `t.accent` / `t.accentForeground` | RGBA | Hover de ghost/outline buttons, tab hover |
| `t.destructive` / `t.destructiveForeground` | RGBA | `destructive/20` bg + `destructive` text (Lyra — tinte, no sólido). `destructiveForeground` = blanco puro |
| `t.border` | RGBA | Bordes de componentes (blanco a=0.1 en dark) |
| `t.input` | RGBA | Fondo de Input/Select trigger (blanco a=0.15 en dark) |
| `t.ring` | RGBA | **Zinc** (gris) — NO primary. Solo Input ring en OnEditFocusGained (mouse click, no teclado) |

### Tokens Sidebar (exclusivos de `Craft.Sidebar`)

| Token | Uso |
|-------|-----|
| `t.sidebar` | Fondo del sidebar |
| `t.sidebarForeground` | Texto de items |
| `t.sidebarPrimary` / `t.sidebarPrimaryForeground` | Emerald-500 — disponible pero NO se usa en active state |
| `t.sidebarAccent` / `t.sidebarAccentForeground` | **Active y hover** de items (no sidebarPrimary) |
| `t.sidebarBorder` | Borde derecho del sidebar |

### Tipografía y spacing

| Token | Valor | Nota |
|-------|-------|------|
| `t.font` | ruta Inter-Regular | Siempre via `Craft.Theme.getFont()` |
| `t.fontBold` | ruta Inter-Bold | Idem |
| `t.fontSize` | 12 | `text-xs` Lyra — base de todos los componentes |
| `t.fontSizeLg` | 14 | `text-sm` Lyra — títulos de Card y Dialog |
| `t.fontSizeSm` | 11 | Adaptación Craft (no existe en Lyra CSS) |
| `t.spacingXs/Sm/Md/Lg/Xl` | 4/8/12/16/24 px | UI units directos |
| `t.borderWidth` | 1 | Usar con `Craft.Theme.SetPixelHeight/Width` |
| `t.radius` | 0 | **Sin border radius** — Lyra usa Radius=0 |
| `t.iconSizeSm` / `t.iconSizeMd` | 16 / 24 | Atlas lucide-16 / lucide-24 |

> **`t.ring` es zinc (gris), NO emerald/primary.** Ring en WoW solo aplica para Input EditBox (OnEditFocusGained via click), no por navegación de teclado.

---

## 12. Versioning — referencia rápida

| Tipo de cambio | Acción |
|---|---|
| Bug fix (sin cambio de API) | `PATCH` → `v1.0.1`, incrementar `CRAFT_BUILD` |
| Nuevo componente o feature | `MINOR` → `v1.1.0`, incrementar `CRAFT_BUILD` |
| Breaking change de API | `MAJOR` → `v2.0.0`, LibStub `"Craft-2.0"`, `CRAFT_BUILD = 1` |

`CRAFT_BUILD` en `Craft.lua` es un integer siempre creciente. Usar `scripts/bump-build.sh`.

---

## 13. Contacto

- **Maintainer**: Alberto Gomez
- **Repositorio**: `github.com/bettogamer/craft`
- **Canal comunidad**: Discord addon-dev WoW

---

## 14. Registro de cambios

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| v0.1 | 30/05/2026 | Alberto Gomez | Versión inicial |
| v0.2 | 30/05/2026 | Alberto Gomez | ADR-0011 pixel-perfect; 11 ADRs; slash commands; token ring corregido (zinc, no primary); lyra-light eliminado; tabla de tokens completa; regla pixel-perfect en §6; WoW mouse-only en §7 |
