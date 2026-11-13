# FR-146 — Auditoría: tope de frame level y centrado de piezas de tamaño impar

**Solicitante:** Craft (revisión de NaowhForever, 2026-11-13).
**Componente:** transversal (14 llamadas `SetFrameLevel(x:GetFrameLevel() + N)` en `Craft/`; marcas y
thumbs de Checkbox, Radio, Switch, Slider, Avatar).
**Tipo:** Auditoría (devuelve fixes concretos o se cierra).
**Prioridad:** Baja.
**Estado:** §1 implementado en dev (2026-11-13, sin release): `Craft.MAX_FRAME_LEVEL = 10000`,
`Craft.Strata.level(n)` y `Craft.Strata.above(frame, n)`; migradas TODAS las subidas de nivel de Craft
(26 llamadas: las 18 `x:GetFrameLevel() + N` y las 8 de Slider/Toast sobre una base guardada). Spec con
padre a 9998. §2 (centrado impar): banco en la página Pixels del Browser (Checkbox, Radio, Switch,
Slider, Avatar a ×0.64 / 0.71 / 0.9 / 1.0); **pendiente de mirar in-game** y abrir fixes concretos de lo
que se vea descentrado. **Primer caso confirmado y arreglado (Badge, 2026-11-13):** según la fila, el
mismo badge salía de 17 o 18 px y el texto (anclado al centro) redondeaba por su cuenta: las píldoras
de una fila se veían 1 px bajas. Fix: alto redondeado a px físicos enteros + texto e icono anclados
`TOPLEFT` con desplazamiento entero (`Theme.px`). Candidatos con el mismo patrón: Button, Toggle, Tabs. **Medido a escala pixel-perfect (1080p, efectiva 0.7111, botón de la página Badge, 2026-11-13):**
todos los badges (cuadrados, píldora, compactos, con icono) salen idénticos: caja de 20 px, mayúsculas
de 9 filas y 5 px arriba / 4 abajo, el mejor reparto posible con un hueco impar. Conclusión: el código es
determinista y correcto; el ±1 px que cambiaba de fila en fila a escala no entera es el redondeo
independiente de caja y texto del cliente (afecta a toda la UI, Blizzard incluida). Corregir la fase en
tiempo de ejecución queda descartado por ahora (se rompe con cada scroll).

---

## 1. Tope de frame level

El cliente tiene un frame level máximo (10000). Un `SetFrameLevel(parent + N)` encima de un padre ya
alto (ventanas de otros addons apiladas, Dialog sobre Window sobre Popover, FR-033) puede pasarse y el
cliente lo recorta sin avisar, desordenando capas (el ✕ del Badge o el botón sobre la zona de arrastre
quedarían debajo). NaowhForever lo limita: `math.min(frameLevel + 1, MAX_FRAME_LEVEL)`
(`Core/Core.lua:~695`). Craft no lo hace en ninguna de sus 14 llamadas.

**Propuesta:** helper `Craft.Strata.above(frame, n)` (o en Theme) que devuelva
`math.min(frame:GetFrameLevel() + n, 10000)`, y migrar las 14 llamadas.

## 2. Centrado a medio píxel con tamaños impares

Una pieza de tamaño impar (thumb del Switch, marca de 9 px en una caja de 16, punto del Radio) anclada
por `CENTER` dentro de un padre par cae en medio píxel; el motor la ajusta a la rejilla y puede quedar
1 px descentrada o temblar al mover la ventana. NaowhForever redondea a mano los tamaños de sus
piezas (`floor(H * share + ROUND)`) y deja el centrado al motor. Craft: sin revisar.

**Propuesta:** banco en el Browser con Checkbox, Radio, Switch, Slider y Avatar a 4 escalas de UI;
corregir los que se vean descentrados (mismo tamaño de paridad que el padre, o ancla por esquina con
offset entero en píxeles físicos, `px()`).

## Criterio de aceptación

- Ninguna llamada de Craft puede pasar de 10000 (test del helper con padre a 9998).
- Informe del banco en este FR; FR o fixes concretos para lo que se vea mal.

## Referencias

`docs/research/naowhforever-ui-patterns.md` §1.5 y §2 (fila Frame level); FR-033 (`Craft.Strata`);
FR-058 (`px()`); FR-143 (snapping de texturas curvas: probar en el mismo banco).
