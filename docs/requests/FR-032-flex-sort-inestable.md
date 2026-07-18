# FR-032 — `Craft.Flex:Layout()`: el sort por `order` NO es estable (revuelve items)

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/layout/Flex.lua` (`Layout()`, paso 1 "ordenar por order")
**Tipo:** Bug
**Prioridad:** Media — cualquier consumidor sin `order` explícito puede ver el layout
revuelto al crecer la lista de items; workaround simple pero fácil de no conocer
**Estado:** Resuelto (dev) — sort decorado con `_seq` en `Flex:Layout()`; cubierto por
`tests/flex_spec.lua` (reproduce el revuelto 9→11 sin el fix). Pendiente release/re-vendoreo.

---

## Problema

`Flex:Layout()` ordena los items así (Flex.lua ~110):

```lua
-- 1. Ordenar items por order (stably)
table.sort(sorted, function(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return false  -- stable: preserve insertion order
end)
```

El comentario promete estabilidad, pero **`table.sort` de Lua es quicksort y NO es
estable** — devolver `false` para iguales no preserva el orden de inserción; solo evita
el error "invalid order function". Con varios items compartiendo el `order` default (0),
el orden visual resultante depende del tamaño del array: con pocos items suele coincidir
con la inserción (por eso pasa desapercibido), y al añadir items la permutación cambia.

## Síntoma observado (Coffer, in-game 12.0.7, 2026-07-17)

La página Settings > Features (columna Flex de 9 items sin `order`, que siempre había
rendido en orden de inserción) ganó 2 filas más y quedó **completamente revuelta**:
cabeceras de sección separadas de sus filas, checkboxes intercalados en otra sección.
Las filas internas (5 items) también permutaron sus checkboxes. Screenshot del owner
disponible en el hilo de Coffer.

## Workaround actual (Coffer)

`order` explícito (10, 20, 30…) en **todos** los `Flex:Add` de SettingsWin.lua
(commit `dev` 2026-07-17). Frágil como guideline: nada avisa si un Add nuevo lo omite.

## Solución propuesta

Sort decorado con el índice de inserción (estabilidad real, coste O(n) extra):

```lua
for i, item in ipairs(self._items) do
    sorted[i] = item
    item._seq = i
end
table.sort(sorted, function(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a._seq < b._seq
end)
```

Con esto `order` vuelve a ser lo que documenta la API: un override opcional sobre el
orden de inserción (semántica CSS flexbox `order`).

## Impacto

Solo `Layout()`; sin API nueva ni cambios de comportamiento para quien ya pasa `order`
explícito. Los consumidores que dependían (sin saberlo) del orden de inserción quedan
corregidos, no rotos.
