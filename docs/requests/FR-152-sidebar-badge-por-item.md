# FR-152 — Badge de texto al final de una fila del `Sidebar`

**Solicitante:** QuantumDungeonTools (F6b, ventana principal), 2026-11-14.
**Componente:** `Craft/components/Sidebar.lua` (`AddItem`, `_positionRow`).
**Tipo:** API (campo nuevo de ítem).
**Prioridad:** Baja (el consumidor tiene fallback).
**Estado:** ✅ implementado y verificado in-game (2026-11-14), release v2.51.0.

---

## Necesidad

El diseño aprobado de la ventana principal de QDT (lienzo v52, artboard «Inicio») marca un módulo
que aún no existe con una etiqueta **«PRONTO»** al final de su fila del sidebar: caja con borde
fino, texto de 9 px semibold en `mutedForeground`, pegada al borde derecho de la fila (patrón
shadcn `SidebarMenuBadge`). Hoy un ítem admite `disabled`, `muted`, `tooltip` y `action` (botón con
icono), pero no un texto/badge al final; y las filas se reciclan (pool), así que el consumidor no
puede colgar un `Craft.Badge` propio de la fila sin que acabe en otro ítem.

## Propuesta

- Campo de ítem **`badge`**: `string` (texto) o `{ text =, variant = "outline"|"secondary"|…,
  tone = <token o {r,g,b,a}> }`. Se pinta con `Craft.Badge` (o su misma receta) anclado a la derecha
  del contenido de la fila, antes de `action` si hay ambos, y la etiqueta del ítem se elide para no
  pisarlo.
- Vive en el pool de la fila: se crea una vez por fila y se oculta cuando el ítem no trae `badge`.
- `disabled = true` lo atenúa igual que el icono (`DISABLED_ALPHA`).
- `SetItems` / `UpdateItem` (si existe) lo refrescan como el resto de campos.

## Fallback en el consumidor (mientras tanto)

QDT pone el ítem `disabled` con `tooltip = "Pronto"` y enseña el badge «PRONTO» solo en la tarjeta
del módulo en la página Inicio (`QuantumDungeonTools/wow/MainWindow.lua`, `buildSidebar`).

## Verificación sugerida

- `tests/sidebar_spec.lua`: un ítem con `badge` crea/muestra la región; sin `badge` queda oculta
  tras reciclar la fila.
- Demo: página Sidebar del Browser con un ítem «PRONTO» deshabilitado y otro con contador («3»).

## Resolución (dev, 2026-11-14)

Norte: fidelidad shadcn. `SidebarMenuBadge` en shadcn **no es una caja**: es texto `text-xs`
medium (`h-5 min-w-5 px-1`, `right-1`, `pointer-events-none`, acento con `peer-hover` /
`peer-data-active`). Por eso el campo tiene dos formas:

- `badge = "3"` / `3` / `{ text, color }` → el `SidebarMenuBadge` tal cual (contador).
- `badge = { text, variant, ... }` → la composición `<SidebarMenuBadge><Badge variant="outline">`:
  un `Craft.Badge` con los overrides de FR-140 (`fontSize`, `fontWeight`, `paddingX/Y`,
  `textColor`/`borderColor`/`fillColor`, `pill`, `icon`, `fontFlags`).

Cambios respecto a la propuesta:

- **`tone` → `color`**: el mismo nombre que `action.color` (FR-126) en el Sidebar; en un
  `Craft.Badge` se traduce a `textColor`.
- **`disabled` no atenúa el badge**: en shadcn `disabled:opacity-50` va en el botón y el badge es
  su hermano (igual que la acción, FR-109). El «PRONTO» de QDT se pide con
  `color = "mutedForeground"`, que es justo lo que pinta el diseño (texto `mutedForeground`).

Para el caso de QDT:

```lua
{ id = "it", label = "Instance Tracker", icon = "map", disabled = true, tooltip = "Pronto",
  badge = { text = "PRONTO", variant = "outline", fontSize = 9, fontWeight = "bold",
            paddingX = 4, color = "mutedForeground" } }
```

(`fontWeight` de `Craft.Badge` admite `regular`/`medium`/`bold`; no hay semibold.)

Implementación: `Craft/components/Sidebar.lua` (`_makeRowBadge`, `_layoutBadge`, `_colorBadge`,
`_positionRow`). Tests: `tests/sidebar_spec.lua` («item badge (FR-152)», 8 casos). Demo: página
Sidebar del Browser, «Badge (FR-152)», con botón «FR-152: reciclar filas».
