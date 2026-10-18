# FR-115 · Panel: la acción de cabecera no se coloca si el panel aún no tiene ancho

- **Pide:** SMRT (módulo Auras, tarjeta «Border Settings», 2026-10-16)
- **Componente:** `Craft.Panel` (`components/Panel.lua`) + `Craft.Grid` (`layout/Grid.lua`)
- **Prioridad sugerida:** baja (hay fallback en el consumidor)
- **Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-18), release v2.35.0. La cabecera re-maqueta en su propio `OnSizeChanged` cuando su ancho cambia respecto al de la última pasada del Grid (sin bucle con el `SetHeight` propio). Demo: bloque FR-115 de `Craft_Browser/pages/Panel.lua`.

## Síntoma

Un `Panel` recién creado al que se le pone `SetHeaderAction(frame)` **antes** de darle ancho (el consumidor lo
dimensiona después, en su propio layout) deja la acción **sin anclar**: `frame:GetNumPoints() == 0`, `GetLeft()`
nil, invisible, aunque `IsShown()`/`IsVisible()` sean true y la cabecera sí reserve su alto. Visto en SMRT: el
interruptor «Show Border» de una cabecera sin más botones no aparecía (diagnóstico in-game: host 42×28 visible,
sin posición).

## Causa

`Panel:_layoutHeaderGrid` delega en `Craft.Grid`, y `Grid:Layout()` sale sin hacer nada si el contenedor mide 0
(`Grid.lua:163`, «contenedor sin ancho aún»). El Panel no vuelve a maquetar la cabecera cuando luego recibe ancho:
solo lo hace en `SetHeaderAction`, `SetTitle` y el cambio de tema.

## Propuesta

Que el Panel re-maquete su cabecera cuando cambie su ancho (`OnSizeChanged` del frame, solo si hay acción y el
ancho pasó de 0 a > 0 o cambió), igual que hace Flex/Grid en otros contenedores. Alternativa mínima: documentar en
`SetHeaderAction` que hay que llamarlo con el panel ya dimensionado.

## Fallback en el consumidor (mientras tanto)

SMRT `modules/Auras/ui/Fields.lua`: tras `frame:SetWidth(cardW)`, si `host:GetNumPoints() == 0` vuelve a llamar
`card.panel:SetHeaderAction(host)` (misma acción: solo re-maqueta). Quitarlo al re-vendorear con el arreglo.
