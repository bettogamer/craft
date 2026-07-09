# ADR-0015: API de personalización para consumidores — overrides de color, fuentes runtime (LSM) y outline

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0015 |
| Título | API de personalización para addons consumidores — overrides de token, fuentes por path/LSM y font outline |
| Fecha | 09/07/2026 |
| Autor(es) | bettogamer |
| Estado | **Aceptada** (Fases 1–3 implementadas) |
| Alcance | `Craft.Theme`, `Presets.lua`, componentes con `SetFont` (Fase 3), docs de diseño |
| Relacionado | ADR-0014 (theming multi-eje), ADR-0005 (theming), ADR-0002 (Lyra), ADR-0012 (dark-only) |

---

### 1. Contexto

ADR-0014 dejó el theming como composición de ejes (`build{ style, base, accent, font, headingFont }`),
con presets built-in y las primitivas `use`/`extend`/`register_preset`. Eso cubre elegir entre las
paletas/fuentes **que Craft trae**, pero los addons consumidores quieren **personalizar más allá del
catálogo**:

1. **Temas custom con color propio** — el caso motivador es un addon que pinta su UI con el **color de
   la clase del personaje** (`RAID_CLASS_COLORS`). Hoy tendría que `extend()` y pisar `primary` +
   `sidebarPrimary` + foregrounds a mano, sabiendo qué tokens tocar.
2. **Fuentes de LibSharedMedia (LSM)** — usar cualquier fuente que el usuario tenga registrada (vía otros
   addons), no solo las bundleadas (Inter/Geist).
3. **Font outline** — contorno de texto (`OUTLINE`/`THICKOUTLINE`, flags de `SetFont`) para legibilidad
   sobre fondos variables (uso tipo HUD/overlay).

Objetivo: **dar palancas de personalización a los consumidores** sin romper el contrato de tokens ni la
independencia de Craft (no puede depender de LSM; ADR-0001/0012).

### 2. Decisión

Extender la API de theming en **3 fases** incrementales.

#### Fase 1 — Overrides de token (IMPLEMENTADA)

- **`build{ overrides = <tabla de tokens> }`**: `compose` fusiona `overrides` **al final**, pisando
  cualquier eje. Vía ergonómica y genérica para personalizar tokens sueltos.
- **`Craft.Theme.accentFrom(color[, fg])`**: helper **color-agnóstico** que genera la tabla de override
  de accent desde UN color (`primary` = `sidebarPrimary` = color; foregrounds con contraste por
  luminancia, o el `fg` dado). Craft **NO** conoce clases de WoW — el consumidor lee el color (p. ej.
  `RAID_CLASS_COLORS[class]`) y lo pasa:
  ```lua
  local _, class = UnitClass("player")
  local cc = RAID_CLASS_COLORS[class]
  Craft.Theme.use(Craft.Theme.build{
      base = "zinc",
      overrides = Craft.Theme.accentFrom({ r = cc.r, g = cc.g, b = cc.b }),
  })
  ```

**Decisión (owner): NO se integra un helper de color de clase en Craft.** La lib queda genérica; el
conocimiento WoW-específico (clases) vive en el consumidor.

#### Fase 2 — Fuentes por path / LSM (IMPLEMENTADA)

- `build{ font = { font=<path>, fontMedium=<path>, fontBold=<path> } }`: cualquier eje acepta una **tabla
  inline** además de un nombre del catálogo (el `pick` de `compose` devuelve la tabla tal cual si `name`
  es table). Sirve para body y heading (`headingFont = { fontHeading=<path> }`).
- `Craft.Theme.registerFont(name, paths)`: registra una familia en runtime en los ejes `font` **y**
  `headingFont` (aparece en `getAxisOptions` → UIs de selección). `medium/bold` caen a `font` si faltan.
- **Craft queda LSM-agnóstico**: el consumidor hace el puente `LSM:Fetch("font", name)` → path → Craft.
  No se vendorea ni se depende de LibSharedMedia.

#### Fase 3 — Font outline (IMPLEMENTADA)

- Token **`fontFlags`** en el eje Style (`""` | `"OUTLINE"` | `"THICKOUTLINE"` | `"MONOCHROME"`), **global**
  para todo el texto de la UI (decisión owner: no por-rol ni por-familia). Default `""` (sin contorno).
- Se **centralizó** la aplicación de fuente: `Craft.Theme.applyFont(fs, path, size)` aplica `fontFlags`; se
  migraron los **32** `SetFont` de los componentes a este helper (el probe interno de `Theme.lua` queda
  fuera). Pasa siempre el 3er arg (el `EditBox` lo requiere; el `FontString` lo acepta).
- **Divergencia deliberada de shadcn** (shadcn no tiene outline; su tipografía es familia+peso+tamaño):
  documentada en `design-reference.md §9`. El default (`""`) NO diverge; solo el opt-in del consumidor.

### 3. Alternativas consideradas

- **Helper de clase integrado** en Craft (`Theme.classAccent`): descartado — mete acoplamiento WoW-clases
  en una lib de theming que debe ser genérica. `accentFrom` genérico + el addon leyendo la clase cubre el
  caso sin ese acoplamiento.
- **Depender de/vendorear LSM**: descartado — rompe la independencia de Craft (ADR-0001/0012). Se expone
  fuentes por path y el consumidor bridgea LSM.
- **Outline por-rol o por-familia**: descartado por ahora — mayor complejidad; el caso HUD se cubre con un
  flag global.

### 4. Consecuencias

**Positivas:** los addons personalizan color y fuente sin forkear Craft ni conocer el set interno de
tokens; el caso "tema con color de clase" queda en 2 líneas; Craft sigue independiente (sin dep de LSM) y
fiel a shadcn salvo el outline (marcado como divergencia). `overrides` es no-invasivo (se fusiona al final;
sin overrides, `build` es idéntico al de ADR-0014 → sin regresión; gate `lyra-dark` intacto).

**Negativas / costos:** la Fase 3 (outline) toca ~43 sitios de `SetFont` → refactor a un applier central,
con riesgo y testing; es la razón del faseo. El outline añade una divergencia de shadcn a mantener.

### 5. Estado de implementación

- **Fase 1: HECHA** — `build{overrides}` en `compose` (`Presets.lua`), `Craft.Theme.accentFrom` (`Theme.lua`),
  demo en la página Theme del Browser, tests en `tests/theme_spec.lua`, doc en `docs/components/theme.md`.
- **Fase 2: HECHA** — `pick` acepta tabla inline (`Presets.lua`), `Craft.Theme.registerFont` (`Theme.lua`),
  tests + doc con ejemplo LSM.
- **Fase 3: HECHA** — token `fontFlags` (`Presets.lua` eje Style), `Craft.Theme.applyFont` (`Theme.lua`),
  32 `SetFont` migrados a `applyFont`, toggle demo en la página Theme del Browser, tests, divergencia §9.

### 6. Historial

| Rev | Fecha | Autor | Cambio |
|-----|-------|-------|--------|
| 1 | 09/07/2026 | bettogamer | Propuesta y aceptación; Fase 1 implementada; decisiones: API genérica (sin helper de clase), outline global, fuentes por path (LSM-agnóstico), faseo colores→fonts→outline |
| 2 | 09/07/2026 | bettogamer | Fase 2 implementada (tabla inline de paths + `registerFont`, LSM-agnóstico) |
| 3 | 09/07/2026 | bettogamer | Fase 3 implementada (token `fontFlags` global + `applyFont`, 32 `SetFont` migrados; divergencia §9) — ADR completo |
