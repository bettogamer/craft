# FR-055 — `Craft.Checkbox`: hit-area expandida (inset negativo, Lyra parity)

**Reportado por:** Auditoría de fidelidad vs markup Lyra real, ejemplo "Notifications" (Card + FieldGroup de checkbox-fields), 2026-07-20
**Componente:** `Craft/components/Checkbox.lua` (área interactiva del frame)
**Tipo:** Usabilidad (target size pequeño vs Lyra)
**Prioridad:** Media (tolerancia de clic real perdida, especialmente en checkboxes standalone)
**Estado:** ✅ Implementado (dev, 2026-07-20) — **Opción C**: `SetHitRectInsets(-12, -12, -8, -8)` sobre `self.frame`. Ni A (frame hitbox hijo) ni B (expandir el frame): WoW tiene el primitivo nativo exacto, y a diferencia de A/B queda FUERA del flujo de layout (no toca `GetWidth`/`GetHeight`), igual que el pseudo-elemento CSS. **Verificado in-game (2026-07-20)** — el clic fuera del box visual togglea. Cerrado

---

## Problema

Lyra expande el área de click del checkbox más allá del box visual de 16×16px mediante un pseudo-elemento `::after` con inset negativo. El markup real especifica `after:absolute after:-inset-x-3 after:-inset-y-2`, dando un target físico real de **~40×32px** (box 16px + 12px horiz por lado + 8px vert por lado). Craft usa el box exacto sin expansión, lo que reduce la tolerancia de clic en un ~60% respecto a Lyra.

**Evidencia:**

- **Markup Lyra real (ejemplo "Notifications"):**
  - Clase `after:absolute after:-inset-x-3 after:-inset-y-2` presente en todos los estados del checkbox (checked, unchecked, indeterminate)

- **CSS Lyra real (extraído de `shadcn-pages/Profile - shadcn_ui.mhtml`):**
  - `shadcn-pages/Profile - shadcn_ui.mhtml:978` — `.inset-x-3 { inset-inline: calc(var(--spacing) * 3) }` (con `--spacing`=4px → -12px horiz por lado)
  - `shadcn-pages/Profile - shadcn_ui.mhtml:4586` — `.after:-inset-x-3` (pseudo-elemento `::after` con inset horizontal negativo)
  - `shadcn-pages/Profile - shadcn_ui.mhtml:4592` — `.after:-inset-y-2` (pseudo-elemento `::after` con inset vertical negativo, -8px por lado; `-inset-y-2` = `-inset-block-start: 0.5rem` / `-inset-block-end: 0.5rem` en Tailwind, luego Lyra recalibra, dando ~-8px)
  - **Cálculo visual:** inset-x-3 = -12px, inset-y-2 = -8px → box 16px + 24px horiz + 16px vert = 40px × 32px real

- **Craft actual:**
  - `Craft/components/Checkbox.lua:53` — `self.frame:SetHeight(BOX_SIZE)` (solo altura = 16px, sin expansión vertical)
  - `Checkbox.lua:59` — `self._box:SetPoint("LEFT", ...)` — posición sin margen negativo
  - Ancho del frame se calcula en `_recalcWidth()` como `BOX_SIZE` (si no hay label) + `LABEL_GAP` + label width (si existe), sin hit-area buffer
  - `Checkbox.lua:98` — `self.frame:SetScript("OnMouseDown", ...)` registra la interacción, pero **en el frame no expandido**

- **Spec actual:** `docs/components/checkbox.md` **no menciona en absoluto** un hit-area expandido — ni siquiera como omisión consciente (contraste: el `focus-visible:ring-1` **SÍ está explícitamente descartado** en línea 82 por ADR-0011)

## Contexto

En WoW (entorno mouse-only, sin touch), el impacto es **menor** que en web, pero sigue siendo tolerancia de clic **real perdida**, especialmente en casos de uso prácticos:

- Checkbox **standalone sin label** (caso "columna de selección" en un listado): target = 16×16px exacto → muy pequeño
- Checkbox **con label corto** ("Yes", "No"): todo el ancho es target, pero la altura 16px sigue siendo estrecha
- Comparativa: botones web tienen mínimo recomendado 44×44px (WCAG AAA); aquí Lyra lo mitiga con el pseudo-elemento

## Solución propuesta

Expandir el área interactiva del checkbox manteniendo el **box visual en 16×16px**. Opciones:

### Opción A: Frame invisible adicional (recomendada)

- Crear un Frame `_hitbox` de tamaño **40×32px** inset a -12px horiz / -8px vert sobre `self.frame`
- Registrar `OnMouseDown` en `_hitbox` en lugar de `self.frame` (o registrar en ambos)
- El box visual (`_box`) sigue siendo 16×16px, centrado o alineado dentro del _hitbox
- Aplicar en `Create()` y `_recalcWidth()` (recalcular cuando hay label que expande horizontal)

### Opción B: Expandir `self.frame` y posicionar visual dentro

- `self.frame:SetHeight()` y `SetWidth()` a valores expandidos (40×32 o hasta borde del label)
- Posicionar `_box` dentro del frame con inset explicit (`SetPoint("CENTER", ...offsets)` o similar)
- Registro `OnMouseDown` continúa en `self.frame` (ahora expandido)

**Recomendación:** Opción A es más limpia (no mezcla visual + hit-area en el mismo frame), pero ambas son válidas. El owner puede elegir.

### Aplicación en la spec

Actualizar `docs/components/checkbox.md`:
- Nueva sección "Hit-area" en "Dimensiones" (§43–59)
- Tabla de tamaños: añadir fila "Hit-area (interactive)" = 40×32px (box 16px + inset)
- Notas de implementación: documentar el patrón WoW de expansión (pseudo-elemento → frame invisible)

## Notas

- **Insets exactos:** `-inset-x-3` y `-inset-y-2` en Tailwind base con `--spacing=4px` dan -12px horiz / -8px vert, pero Lyra puede recalibrar. El owner debería confirmar los valores exactos en devtools si quiere pixel-perfect (regla: CSS Lyra no es fetcheable — solo el owner la ve).
- **Con label:** si el checkbox tiene label, el hit-area puede extenderse hasta después del label (coherente con shadcn web, donde el label es parte de la interacción — ver también FR-056).
- **Relación con FR-056:** este FR (hit-area del box) + FR-056 (label clickable) = hit-area práctica total de checkbox en Lyra. Ambos van juntos.

## Alcance mínimo (MVP)

- Un nuevo Frame `_hitbox` o expansión de `self.frame` (2–5 líneas de código en `Create()` y `_recalcWidth()`)
- Actualizar la spec (1 sección nueva, 1–2 párrafos)
- Tests: assert de tamaño en `tests/checkbox_spec.lua` para blindar

## Referencias

- Spec actual: [`docs/components/checkbox.md`](../components/checkbox.md)
- Implementación: [`Craft/components/Checkbox.lua`](../../Craft/components/Checkbox.lua) (líneas 53, 59, 98, `_recalcWidth()`)
- Markup Lyra verificado: ejemplo "Notifications" (pegado en auditoría 2026-07-20)
- CSS Lyra: Tailwind insets ([Tailwind docs — inset](https://tailwindcss.com/docs/top-right-bottom-left)) + `shadcn-pages/Profile - shadcn_ui.mhtml` líneas 978, 4586, 4592
- ADR-0011 (focus-ring, mouse-only): [`docs/decisions/ADR-0011.md`](../../docs/decisions/ADR-0011.md)
- Relación: FR-056 (label clickable)
