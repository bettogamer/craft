# FR-056 — `Craft.Field`: label clickable = toggle del control asociado (web parity)

**Reportado por:** Auditoría de fidelidad vs HTML/spec Lyra, ejemplo "Notifications" (Field con Checkbox), 2026-07-20
**Componente:** `Craft/components/Field.lua` (wiring label → control)
**Tipo:** Usabilidad (patrón web `<label for>` no implementado)
**Prioridad:** Menor (mejora UX, pero workaround: clicar el control directo)
**Estado:** ✅ Implementado (dev, 2026-07-20) — **Opción A** (duck-type con fallback silencioso). Dos desvíos respecto al esbozo: (1) se añadió `Toggle()` público a `Checkbox` y `Switch` y se prioriza sobre `SetChecked(not GetChecked())`, porque el fallback dejaba desincronizado el signal two-way de ADR-0013; (2) el cableado es `EnableMouse` + `OnMouseDown` a mano, NO `Craft.Label` `config.onClick` (ese modo tiñe el texto de `primary` en hover — afordancia de link que un label de formulario no tiene). Añadido guard de `disabled` vía `controlFrame:IsMouseEnabled()`. **Verificado in-game (2026-07-20)** — el label acciona el control. Cerrado

---

## Problema

En `Craft.Field`, el label se crea como un `Craft.Label` puro (FontString), sin handler de mouse ni referencia al control asociado. En el HTML real (ejemplo Notifications), el label es un **`<label for="id">` nativo**, así que clicar el texto togglea el control (Checkbox, Radio, etc.). En Craft, clicar el label no hace nada — solo el control mismo responde al clic.

**Evidencia:**

- **HTML Lyra real (ejemplo "Notifications"):**
  - El markup usa `<label aria-labelledby="notify-all-label">` o `<label for="...">` (según la variante), creando una relación bidireccional: clicar el label ejecuta `input:click()`

- **Craft actual:**
  - `Craft/components/Field.lua:74-78` — crea el label sin `OnMouseDown` handler:
    ```lua
    if self._cfg.label then
        self._label = Craft.Label:Create(self.frame, { text = self._cfg.label })
    end
    ```
  - `Field.lua` **no almacena ni usa** el `config.control` para reenviar eventos (solo lo reparenta, línea 70-72)
  - **NO hay wiring** de toggle/SetChecked en `Field.lua` (búsqueda: `control:SetChecked()` / `control:Toggle()` = CERO resultados)

- **Spec actual:** `docs/components/field.md` sección "Diferencias conocidas vs shadcn" (§186–196, líneas 186–197) **NO menciona esta limitación** — lista omisiones de componentes (FieldSet, FieldLegend, etc.) pero no documenta que el label no sea clickable

## Contexto

Es el **complemento natural de FR-055** (hit-area del checkbox):
- FR-055 expande el área de click del **box visual** a 40×32px
- FR-056 permitiría clicar el **label** para togglear el control
- Juntos = **área interactiva práctica total** del control, coherente con shadcn web

En WoW es una mejora de UX marginal (el usuario puede clicar el control directo), pero es diferencia abierta vs web y reduce la tolerancia de clic disponible.

## Solución propuesta

**Opción A: Registrar OnMouseDown en label y reenviar al control (recomendada)**

Si `config.control` expone un método de toggle (duck-type):

```lua
-- En Field:Create() tras crear self._label:
if self._label and self._cfg.control then
    local controlFrame = self:_resolveFrame(self._cfg.control)
    self._label:GetFrame():SetScript("OnMouseDown", function()
        -- Buscar método toggle en el control (Checkbox, Radio, Switch, etc.)
        local ctrl = self._cfg.control
        if type(ctrl.Toggle) == "function" then
            ctrl:Toggle()
        elseif type(ctrl.SetChecked) == "function" then
            -- Alternativa: leer estado y invertir
            ctrl:SetChecked(not ctrl:GetChecked())
        end
    end)
end
```

**Requerimientos:**
- El control debe exponer `:Toggle()` o `:GetChecked()` / `:SetChecked()` (API común: Checkbox, Radio, Switch, Toggle)
- Wiring ocurre en `Create()` tras crear el label (post-theme, post-config)
- Sin cambios de API pública de Field (solo comportamiento interno)

**Beneficio:** Coherencia web, hit-area práctica expandida, patrón `<label for>` en WoW.

**Riesgo:** Si el control NO expone toggle (p. ej. un Frame crudo, un Input de texto), el clic label hace nada — es robusto (fallback silencioso), pero conviene documentar.

### Opción B: Documentar como limitación conocida

Si se decide fuera de alcance (ROI bajo en WoW, patrón dudoso en mouse-only):

- Añadir un punto en `field.md` sección "Diferencias conocidas" (§186–196):
  > "**Label no clickable:** a diferencia de `<label for>` en HTML, el label de Field no togglea el control al clicar. El usuario debe clicar el control mismo (Checkbox box, Radio orb, etc.) o usar tab + enter (si keyboard estuviera soportado, ADR-0011)."

- Sin código, solo documentación

## Alcance mínimo (MVP)

**Opción A:**
- 5–8 líneas de código en `Field.lua` (`Create()`)
- 1 frase en `field.md` documentando el comportamiento
- Sin tests nuevos (patrón de wiring, no API pública)

**Opción B:**
- 1 frase en `field.md` sección "Diferencias conocidas"
- Mínimo esfuerzo

## Notas

- **Duck-typing**: la solución debe no asumir un método específico. Usar `:Toggle()` si existe, fallback a `:SetChecked()` + `:GetChecked()`, fallback silencioso si nada existe.
- **Relación con FR-055**: escribir ambos FRs juntos en el spec (hit-area box + label clickable = hit-area práctica total)
- **Input (no checkbox)**: `Craft.Input` (RFC-002 o future) NO tendría sentido toggle en el label — Field+Input requeriría otro patrón (quizá label + FocusHint). Por eso el duck-type fallback es importante.

## Alcance NO incluido

- **Radio + RadioGroup:** Field+Radio debería comportarse igual (label togglea el radio). Si es parte de RadioGroup el comportamiento es idéntico (reenviar a `:SetChecked(true)`).
- **Foco keyboard + enter:** ADR-0011 descarta keyboard en WoW (mouse-only); el label click es mouse-only.

## Referencias

- Spec actual: [`docs/components/field.md`](../components/field.md) (sección "Diferencias conocidas", líneas 186–197)
- Implementación: [`Craft/components/Field.lua`](../../Craft/components/Field.lua) (líneas 74–78, `Create()`)
- HTML Lyra verificado: ejemplo "Notifications" (pegado en auditoría 2026-07-20)
- Patrón web: `<label for="id">` (MDN — [HTML label element](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/label))
- Relación: FR-055 (checkbox hit-area)
- ADR-0011 (mouse-only, sin keyboard): [`docs/decisions/ADR-0011.md`](../../docs/decisions/ADR-0011.md)
