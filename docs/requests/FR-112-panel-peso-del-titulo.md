# FR-112 — `Craft.Panel`: elegir el peso del título (bold)

**Solicitante:** SMRT (revisión UX de la pestaña Display de «Auras personalizadas», 2026-10-15).
**Componente:** `Craft/components/Panel.lua` (build vendoreado 2.33.0, `CRAFT_BUILD = 35`).
**Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-15), release v2.34.0. Incluye el opcional: token de contexto `cardTitleWeight` (vía `overrides`) + `SetTitleWeight`. Demo en `Craft_Browser/pages/Panel.lua` (bloque FR-112).
**Tipo:** Mejora (API / tema).
**Prioridad:** Media. **No bloquea:** SMRT sigue con el título en medium mientras tanto.

---

## Qué falta

El título de una tarjeta se pinta siempre con `t.fontHeading or t.fontMedium or t.font` a `fontSizeLg`
(Panel.lua:310). Entre filas de etiquetas de 13 px, un título medium de 14 px apenas se distingue, y en
un formulario largo (la pestaña Display de una aura: Icon Settings, Swipe Overlay Settings, Position and
Size Settings, una tarjeta por subelemento) no se ve dónde empieza cada sección. El owner pidió los títulos
en negrita. No hay forma de pedirlo: no existe opción de peso y `_title` es privado.

## Propuesta

- Config `titleWeight = "regular" | "medium" | "bold"` (por defecto `"medium"`, como hoy), resuelto con
  `theme:getFont(weight)` en `_applyTheme`, de forma que un cambio de tema o de fuente lo respete.
  Si la fuente no trae negrita, `getFont("bold")` ya cae a la regular (registro de fuentes, Theme.lua ~l. 240).
- Opcional, a decidir por el dueño de Craft: un token de tema `cardTitleWeight` para que el consumidor lo
  cambie en todas sus tarjetas desde su contexto de tema (SMRT lo querría en todas las suyas, no solo en
  Auras), en vez de pasarlo tarjeta a tarjeta.

## Fallback en SMRT mientras tanto

Ninguno: los títulos siguen en medium. No se toca `_title` desde fuera.
