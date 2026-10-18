# FR-098 — `Craft.Sidebar`: doble clic sobre un item (`onDoubleClick`)

**Solicitante:** SMRT (página «Mis notas»: doble clic sobre una nota la activa, 2026-09-23).
**Componente:** `Craft/components/Sidebar.lua`.
**Tipo:** Mejora.
**Prioridad:** Baja. **No bloquea:** SMRT detecta el doble clic por su cuenta (ver abajo).

---

## Qué falta

Un item de `Craft.Sidebar` solo avisa de un clic, con `onSelect(id)` (y `itemConfig.onClick`).
No hay forma de enterarse de un doble clic. En una lista de documentos, «doble clic = abrir o
usar» es lo que se espera: en Mis notas, doble clic sobre una nota la pone en el panel.

## Propuesta

Un callback opcional en la config, sin romper lo que ya existe:

```lua
Craft.Sidebar:Create(parent, {
  onSelect = function(id) ... end,        -- igual que ahora: se dispara en CADA clic
  onDoubleClick = function(id) ... end,   -- nuevo: el segundo clic de un doble clic
})
```

- Usar `OnDoubleClick` del `Button` de la fila (`itemFrame`), que el cliente ya da. El
  primer clic sigue llamando a `onSelect`, así que la fila ya está seleccionada cuando llega
  `onDoubleClick`.
- Las filas con hijos (`collapsible`) y las filas deshabilitadas no lo disparan.
- Opcional, por coherencia: `itemConfig.onDoubleClick`, como ya existe `itemConfig.onClick`.

## Apaño actual en SMRT (quitar al re-vendorear)

`SMRT/modules/Notes/wow/Editor.lua`, en el `onSelect` de `w.list`: dos `onSelect` sobre el
mismo id en menos de `DOUBLE_CLICK` (0,4 s) cuentan como doble clic. Cuando esto salga, se
cambia por `onDoubleClick` y se borran `DOUBLE_CLICK` y `lastClick`.

## Resolución — IMPLEMENTADO en dev (2026-09-27, pendiente in-game y release)

Tal cual la propuesta: `config.onDoubleClick(id)` e `itemConfig.onDoubleClick(id, itemConfig)`,
colgados del `OnDoubleClick` del `Button` de la fila. El primer clic sigue siendo `onSelect`.
Ramas (`collapsible`) y filas `disabled` no lo disparan.

Detalle: el script **solo se registra si hay algún callback** (global o del item). Con un
`OnDoubleClick` puesto, el cliente entrega el segundo clic ahí y **no** como `OnClick`; sin
callback, las sidebars que no lo usan se comportan exactamente como antes.

Implementación: [`Craft/components/Sidebar.lua`](../../Craft/components/Sidebar.lua). Tests:
`tests/sidebar_spec.lua` (4 nuevos).

**Para SMRT:** cambiar el apaño de `Editor.lua` por `onDoubleClick` y borrar `DOUBLE_CLICK` y
`lastClick`. Ojo: con `onDoubleClick` puesto, el doble clic ya no produce dos `onSelect`.
