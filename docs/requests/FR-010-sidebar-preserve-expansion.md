# FR-010 — Sidebar: preservar el estado de expansión al `SetItems` (refrescos del árbol)

**Reportado por:** Sentry (consumer addon)
**Componente:** `Craft/components/Sidebar.lua`
**Tipo:** Feature Request
**Prioridad:** Media — afecta a cualquier consumer que reconstruya el árbol tras editarlo (CRUD)
**Estado:** ✅ Implementado (dev) — `Sidebar.lua` + `tests/sidebar_spec.lua`; pendiente release/bump-build

---

## Problema

`Sidebar:SetItems(tree)` **reconstruye el árbol desde cero** y cada nodo colapsable arranca según su
`defaultOpen` (por defecto colapsado). Por tanto, cuando un consumer reconstruye la lista para reflejar un
cambio (añadir/quitar/renombrar un item), **se pierde qué nodos tenía expandidos el usuario**: todos
vuelven a su `defaultOpen`. Es continuación de FR-008 (árbol colapsable).

## Caso de uso (Sentry)

La UI de configuración (M7) edita packs en vivo y refresca el `Sidebar` tras cada operación CRUD:

- **Añadir widget a un pack** → tras `SetItems` el pack se **colapsa**, ocultando el widget recién creado.
- **Borrar un widget** → el pack que estaba **abierto se cierra** (y los demás packs también).
- En general, cualquier `SetItems` colapsa todo el árbol, rompiendo la sensación de estado estable.

## Solución propuesta

Que `SetItems` **conserve por defecto** el estado de expansión de los nodos cuyo `id` exista antes y
después; los nodos nuevos usan su `defaultOpen`. Y exponer API pública para leerlo/fijarlo explícitamente.

### API
```lua
-- 1) SetItems preserva expansión por id (comportamiento por defecto, retrocompatible):
sidebar:SetItems(tree)            -- nodos con id repetido mantienen su _open; nuevos → defaultOpen

-- 2) Control explícito del estado de expansión:
local state = sidebar:GetExpandedState()   -- → { [nodeId] = true/false, ... } (solo nodos colapsables)
sidebar:SetExpandedState(state)            -- aplica un mapa id → expandido
sidebar:IsExpanded(nodeId)                 -- → boolean

-- (opcional) variante explícita por si se quiere forzar:
sidebar:SetItems(tree, { preserveExpansion = true })
```

### Comportamiento
- **Por defecto**, `SetItems` mapea el `_open` actual por `id` y lo reaplica tras reconstruir.
- `GetExpandedState()` devuelve un snapshot `{ id → bool }` de los nodos colapsables.
- `SetExpandedState(map)` expande/colapsa según el mapa (ignora ids inexistentes).
- `Select(id)` ya auto-expande ancestros (FR-008); esto cubre el resto de nodos no relacionados.

## Workaround actual (Sentry)

Leemos los **internos** del componente antes de cada `SetItems` y los restauramos a mano:

```lua
-- OptionsFrame.lua — frágil: depende de _sections/_open privados de Craft.Sidebar
local function snapshotOpen()
  local open = {}
  for _, e in ipairs(sidebar._sections or {}) do
    if e.collapsible and e.itemId then open[e.itemId] = e._open and true or false end
  end
  return open
end
-- y reconstruimos el árbol pasando defaultOpen = openMap[id]
```

Funciona, pero acopla a Sentry con la estructura interna de `Sidebar` (`_sections`, `_open`), que puede
cambiar sin aviso. Por eso pedimos API pública.

## Impacto

Additivo y retrocompatible: si todos los ids son nuevos (o no había estado previo), el comportamiento es el
de hoy. Mejora la UX de cualquier UI que edite el árbol en vivo (la base de M7 de Sentry).
