# FR-144 — `Craft.ScrollBar`: el arrastre del thumb no debe quedarse enganchado

**Solicitante:** Craft (revisión de NaowhForever, 2026-11-13).
**Componente:** `Craft/components/ScrollBar.lua` (riel compartido de Scroll, Textarea, Menu, Select…).
**Tipo:** Bug latente / robustez.
**Prioridad:** Media.
**Estado:** implementado en dev (2026-11-13, sin release). `ScrollBar:_endDrag()` es la única
salida del arrastre (OnMouseUp, botón ya no pulsado en el `OnUpdate` —`IsMouseButtonDown`, como Slider
FR-110—, `OnHide` del riel y `Destroy`). Specs en `tests/scrollbar_spec.lua`. **Pendiente in-game:** el
repro Alt-Tab de la página Scroll del Browser.

---

## Síntoma (esperado)

Si el `OnMouseUp` del thumb no llega (se suelta el botón fuera del cliente tras un Alt-Tab, se abre
un menú del juego, el frame se oculta y se vuelve a mostrar a mitad de arrastre…), el thumb sigue al
cursor sin botón pulsado hasta el siguiente clic.

## Causa

`ScrollBar.lua:121-136`: el `OnUpdate` del arrastre solo comprueba `self._dragging`, que solo pone a
`false` el `OnMouseUp` (`:138-140`) o la limpieza de `:326`. No mira si el botón sigue pulsado.

`Craft.Slider` ya lo resuelve (FR-110): su `OnUpdate` corta con `IsMouseButtonDown`
(`Slider.lua:296-299`, `:425-437`). NaowhForever hace lo mismo en su slider
(`Core/Options/Widgets.lua:395-430`).

## Propuesta

En el `OnUpdate` del thumb: si `not IsMouseButtonDown("LeftButton")`, cerrar el arrastre por la misma
ruta que `OnMouseUp` (`_dragging = false`, quitar el `OnUpdate`, restaurar el color). Factorizar esa
ruta en un `_endDrag()` que usen los tres sitios. Revisar también `OnHide`: cerrar el arrastre si el
riel se oculta durante el mismo.

## Criterio de aceptación

- Test: con `IsMouseButtonDown` stub a `false` a mitad de arrastre, el siguiente tick termina el
  arrastre y quita el `OnUpdate`.
- In-game: arrastrar el thumb, Alt-Tab, soltar fuera, volver: el thumb no sigue al cursor.
- Demo: nota en la página Scroll del Browser con el paso de repro.

## Referencias

`docs/research/naowhforever-ui-patterns.md` §2; FR-110 (Slider drag), FR-090/091 (ScrollBar).
