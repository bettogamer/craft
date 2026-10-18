# FR-054 — `Craft.Checkbox`: icono indeterminado = "minus" vs "check" esperado (Lyra parity)

**Reportado por:** Auditoría de fidelidad vs markup Lyra real, ejemplo "Notifications" (Card + FieldGroup de checkbox-fields), 2026-07-20
**Componente:** `Craft/components/Checkbox.lua` (estado indeterminate)
**Tipo:** Fidelidad de diseño (divergencia contra Lyra verificada)
**Prioridad:** Media (impacto visual directo, ejemplo real disponible)
**Estado:** ✅ IMPLEMENTADO (Opción A) — confirmado visualmente por el owner el 2026-07-20 ("nunca veo un guion, solo check o no check"). `_dash`/`_lastIcon` eliminados de `Checkbox.lua`; spec `docs/components/checkbox.md` actualizada. Pendiente: verificación in-game.

---

## Problema

En estado **indeterminado** (`checked == nil`), Craft renderiza una textura "minus"/guion dedicada (`_dash`), heredada de shadcn base que usa el ícono `MinusIcon`. El markup Lyra real (ejemplo "Notifications") muestra que `data-indeterminate` renderiza el **MISMO ícono `<svg class="lucide lucide-check">` (path `M20 6 9 17l-5-5`)** que `data-checked` — no hay glyph distinto en el diseño verificado.

**Evidencia:**

- **Craft actual:**
  - `Craft/components/Checkbox.lua:82-86` — crea la textura `_dash` en capas ARTWORK
  - `Checkbox.lua:237-239` — asigna `self._lastIcon = "dash"` cuando `checked == nil`
  - `Checkbox.lua:244-245` — alphas exclusivos: `_check:SetAlpha(icon == "check" and p or 0)` y `_dash:SetAlpha(icon == "dash" and p or 0)`
  - `Checkbox.lua:281` — `Craft.Icons.Apply(self._dash, "minus", ICON_SIZE)` — carga el icono "minus" del atlas Lucide

- **Spec desalineada:**
  - `docs/components/checkbox.md:41-42` — describe el dash como si fuera verdad verificada ("Para el estado indeterminado, `_check` se reemplaza por `_dash`")
  - `checkbox.md:67` (tabla "Variantes visuales", fila indeterminate) — documenta "no (dash visible)"
  - `checkbox.md:124` (notas de implementación) — menciona `_box._dash` como componente permanente

- **Markup Lyra real:**
  - Ejemplo "Notifications" (pegado por owner 2026-07-20): todas las instancias de checkbox en estado indeterminate llevan `data-indeterminate` + la clase `.cn-checkbox-indicator [&>svg]:size-3.5` — el SVG es el check, **no hay variante visual distinta**.
  - Verificación: CERO reglas CSS `indeterminate` en `docs/reference/lyra-components.css` que oculten el check ni que dibujen un dash por pseudo-elemento.

**CAVEAT explícito:** Los dos archivos `.mhtml` disponibles (`shadcn-pages/Profile - shadcn_ui.mhtml`, `shadcn-pages/Repo - shadcn_ui.mhtml`) **NO contienen ningún checkbox en estado indeterminate**, así que su silencio no es prueba fuerte. La evidencia real son el **markup pegado + ausencia de override CSS**. Confirmación definitiva = el owner mirando el checkbox indeterminate en el **devtools del navegador** sobre la doc de shadcn/Lyra (regla: el CSS Lyra no es fetcheable — solo el owner puede verificarlo).

## Solución propuesta

Una de dos opciones, ambas simplificadoras:

### Opción A: Indeterminate usa icono "check" (visual idéntico a checked)

Cambiar el comportamiento para que **indeterminate render el MISMO icono que checked** (fidelidad Lyra):

- Eliminar la creación y manejo de `_dash` (líneas 82-86 de Checkbox.lua)
- En `_paint()`, líneas 237-239: cambiar `elseif checked == nil then self._lastIcon = "dash"` a `elseif checked == nil then self._lastIcon = "check"` (o simplemente omitir, pues checked y indeterminate comparten prog=1)
- Eliminar las líneas 244-245 que setean alpha de `_dash`
- Eliminar la línea 281 que carga el icono "minus"
- Actualizar `docs/components/checkbox.md` línea 41 (eliminar mención al dash), línea 67 (tabla: cambiar "dash visible" a "sí, check visible"), línea 124 (eliminar mención `_box._dash`)

**Beneficio:** Simplifica el componente (una sola textura de icono, no dos; un estado visual, no dos), mantiene fidelidad Lyra.

### Opción B: Documentar "minus" como decisión deliberada (si hay razón UX para WoW)

Si el diseño del 14px guion fue intencional para diferenciar "pendiente de usuario" (indeterminate) de "checked por sistema", documentar explícitamente:

- Añadir un comentario en `Checkbox.lua:82` o `:281` justificando la divergencia (p. ej. "Divergencia deliberada: WoW no reutiliza de la misma forma; guion denota 'indeterminado' vs checkmark 'confirmado'")
- Actualizar `checkbox.md:41` con una nota clara: "Craft diverge de Lyra: estado indeterminate renderiza 'minus' (guion) para diferenciación visual WoW-específica, no 'check'"

## Alcance mínimo (MVP)

Si se elige **Opción A:**
- Eliminar 5 líneas de código + comentarios en `Checkbox.lua`
- Actualizar 3 puntos en la spec (`checkbox.md`)
- Sin cambios de API pública ni tests (ya existen tests indeterminate que seguirán pasando, pues la API no cambia)

Si se elige **Opción B:**
- Un comentario de 1 línea en Checkbox.lua + una frase en checkbox.md
- Mínimo esfuerzo

## Referencias

- Spec actual: [`docs/components/checkbox.md`](../components/checkbox.md)
- Implementación: [`Craft/components/Checkbox.lua`](../../Craft/components/Checkbox.lua) (líneas 82–86, 237–245, 281)
- Markup Lyra verificado: ejemplo "Notifications" (pegado en auditoría 2026-07-20)
- CSS Lyra: [`docs/reference/lyra-components.css`](../reference/lyra-components.css) (`.cn-checkbox*`, sin rules `indeterminate` específicas)
- Patrón Weave reactivo: [`Craft/components/Checkbox.lua`](../../Craft/components/Checkbox.lua) (ADR-0013 §4.6)
