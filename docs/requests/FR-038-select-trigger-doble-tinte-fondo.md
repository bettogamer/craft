# FR-038 — Select: trigger sale más claro que shadcn (doble tinte del fondo)

**Reportado por:** Comparación visual shadcn vs Craft (interno, 2026-07-18)
**Componente:** `Craft/components/Select.lua` + `Craft/components/Combobox.lua` (shadcn: Select, Combobox)
**Tipo:** Bug fix (fidelidad)
**Prioridad:** Media
**Estado:** ✅ Implementado y verificado in-game (2026-07-18)

> **Defecto COMPARTIDO:** el trigger de Combobox es "Select-style" y copia la misma técnica
> (`_triggerBorder` full-fill bajo `_triggerBg` translúcido) — mismo doble tinte. Fix aplicado a ambos.

---

## Problema

El fondo del trigger del Select se ve **notablemente más claro** (gris más marcado) que en shadcn,
donde el trigger es apenas más claro que el card. No es un token equivocado — los tokens son correctos
(`border-input` = blanco 0.15, `bg-input/30` = blanco 0.045); es la **técnica de borde+fondo**.

Select pinta el borde como una **textura que rellena TODO el frame** y mete el fondo encima con un
inset de 1px:

- `Select.lua:86-87` — `_triggerBorder` con `SetAllPoints` → cubre el frame entero.
- `Select.lua:398` — `_triggerBorder:SetColorTexture(t.input, 0.15)` a frame completo.
- `Select.lua:403` — `_triggerBg` (inset 1px) encima a 0.045 (input/30).

El comentario dice *"the border frame is the visible background, bg is inset 1px on top"* — pero eso
**solo funciona si el fondo es opaco**. Como `_triggerBg` es translúcido (0.045), el blanco del borde
de abajo **se transparenta a través** y el interior recibe las **dos** capas apiladas (0.15 + 0.045),
en vez de solo el fondo.

Composite sobre el card (`#171717` ≈ 0.091):

| | shadcn (correcto) | Craft (actual) |
|---|---|---|
| Interior | blanco 0.045 sobre card → **≈ 0.13** | 0.15 + 0.045 apiladas sobre card → **≈ 0.26** |

El interior queda con ~**el doble** de luminosidad → el "cajón gris claro". El borde (0.15) está bien;
lo que está mal es que ese 0.15 también rellena el centro.

**Contraste:** `Input.lua` usa el MISMO token (`border-input` + `bg-input/30`) y lo hace bien
(`Input.lua:69-75`): el borde son **4 texturas de 1px** vía `Craft.Theme.AnchorBorder`, no un relleno.
Así el interior muestra **solo** el `_bg`. Por eso el Input se ve sutil y el Select no.

**Escenario:** cualquier Select sobre un card/panel → el trigger destaca como un recuadro gris claro en
lugar del recuadro sutil de shadcn.

## Solución propuesta

Alinear Select al patrón de Input: borde = 4 texturas de 1px con `Craft.Theme.AnchorBorder`, en vez de
una textura full-fill bajo el fondo translúcido. Afecta:

- `_triggerBorder` (una textura) → `_borderTop/_borderBottom/_borderLeft/_borderRight` (cuatro).
- `_applyTheme`: `AnchorBorder(...)` + pintar el borde idle (input) con un helper.
- Swaps de color (input↔ring) repintan las 4 texturas vía el helper: en Select `Open()`/`Close()`;
  en Combobox `Open()`/`_onPanelClosed()`.

El fondo (`_triggerBg`) y su hover no cambian: siguen inset 1px a input/30 ↔ input/50. Fix idéntico en
ambos componentes (helper `_paintTriggerBorder`).

## Caso de uso

Todo Select en formularios (Coffer, settings). Ejemplo shadcn "Preferred Currency".

## Impacto

Fix de fidelidad; cambios locales al componente; sin impacto en la API pública. Riesgo bajo (reusa el
helper `AnchorBorder` ya probado por Input/Checkbox/Button).
