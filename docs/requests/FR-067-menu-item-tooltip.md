# FR-067 — `Craft.Menu`: no hay forma de dar TOOLTIP a una fila

**Reportado por:** Coffer (SortedBags) — al agrupar las acciones de la toolbar (limpiar ·
combinar · vender basura) en un solo menú 🏷 porque la barra ya no daba más de sí: 14 botones de
28 px en una ventana de 458 px (M10, 2026-07-30).
**Componente:** [`Craft/components/Menu.lua`](../../Craft/components/Menu.lua) —
spec [`docs/components/menu.md`](../components/menu.md)
**Tipo:** Feature (hueco de API)
**Prioridad:** Media — hay fallback (`rightText`), pero obliga a degradar información que el
botón suelto sí daba.

---

## Problema

Una fila de menú puede decir **qué** hace (`label`), **con qué** (`icon`), **cuánto**
(`rightText`) y si está **disponible** (`disabled`), pero no puede explicar **por qué** ni dar
detalle bajo el cursor. En cuanto una acción se muda de un botón de barra a una fila de menú,
pierde su tooltip: es el único canal que el componente no expone.

Y es justo el caso en el que un menú se usa de verdad — agrupar acciones para descongestionar una
barra —, así que el hueco aparece siempre que el consumidor hace lo que la librería invita a hacer.

Estado actual del schema de item (`_renderItem`, Menu.lua:311-442): `type`, `label`, `icon`,
`avatar`, `rightText`, `disabled`, `variant`, `checked`, `group`/`value`, `onClick`/`onToggle`/
`onSelect`, `onDelete`. Ningún `tooltip`. Las filas son frames internos (`item.row`), así que el
consumidor tampoco puede engancharlo por fuera sin tocar internos.

Nota: `disabled` ya distingue "existe pero no ahora", y el patrón de la propia librería para
explicar un control gris es el tooltip (FR-020). Menu es hoy la excepción.

## Reproducción

```lua
menu:SetItems({
  { type = "item", icon = "banknote-arrow-up", label = "Vender basura",
    rightText = "12g 40s", disabled = false,
    onClick = sell },   -- ¿qué se va a vender exactamente? no hay dónde contarlo
})
```

## Propuestas

**A (mínimo) — `cfg.tooltip` = string | función.** `OnEnter`/`OnLeave` sobre `item.row`
(que ya maneja hover para el resaltado) con `GameTooltip:SetOwner(row, "ANCHOR_RIGHT")`. String
para el caso simple; función `fn(GameTooltip)` para el rico (varias líneas, dobles líneas con
color, cifras que cambian entre aperturas). Anclar a la DERECHA del panel, no arriba: un menú ya
está pegado a su ancla y un tooltip encima taparía las filas vecinas.

**B (recomendada) — A + que funcione también con `disabled = true`.** Es el caso que más lo pide
("necesitas un banquero", "requiere un mercader abierto"): hoy `_applyDisabled` hace
`EnableMouse(false)` sobre la fila (Menu.lua:708), así que una fila gris ni siquiera recibe
`OnEnter` y no podría mostrar el motivo. Habría que mantener el mouse habilitado y bloquear solo
el clic/hover-highlight — que es lo que hace `Craft.Button`, cuyo tooltip sí se ve estando gris.

**C (opcional) — `cfg.description`.** shadcn no la tiene en `DropdownMenuItem`, pero sí el
patrón "línea secundaria atenuada" en `Command`/`Select` de sus ejemplos. Ortogonal a A/B: sirve
para texto corto y permanente, no sustituye al tooltip (que es donde cabe una lista).

## Mientras tanto (workaround en el consumidor)

Coffer mete el dato que se mira antes de pulsar en **`rightText`**: el total de oro de la venta,
o el motivo corto del gris ("Necesitas un mercader"). Se pierde el desglose que sí tenía el botón
suelto — una línea por pieza, coloreada por calidad, "3x Nombre" + su valor, las 12 primeras y
"+N más" (paridad con Sorted, checklist §17). Ese detalle vuelve en cuanto cierre este FR.
