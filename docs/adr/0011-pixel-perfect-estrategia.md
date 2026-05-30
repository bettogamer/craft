# ADR-0011: Estrategia de pixel-perfect y conversión de escala

### Metadatos

| Campo | Valor |
|-------|-------|
| Número | 0011 |
| Título | Estrategia de pixel-perfect y conversión de escala |
| Fecha | 30/05/2026 |
| Autor(es) | Alberto Gomez |
| Estado | **Aceptada** |
| Alcance | `Craft/theme/Theme.lua` (helpers px/SetPixel*), todos los componentes con borders y drag |
| Stakeholders consultados | Lecciones del POC CraftUI (ADR-0012, ADR-0013, CraftTheme.lua) |

---

### 1. Contexto

WoW usa un sistema de coordenadas en **UI units**, no píxeles. `frame:SetSize(32, 32)` crea un frame de 32 UI units. Cuántos píxeles físicos equivale 1 UI unit depende de `UIParent:GetEffectiveScale()`:

- En WoW 1080p default: ~1.41 px/unit
- En pixel-perfect: 1.0 px/unit
- En 4K default: ~2.81 px/unit

Esto tiene tres implicaciones para Craft:

1. **Spacing/sizing**: los valores del design system (`h-8=32`, `gap=6`, etc.) son design pixels. Si los usamos directamente como UI units, los componentes se verán ligeramente más grandes o pequeños según el scale del usuario.

2. **Bordes de 1px**: `border:SetHeight(1)` crea un borde de 1 UI unit, no 1 píxel. A `scale=1.41` ese borde tiene 1.41 px y se ve borroso. A `scale=2.81` tiene 2.81 px (grosor de 3 píxeles). La solución es expresarlo en píxeles físicos: `1 / GetEffectiveScale()`.

3. **Posición del cursor**: `GetCursorPosition()` devuelve píxeles de render, no UI units. Para drag en Slider y Scroll es necesario dividir por `GetEffectiveScale()`.

El POC CraftUI resolvió esto con:
- `CraftTheme.SetPixelHeight/Width/Size()` con `PixelUtil` (Retail) o `math.max(n/scale, 0.5)` (Classic)
- Corrección de escala en dropdowns: `popup:SetScale(triggerEff / uiParentEff)`
- ADR-0013 (bug resuelto): sub-pixel border en nine-slice

Craft elimina nine-slice (Lyra `radius=0`), lo que elimina el problema ADR-0012/ADR-0013. Pero los bordes de 1px y el cursor siguen requiriendo manejo correcto.

---

### 2. Alternativas consideradas

| Alternativa | Pros | Contras |
|---|---|---|
| A. No hacer nada — usar UI units directamente para todo | Simplicidad máxima | Bordes borrosos y tamaños incorrectos en scales distintos de 1.0 |
| B. Forzar pixel-perfect como ElvUI (cambiar uiScale del usuario) | Nítido siempre | Inaceptable — Craft no debe modificar settings globales del usuario |
| C. Helpers `Craft.Theme.px()` + `SetPixelHeight/Width/Size()` con PixelUtil/fallback | Correcto para los elementos que lo necesitan; sin cambiar settings del usuario | Necesita 4 funciones adicionales en Theme |
| D. Solo PixelUtil, sin fallback | Simple | Rompe en Classic donde PixelUtil no existe |

---

### 3. Decisión

> **Alternativa C: helpers de escala en Craft.Theme para los casos que los necesitan, sin tocar settings del usuario.**

**Regla de tres categorías:**

1. **Spacing/sizing de componentes** (h-8=32, gap=6, etc.): usar el valor directamente como UI units. No convertir. Los componentes se verán proporcionalmente correctos en todos los scales aunque no sean pixel-perfect exactos.

2. **Elementos de exactamente 1px** (borders, separators, underlines): SIEMPRE usar `Craft.Theme.SetPixelHeight(frame, 1)` o `SetPixelWidth`. Estos usan `PixelUtil` en Retail o `math.max(1/scale, 0.5)` en Classic.

3. **Posición del cursor** (drag en Slider, Scroll): SIEMPRE dividir por `frame:GetEffectiveScale()`.

**Helpers en `Craft/theme/Theme.lua`:**
- `Craft.Theme.px(n, frame)` — n píxeles → UI units con clamp 0.5
- `Craft.Theme.SetPixelHeight(frame, n)` — PixelUtil o fallback
- `Craft.Theme.SetPixelWidth(frame, n)` — ídem
- `Craft.Theme.SetPixelSize(frame, w, h)` — ídem

**Corrección de escala en popups**: Select dropdown, Tooltip y cualquier popup posicionado relativo a UIParent desde un frame con escala propia usa `popup:SetScale(triggerEff / uiParentEff)`.

**Flex offsets**: redondear con `math.floor()` antes de `SetPoint` para evitar sub-pixel blending en layouts calculados.

---

### 4. Consecuencias

#### 4.1 Positivas

- Los bordes de 1px siempre se ven como 1px físico, independientemente del UI scale del usuario.
- Los componentes con drag (Slider, Scroll) funcionan correctamente en cualquier scale.
- Craft nunca toca el `uiScale` del usuario — sin efectos secundarios en el UI global del juego.
- El fallback clásico `math.max(n/scale, 0.5)` garantiza visibilidad mínima en Classic.
- `PixelUtil` en Retail da snapping nativo sin cálculo manual.

#### 4.2 Negativas / costos

- Los componentes no son pixel-perfect exactos para el 99% de usuarios que no tienen `GetEffectiveScale() == 1.0`. El spacing/sizing se ve ligeramente más grande o pequeño. Es el mismo comportamiento de cualquier web en monitores con distintos DPIs — aceptable.
- Los helpers añaden 4 funciones a `Craft.Theme`.
- Cada componente con border de 1px debe llamar `SetPixelHeight/Width` — requiere disciplina en la implementación.

#### 4.3 Neutras / observables

- `Craft.Theme.isPixelPerfect()` está disponible para que los addons que lo necesiten detecten el estado.
- Craft no forma opinión sobre si el usuario debe o no usar pixel-perfect — eso es decisión del usuario/addon.

---

### 5. Impacto en el sistema

- **`Craft/theme/Theme.lua`**: 4 helpers nuevos (`px`, `SetPixelHeight`, `SetPixelWidth`, `SetPixelSize`).
- **Todos los componentes con border**: llamar `Craft.Theme.SetPixelHeight/Width` en lugar de `SetHeight/Width(1)`.
- **`Craft/layout/Flex.lua`**: `math.floor()` en offsetX/offsetY antes de `SetPoint`.
- **Select, Tooltip**: corrección de escala en popup.
- **Slider, Scroll**: cursor position `/frame:GetEffectiveScale()`.
- **Documentación**: `docs/pixel-perfect.md` como referencia de implementación.

---

### 6. Plan de reversión

- **Señales de problema**: los helpers causan artefactos visuales en algunos casos edge; o PixelUtil cambia su API en un patch de WoW.
- **Costo de revertir**: bajo — los helpers son aislados en Theme.lua. Reemplazar con valores directos no rompe la API de los componentes.

---

### 7. Validación

- **Border de 1px**: en WoW 1080p default (scale ~1.41) el borde de Input y Panel se ve como 1 píxel nítido (no 2 píxeles o borroso).
- **Drag en Slider**: arrastrar el thumb funciona correctamente en Craft_Browser (que corre a 0.75x scale).
- **Select dropdown**: el dropdown aparece sin distorsión de escala cuando el frame padre tiene scale distinto de 1.

---

### 8. Referencias

- `CraftUI/docs/wow-units.md` — documentación exhaustiva del sistema WoW
- `CraftUI/src/components/CraftTheme.lua` — implementación de referencia de los helpers
- `CraftUI/docs/adr/0013-bug-nine-slice-top-border-subpixel.md` — bug de sub-pixel resuelto en el POC
- `docs/pixel-perfect.md` — guía de implementación para Craft
- WoW PixelUtil API: nativa en Retail Dragonflight+

---

### 9. Historial

| Versión | Fecha | Autor | Cambio |
|---------|-------|-------|--------|
| 1 | 30/05/2026 | Alberto Gomez | Propuesta inicial |
| 2 | 30/05/2026 | Alberto Gomez | Aceptada — estrategia de tres categorías documentada |
