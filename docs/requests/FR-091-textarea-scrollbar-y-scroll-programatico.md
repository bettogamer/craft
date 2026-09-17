# FR-091 — `Craft.Textarea`: sin barra de desplazamiento visible y sin forma de volver arriba

**Solicitante:** SMRT (NSRT F4b, editor de notas de banda, 2026-09-16).
**Componente:** [`Craft/components/Textarea.lua`](../../Craft/components/Textarea.lua) —
`Textarea:Create` / `Textarea:SetValue` / `Textarea:_followCursor`
**Tipo:** Hueco de UI (no hay barra) + hueco de API (no hay `ScrollToTop`).
**Prioridad:** Media. No bloquea: la rueda del ratón y el seguimiento del cursor sí desplazan, así
que el texto es accesible; lo que falta es **ver** que hay más texto y poder volver arriba desde el
consumidor.
**Estado:** ✅ **CERRADO** (2026-09-16) — los tres puntos, con el riel **reutilizado** de
`Craft.Scroll` (extraído a `Craft.ScrollBar`): ver *Resolución* al final.

---

## Problema

El editor de notas de SMRT es un `Craft.Textarea` con una nota de banda entera dentro: 40-200
líneas es lo normal. Dos cosas se notan enseguida al usarlo con texto largo:

1. **No hay barra de desplazamiento.** El componente monta un `ScrollFrame` con rueda y
   seguimiento del cursor (`Textarea.lua:73-95`, `_followCursor`), pero no pinta ningún indicador:
   nada dice que hay texto por debajo, ni cuánto, ni dónde estás. `Craft.Scroll` sí trae barra con
   pulgar (`Scroll.lua:_updateScrollbar`), así que el patrón visual ya existe en la librería.
2. **No se puede volver arriba desde fuera.** Al cambiar de nota, el consumidor llama a
   `SetValue(otroTexto)` y el `ScrollFrame` **conserva el desplazamiento anterior**: venías del
   final de una nota larga y la nota nueva aparece por su mitad, o en blanco si es más corta. No
   hay `ScrollToTop`, ni `SetValue` reinicia la posición.

## Por qué no hay apaño desde el consumidor

- El `ScrollFrame` (`self._scroll`) y el `EditBox` interno son privados; `GetEditBox()` da el
  `EditBox`, pero `SetVerticalScroll` vive en el `ScrollFrame`, que no se expone.
- `GetEditBox():SetCursorPosition(0)` mueve el caret pero solo arrastra la vista cuando el
  `OnCursorChanged` llega a `_followCursor`, lo que depende del foco: no es una forma fiable de
  decir «vuelve arriba».
- Tocar `textarea._scroll` desde el consumidor es depender de internos de la librería, que es
  justo lo que la regla de vendoreado prohíbe.

## Propuesta

1. **Barra de desplazamiento**, con el mismo aspecto y comportamiento que `Craft.Scroll`
   (aparece solo cuando el contenido pasa del alto visible; pulgar arrastrable; se atenúa cuando
   no se usa). Lo ideal es reutilizar el código de la barra de `Scroll.lua` en vez de una segunda
   implementación.
2. **`Textarea:ScrollToTop()`** (y, si sale gratis, `ScrollToBottom()` y
   `SetScrollOffset(n)`/`GetScrollOffset()`, como los de `Craft.Scroll`).
3. **`SetValue` vuelve arriba por defecto**: cargar otro texto es empezar otro documento. Si se
   prefiere no cambiar el comportamiento actual, con el punto 2 el consumidor lo hace él.

## Criterio de aceptación

- Un `Textarea` con más texto del que cabe enseña barra; al reducir el texto por debajo del alto
  visible, la barra desaparece.
- Arrastrar el pulgar desplaza el texto, y la rueda mueve también el pulgar.
- `SetValue` con un texto nuevo deja la vista en la primera línea (o `ScrollToTop()` lo consigue).
- El foco y la posición del caret no cambian por pintar la barra.

## Mientras tanto, en SMRT

El editor se queda con la rueda del ratón y avisa en la ayuda de la pantalla. Al cambiar de nota
se llama a `GetEditBox():SetCursorPosition(0)`, que en la mayoría de los casos arrastra la vista
arriba; cuando el FR esté resuelto se sustituye por `ScrollToTop()` y se re-vendorea el build.


---

## Resolución (2026-09-16)

Los tres puntos, y el 1 por la vía que pedía el FR: **reutilizar el riel, no escribir un
segundo**.

1. **Barra de desplazamiento.** El riel de `Scroll.lua` —track, pulgar arrastrable con sus
   estados secondary/accent/primary, auto-ocultado y el manejo de la esquina reservada por
   `Craft.Window`— sale a **`Craft/components/ScrollBar.lua`**, y ahora lo montan tanto
   `Craft.Scroll` como `Craft.Textarea`. `Craft.Scroll` no cambia por fuera: mismos campos
   privados (pasan a ser alias de las regiones del riel), mismos métodos, y su spec de esquina
   reservada sigue verde sin tocar una sola aserción. En el Textarea el riel se ancla **dentro**
   del campo (1px del borde, `py-2` arriba y abajo), así que el track coincide con el área de
   texto y el recorrido del pulgar mapea lo que se ve.
2. **API de scroll.** `ScrollToTop()`, `ScrollToBottom()`, `SetScrollOffset(n)` y
   `GetScrollOffset()`, con los mismos nombres y la misma semántica de clamp que en
   `Craft.Scroll`. Salieron gratis, como anticipaba el FR.
3. **`SetValue` vuelve arriba**, que era la opción preferida del FR.

**Decisión que el FR no pedía y conviene conocer: el ancho del riel se reserva SIEMPRE**, haya
desbordamiento o no. El ancho del viewport es el ancho de wrap del `EditBox`: si el riel
apareciese y desapareciese, el wrap cambiaría, el alto del texto cambiaría, y eso volvería a
conmutar el riel — un texto justo en la frontera oscilaría indefinidamente. Es la misma
decisión que ya tomaba `Craft.Scroll`. Efecto visible: el texto termina 8px antes, delante de
la barra en vez de debajo de ella.

Criterios de aceptación, todos con test (`tests/textarea_spec.lua` 12 nuevos,
`tests/scrollbar_spec.lua` 8 nuevos):

- El riel aparece al desbordar y **desaparece** al reducir el texto por debajo del alto visible.
- La rueda mueve el offset **y** el pulgar con él; el drag del pulgar usa el mismo cálculo que
  en `Craft.Scroll` (y su conversión de coordenadas de ADR-0011).
- `SetValue` deja la vista en la primera línea.
- **El caret no se mueve** por desplazar la vista — hay un test dedicado, porque es justo la
  diferencia con el apaño de `SetCursorPosition(0)` que el consumidor usaba.

- Implementación: `Craft/components/ScrollBar.lua` (nuevo), `Craft/components/Scroll.lua`
  (delega), `Craft/components/Textarea.lua`. Registrado en **los dos `.toc`**.
- Spec: `docs/components/scroll.md` §*Riel compartido (`Craft.ScrollBar`)* y
  `docs/components/textarea.md` §*Barra de desplazamiento (FR-091)*.
- Demo: `Craft_Browser/pages/Textarea.lua` → bloque FR-091 (nota de 40 líneas, botones
  ScrollToTop/ScrollToBottom y un «Load note» que alterna textos vía `SetValue`).

**Para SMRT:** al re-vendorear, el `GetEditBox():SetCursorPosition(0)` del cambio de nota se
sustituye por `ScrollToTop()` — o directamente se borra, porque `SetValue` ya lo hace.
