# ADR-0014: Theming multi-eje — Style / Base / Theme / Font / Icons componibles y roadmap

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0014 |
| Título | Theming multi-eje — ejes componibles (Style/Base/Theme/Font/Icons) y roadmap de soporte |
| Fecha | 08/07/2026 |
| Autor(es) | bettogamer |
| Estado | **Aceptada** |
| Alcance | `Craft.Theme`, `Presets.lua`, docs de diseño, guardrails de estilo |
| Supersede | ADR-0002 (parcial): corrige Base Color y reencuadra el rol de Lyra y de la fuente |
| Relacionado | ADR-0002, ADR-0005 (theming), ADR-0003 (íconos), ADR-0012 (dark-only), RFC-002 (style Mira) |

---

### 1. Contexto

El MVP de Craft se implementó con **un único preset plano** (`lyra-dark`, ~60 tokens en
`Craft/theme/Presets.lua`). El sistema de theming (ADR-0005) ya soporta live-switching
(`Craft.Theme.use/register_preset/extend`) y se diseñó multi-preset desde el día 1, pero en la
práctica **todo el código y los docs quedaron asumidos en Lyra**, y el registro documental acumuló
deuda e inconsistencias durante la implementación del MVP.

El maintainer quiere que Craft evolucione hacia el modelo de ejes del create tool de shadcn
(`ui.shadcn.com/create`): poder cambiar **Base Color**, **Theme (accent)**, **Heading font** y
**Body font**; y más adelante el **Style** (p. ej. "Mira") y la **Icon Library**.

Este ADR **no implementa** nada de eso. Su propósito es (a) dejar registrada la razón por la que el
MVP arrancó con **Lyra dark**, (b) **corregir el registro canónico** de los ejes (que tenía gaps), y
(c) fijar el **modelo de ejes** y el **roadmap** de soporte, incluyendo qué queda prohibido y hasta
cuándo. La implementación de cada eje se hará en versiones posteriores, bajo este marco.

**Constraint permanente:** Craft es **dark-mode únicamente** (ADR-0005/ADR-0012). Ningún eje
reintroduce light mode.

---

### 2. Por qué el MVP arrancó con Lyra dark

shadcn v4 ofrece varios **styles** (la *forma* de los componentes: radius, densidad). De todos ellos,
**Lyra es el único con `radius: 0`** (esquinas 100% rectas) — confirmado en el CSS de origen
(`apps/v4/registry/styles/style-lyra.css` usa `rounded-none` en todo, sin variable `--radius`).

Esto es decisivo para WoW: **WoW no tiene una primitiva de rectángulo redondeado**. Los fondos se
pintan con `SetColorTexture` (rectángulos planos) y los bordes con 4 texturas de 1px. Cualquier style
con `radius > 0` (Vega/Nova/Maia/Mira) exigiría **construir primero una capa de renderizado de esquinas
redondeadas** (ver RFC-002) antes de poder shippear un solo componente.

Elegir **Lyra** permitió entregar el MVP directamente sobre los rectángulos nativos de WoW, sin esa
capa. La estética sharp/boxy además encaja con el paradigma visual del juego. Las decisiones del MVP en
los otros ejes fueron:

| Eje | Valor MVP | Nota |
|-----|-----------|------|
| **Style** (forma) | **Lyra** — `radius = 0` | Único style rounded-none de shadcn → renderizable en WoW nativo |
| **Base Color** | **Neutral** | Grises puros (C=0). Ver corrección en §4 |
| **Theme (accent)** | **Emerald** | `primary`, `sidebar-primary` |
| **Font** (body + heading) | **Inter** (Regular/Medium/Bold) | Eje independiente del Style — ver §4 |
| **Icon Library** | **Lucide** | Atlas `Craft/media/lucide.tga` (ADR-0003) |

---

### 3. Decisión — modelo de 5 ejes componibles

Craft adopta explícitamente el modelo de **ejes componibles** de shadcn. Un tema resuelto es la
composición de cinco ejes ortogonales:

1. **Style** (forma / radius / densidad). Es lo que define `style-<name>.css`. Lyra = `rounded-none`.
   **Congelado en Lyra** hasta un ADR futuro (ver §6). Es el único eje que puede tocar el renderizado
   de componentes.
2. **Base Color** (paleta de grises neutrales) → `background/foreground/card/popover/secondary/muted/
   accent/border/input/ring` + `sidebar*` neutrales.
3. **Theme / accent** → `primary/primaryForeground/sidebarPrimary/sidebarPrimaryForeground`.
4. **Font** — **body** y **heading** como familias separables. Hoy ambas = Inter; no existe aún un
   token de heading distinto (los títulos usan `fontMedium`).
5. **Icon Library** — Lucide hoy (atlas supersampleado). Eje futuro.

Los ejes 2–4 son **solo datos** (tablas de tokens / rutas de fuente). La infraestructura de theming ya
los soporta vía `register_preset`/`extend`; el trabajo de soporte "completo" es una **capa de
composición** que los combine sin explotar en presets N×M (ver §6).

---

### 4. Correcciones al registro canónico (supersede ADR-0002 parcialmente)

Durante el MVP el registro documental acumuló estos gaps, que este ADR resuelve como **verdad
canónica**:

- **Base Color = Neutral, NO Zinc.** ADR-0002 y AGENTS.md documentaban "Base=Zinc", pero la
  implementación real de `lyra-dark` usa **grises neutros** (`oklch(… 0 0)`, C=0). `design-reference.md`
  (header) y RFC-002 ya decían Neutral. → **Neutral** es el valor canónico; toda mención a "Zinc" como
  base es obsoleta.
- **La fuente NO es parte del Style Lyra.** `style-lyra.css` define **solo la forma** (`rounded-none`);
  **no** define fuente ni color. La fuente es un eje independiente del create tool. Por tanto, la
  elección de **Inter** por Craft es legítima y no contradice a Lyra (disuelve la duda "¿Lyra fuerza
  JetBrains Mono?": esa restricción, si existe, es un *default del create tool*, no parte del estilo).
- **`ring` es gris neutro** (`neutral-500` en dark), no emerald ni "zinc". Sutil por diseño.

ADR-0002 se conserva como registro histórico de la elección de Lyra en el MVP, con un puntero
"Superseded (parcial) por ADR-0014".

---

### 5. Alcance de ESTE ADR (solo documentación)

Este ADR **no cambia código**. En este pase:

- Se corrigen los docs (`design-reference.md`, `AGENTS.md`, comentarios de `Presets.lua`,
  `/update-design-tokens`, RFC-002) para reflejar la verdad canónica de §4 y este modelo.
- El token `radius` **sigue muerto** (ningún componente lo lee), `fontHeading` **no existe aún**, y no
  hay capa de composición ni de render redondeado. Todo eso es trabajo de versiones siguientes (§6).

---

### 6. Roadmap de soporte

#### 6.1 Próxima versión — ejes de color y tipografía (bajo riesgo, sin tocar la forma)

Implementar **Base Color + Theme (accent) + Body font + Heading font** intercambiables:

- **Capa de composición**: `Craft.Theme.build{ base, accent, font, headingFont }` que compone las capas
  de tokens en la tabla plana que los componentes ya consumen (extiende `extend()`). Evita presets N×M.
  **No requiere tocar componentes** para color.
- **Heading font**: nuevo token `fontHeading` (default = `fontMedium`, para no cambiar el look actual);
  los 4 componentes de título (Dialog, Window, Panel, Section) leen `t.fontHeading`.
- **Datos**: capas de Base Color (neutral + zinc/slate/stone/gray, variantes dark) y de accent
  (emerald + otros), generadas con el pipeline OKLCH→RGBA existente.
- **Bundling de fuentes**: cada familia adicional = ~1.2 MB de TTFs (3 pesos) en `media/` + verificar
  licencia (OFL). Costo real = tamaño de repo/consumidor, no código.
- **Rediseño de `/update-design-tokens`**: hoy está hardcodeado a un preset Lyra único. Debe
  **parametrizarse por eje** (generar la capa del base-color y la del accent por separado, aceptar la
  familia de fuente) en vez de actualizar un `lyra-dark` plano. Este rediseño es parte de esta fase.
- **Dark-only** siempre.

#### 6.2 Versión futura — Style (Mira) e Icon Library

- **Style axis (Mira, `radius > 0`)**: es el trabajo estructural pesado (capa de render de esquinas
  redondeadas). Requiere **su propio ADR** que supere el guardrail `radius = 0` (ver §7) + el refactor
  de chokepoint de renderizado que RFC-002 ya diseñó. **Fuera del alcance de la próxima versión.**
- **Icon Library axis**: swappable icon set. Futuro.

---

### 7. Guardrails (posición tras este ADR)

- **`radius > 0` sigue PROHIBIDO** hasta el ADR futuro del Style axis (§6.2). Lyra = `radius = 0`.
- **Light mode / `lyra-light` sigue PROHIBIDO** — dark-only permanente.
- Presets de **Style** no-Lyra siguen requiriendo ADR.
- Presets/capas de **Base Color, Theme y Font** pasan a ser ciudadanos de primera clase del sistema de
  theming (vía la capa de composición de §6.1) — dejan de ser "prohibidos por no ser Lyra".

---

### 8. Consecuencias

**Positivas:** el registro canónico queda consistente (Neutral, font-como-eje, ring neutro); el roadmap
de temas queda escrito y secuenciado por riesgo; la próxima versión es de bajo riesgo (dato + una capa,
sin tocar componentes); la investigación de shadcn queda capturada para no re-derivarla.

**Negativas / costos:** cada familia de fuente añade peso al bundle; el rediseño de
`/update-design-tokens` es trabajo real; el eje Style (Mira) sigue siendo un proyecto grande diferido.

**Neutras:** los componentes no cambian en esta fase; el token `radius` permanece como dato reservado
hasta el ADR de Style.

---

### 9. Plan de reversión

Este ADR es documental; revertir = restaurar los docs previos. No hay impacto de runtime. Si la capa de
composición (§6.1) resultara problemática al implementarse, se puede seguir usando `register_preset` con
presets planos como fallback (el modelo actual).

---

### 10. Referencias

- ADR-0002 (Lyra como fuente de verdad — superseded parcial), ADR-0005 (theming), ADR-0003 (Lucide),
  ADR-0012 (dark-only)
- RFC-002 (`docs/requests/RFC-002-mira-preset.md`) — style axis / radius, pre-ADR de §6.2
- `docs/design-reference.md` — tokens canónicos (§4 dark)
- `style-lyra.css`: `https://raw.githubusercontent.com/shadcn-ui/ui/main/apps/v4/registry/styles/style-lyra.css`
  (verificado: define solo forma, `rounded-none`, sin fuente ni color)

---

### 11. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 08/07/2026 | bettogamer | Propuesta y aceptación — modelo de 5 ejes, corrección Base=Neutral y font-como-eje, roadmap (próxima: color/font; futura: Style/Icons), supersede parcial de ADR-0002 |
