# FR-096 — `Craft.ToggleGroup`: ancho completo (`width`), segmentos que se reparten el espacio

**Solicitante:** SMRT (página «Mis notas», rediseño del 2026-09-18 — el owner pidió que el
selector Compartidas/Personales «ocupe la cabecera del sidebar»).
**Componente:** `Craft/components/ToggleGroup.lua`.
**Tipo:** Feature (opción nueva, retrocompatible).
**Prioridad:** Baja. **No bloquea:** SMRT lo deja w-fit a la izquierda mientras tanto.

---

## Problema

`ToggleGroup:_layout()` (ToggleGroup.lua:225-251) mide cada segmento por su texto y fija el
frame al total: siempre es `w-fit`. No hay forma de que el grupo llene un contenedor (la
cabecera de un Sidebar de 180 px, una barra de herramientas), que en shadcn es
`<ToggleGroup className="w-full">` con `flex-1` en cada item.

## Qué se pide

- **`config.width`** (y `ToggleGroup:SetWidth(w)`, re-llamable tras crear: el caso es un
  contenedor que cambia de ancho). Con `width`, los segmentos se reparten el ancho a partes
  iguales (`flex-1`), el texto centrado en cada uno; sin `width`, el comportamiento actual.
- Si el texto de un segmento no cabe en su parte, que no se desborde (elidir o, como mínimo,
  documentar que el consumidor debe dar ancho suficiente).

## Apaño actual en SMRT (a retirar al re-vendorear)

`SMRT/modules/Notes/wow/Editor.lua`: el ToggleGroup va w-fit, anclado a la izquierda de la
cabecera del Sidebar. Al llegar este FR: `width` = ancho de la cabecera menos su padding.

## Resolución — CERRADO (2026-09-18, verificado in-game, released en v2.25.0)

**`config.width` + `ToggleGroup:SetWidth(w)`** (re-llamable; `SetWidth(nil)` vuelve a w-fit).
Con ancho, cada segmento mide `(width − gap·(n−1)) / n`: es `flex-1` = `flex: 1 1 0%`, partes
**iguales** sea cual sea el label, como el `w-full` de shadcn. El ancho sobrevive a
`SetOptions` (se reparte entre los nuevos segmentos).

**Desborde:** el label se limita al hueco que deja su parte (menos `px-2.5` y el icono) y
**elide** con `…`: el FontString se crea con wrap desactivado (regla del bug #2b). Se mide con
`GetUnboundedStringWidth`, porque `GetStringWidth` sobre un FontString acotado devuelve el ancho
ya elidido y el siguiente layout encogería más.

Implementación: [`Craft/components/ToggleGroup.lua`](../../Craft/components/ToggleGroup.lua)
(`_layout`, `SetWidth`). Tests: `tests/togglegroup_spec.lua` (5 nuevos).

**Para SMRT:** `width` = ancho de la cabecera menos su padding, y `SetWidth` cuando la cabecera
cambie de ancho.
