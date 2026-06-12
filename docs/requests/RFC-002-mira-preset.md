# RFC-002 — Soporte para nuevos presets (color + style): caso "mira-dark"

**Reportado por:** Alberto (maintainer)
**Área:** `Craft/theme/` + capa de renderizado de fondos en componentes
**Tipo:** Investigación / RFC (pre-ADR)
**Estado:** 🔬 Investigación documentada — pendiente de decisión de maintainer + ADR
**Fecha:** 2026-06-09

---

## Objetivo

Hoy Craft soporta un único preset built-in: `lyra-dark`. Se quiere evaluar cómo
soportar un nuevo preset, conceptualizado como **"mira dark"** (paleta + estilo
visto en `ui.shadcn.com/create`).

---

## Hallazgo central: "color" y "style" son DOS ejes distintos

Según [design-reference.md §1](../design-reference.md), **Lyra no es un tema de color
— es un *estilo de componente* (la forma)**. El panel de `ui.shadcn.com/create`
separa los ejes:

| Eje | Lyra (actual) | Mira (objetivo) |
|-----|---------------|-----------------|
| **Style** (forma) | Lyra → `Radius: 0`, sharp/boxy | Mira → `Radius: Small` (esquinas redondeadas) |
| **Base Color** | Neutral | Neutral |
| **Theme Color** | Emerald | Emerald |

Esto divide el trabajo en dos problemas con coste radicalmente distinto.

---

## Eje 1 — Nuevo preset de COLOR → ya soportado (trivial)

La infraestructura completa ya existe. Un preset de color es **solo datos**:
una tabla de tokens `{r,g,b,a}`.

- `Craft.Theme.register_preset(name, tbl)` — [Theme.lua:126](../../Craft/theme/Theme.lua#L126)
- `Craft.Theme.use("mi-preset")` — cambia activo + notifica listeners → live-switch OK ([Theme.lua:49](../../Craft/theme/Theme.lua#L49))
- `Craft.Theme.extend("lyra-dark", { primary = {...} })` — deriva variantes cambiando solo unos tokens ([Theme.lua:106](../../Craft/theme/Theme.lua#L106))
- Los ~107 `SetColorTexture` de los 12 componentes leen tokens semánticos, no colores hardcoded.

**Conclusión:** si "mira dark" fuera solo otra paleta (otro Base/Theme color
manteniendo `Radius=0`), se añade hoy sin tocar ningún componente. Cero riesgo.
Sería una nueva entrada en [Presets.lua](../../Craft/theme/Presets.lua) o un `register_preset()`.

---

## Eje 2 — El estilo Mira de verdad (Radius>0) → ahí está el trabajo real

El rasgo que define a Mira frente a Lyra es **esquinas redondeadas**. Choca con
todo el diseño actual:

1. **`radius` es dato muerto hoy.** Existe en [Presets.lua:58](../../Craft/theme/Presets.lua#L58)
   (`radius = 0`) pero **ningún componente lo lee**. No hay un solo punto donde se aplique.
2. **No hay capa de renderizado de fondos.** Cada componente llama
   `tex:SetColorTexture(...)` directamente (~107 sitios) → siempre rectángulo plano
   y nítido. `SetColorTexture` no sabe redondear.
3. **Prohibido por guardrails.** [AGENTS.md:210](../../AGENTS.md) dice explícitamente
   *MUST NOT `radius > 0`* y *MUST NOT crear presets no-lyra* sin aprobación;
   ADR-0002 fija Lyra como fuente de verdad. → Decisión de maintainer + nuevo ADR,
   **no** tarea de `component-builder`.

### Opciones de renderizado de esquinas redondeadas en WoW

WoW no tiene `border-radius`. Opciones reales:

- **A) `MaskTexture`** — máscara con esquinas redondeadas aplicada al `_bg`.
  Una máscara por nivel de radio. Lo más limpio para look moderno. **(preferida)**
- **B) 9-slice / `BackdropTemplate`** — bordes/esquinas como TGAs. Más pesado,
  look más tosco, multiplica texturas por componente.
- **C) Texturas compuestas** (centro + 4 esquinas) por componente. Mucho boilerplate.

### Prerequisito arquitectónico (independiente de la opción)

Hoy es imposible honrar `radius` porque **no hay chokepoint**. Antes de cualquier
Mira hay que **centralizar el renderizado de fondos**: introducir un helper

```lua
Craft.Theme.applyFill(tex, colorToken, t)   -- lee t.radius internamente
```

y migrar los ~107 `SetColorTexture` a pasar por él. Así el radio se honra en
**un único sitio** y añadir presets de *estilo* se vuelve barato y repetible
(no solo Mira).

---

## Recomendación / plan propuesto

1. **Definir qué es "mira dark" realmente:**
   - ¿Paleta nueva? → preset de color, disponible hoy (Eje 1).
   - ¿Estilo Mira con esquinas redondeadas? → proyecto con ADR (Eje 2).
2. **Si se quieren rounded corners:**
   - Paso 1: refactor de centralización (`Theme.applyFill`).
   - Paso 2: `MaskTexture` parametrizado por `radius`.
3. **Convención de nombres:** mantener `<style>-<mode>` (`lyra-dark`, `mira-dark`);
   tratar el color como eje componible vía `extend()`, no `mira-neutral-emerald-dark`.
4. **Gobernanza:** abrir ADR que extienda/supere ADR-0002 y relaje el guardrail
   `radius=0`, antes de tocar componentes.

---

## Archivos clave (para retomar)

- [Craft/theme/Presets.lua](../../Craft/theme/Presets.lua) — preset `lyra-dark`, token `radius`
- [Craft/theme/Theme.lua](../../Craft/theme/Theme.lua) — `use/get/extend/register_preset`
- [docs/design-reference.md](../design-reference.md) — §1 (Lyra = estilo, no color), CSS fuente
- [docs/adr/0002-sistema-diseno-shadcn-lyra.md](../adr/0002-sistema-diseno-shadcn-lyra.md) — ADR a extender
- [AGENTS.md](../../AGENTS.md) — guardrails `radius=0` (línea ~210)
- Componentes con `SetColorTexture` directo: Button(18), Tabs(15), Sidebar(14),
  Select(12), Slider(11), Input(10), Checkbox(7), Scroll(6), Dialog(8),
  Panel(3), Tooltip(2), Separator(1)
