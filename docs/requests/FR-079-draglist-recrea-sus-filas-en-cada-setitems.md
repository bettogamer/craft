# FR-079 — `Craft.DragList`: `SetItems` recrea todas sus filas desde cero, así que refrescar la lista fuga frames (y no da forma de destruir lo que el consumidor puso en ellas)

**Reportado por:** Coffer (addon de bolsas para WoW 12.1) — Ajustes ▸ Categorías, la lista maestra
de categorías. Salió de una investigación de memoria del 2026-09-02 (el owner: *"cada vez que
refresco coffer, va aumentando su uso de memoria"*).
**Componente:** [`Craft/components/DragList.lua`](../../Craft/components/DragList.lua) —
`DragList:_build` / `DragList:SetItems`
**Tipo:** Bug (fuga de frames dentro de la librería) + hueco de API (no hay gancho para destruir
el contenido que puso el consumidor)
**Prioridad:** Media-alta. La fuga es silenciosa y proporcional al USO: no crece con el tiempo
sino con cada refresco de la lista, que en un buscador es cada pulsación de tecla.
**Estado:** **CERRADO** (2026-09-02) — implementadas **A** y **B**.

---

## Problema

`SetItems` llama a `_build`, y `_build` **no reusa nada**:

```lua
function DragList:_build()
    if self._order then
        for _, row in ipairs(self._order) do row:Hide(); row:SetParent(nil) end
    end
    self._order = {}
    ...
    for i, item in ipairs(self._items) do
        local row = CreateFrame("Frame", nil, self.frame)   -- ← fila NUEVA en cada SetItems
        row.dragBg  = row:CreateTexture(...)
        row.divider = row:CreateTexture(...)
        local grip  = CreateFrame("Button", nil, row)
        local gtex  = grip:CreateTexture(...)
        ...
        if self._cfg.renderRow then self._cfg.renderRow(content, item, i) end
```

Las filas anteriores se **abandonan** (`Hide()` + `SetParent(nil)`), y en WoW un frame no se
destruye nunca: se quedan vivas para siempre. Cada `SetItems` de una lista de N elementos deja
atrás N frames, N botones de grip y 3N texturas.

El comentario de la cabecera dice *"`renderRow(content, item, index)` runs once per item at build
time"*, que es cierto por build — pero **`_build` corre en cada `SetItems`**, y `SetItems` es la
API normal para refrescar la lista. En Coffer eso son: cada clic en una categoría, cada
renombrado, cada reorden… **y cada pulsación en la caja de búsqueda del maestro**, que es lo que
lo convierte en un goteo constante en vez de una anécdota.

### La segunda mitad: el consumidor tampoco puede limpiar lo suyo

`renderRow(content, item, i)` es donde el consumidor pinta la fila, y ahí es normal crear
componentes Craft (Coffer pone un `Craft.Label` con el nombre de la categoría). Como cada build
trae filas nuevas, esos componentes también son nuevos — **y no hay ningún gancho para destruir
los de la tanda anterior**: ni `onRowReleased`, ni `destroyRow`, ni acceso a las filas viejas.

Eso importa más de lo que parece porque todo componente Craft se registra en `Theme._listeners`,
un array fuerte que solo `Destroy()` vacía (contrato de `theme/Theme.lua:84`). Coffer lo tapó
llevando su propia lista de etiquetas y destruyéndolas antes de cada `SetItems`, pero es un apaño
del consumidor sobre un ciclo de vida que es de la librería: **lo que Craft crea dentro de
`_build` sigue fugando y el consumidor no puede tocarlo.**

## Comparación con `Craft.Menu`, que sí lo hace bien

`Menu:_buildRows` (`components/Menu.lua:277`) **poolea**: reusa `self._items[i]`, crea solo lo que
falta y oculta lo que sobra.

```lua
for i, cfg in ipairs(items) do
    local item = self._items[i]
    if not item then item = self:_makeRow(); self._items[i] = item end
    self:_renderRow(item, cfg)
    ...
end
for i = #items + 1, #self._items do self._items[i].row:Hide() end
```

Los dos componentes resuelven el mismo problema —"re-sembrar una lista de filas"— y solo uno lo
hace sin fugar. La inconsistencia es lo que hace que el consumidor no sospeche: si `Menu:SetItems`
es barato, `DragList:SetItems` parece barato.

## Qué pedimos

**A. Que `_build` poolee, como hace `Menu`.** Reusar las filas existentes, crear solo las que
falten y ocultar las sobrantes. Cierra la fuga de frames sin cambiar la API.

**B. Un gancho de reciclado para el contenido del consumidor.** Con el pool, `renderRow` pasaría a
recibir un `content` **reusado** que aún trae lo pintado en la tanda anterior — así que hace falta
o bien un `onRowReleased(content, item)` que el consumidor use para destruir lo suyo, o bien
documentar explícitamente que `renderRow` debe ser idempotente sobre un `content` reusado
(y entonces el consumidor guarda sus componentes en el propio `content` y los actualiza en vez de
recrearlos, que probablemente es el contrato más limpio).

Lo importante es que **el contrato quede dicho**: hoy no hay forma correcta de escribir un
`renderRow` que cree componentes, y nada avisa de ello.

## Nota de alcance

Esto NO es la causa del susto que abrió la investigación —el addon retenía 4,5 MB en reposo y
6,2 MB con toda la interfaz construida; lo que el panel de memoria enseñaba como 46-72 MB era
basura pendiente de recoger. Pero al auditar los sitios sí apareció esto, y es una fuga de verdad
dentro de la librería, no del consumidor.

Relacionado: la misma investigación sugiere un **`Craft.scope()`** equivalente al `Weave.scope()`
—que colecciona todo componente creado dentro de su `:run()` y los destruye juntos— porque el
idioma de WoW (ocultar la generación vieja y construir una nueva) hace que "crear componentes en
un bucle de reconstrucción" sea el caso NORMAL, y hoy cada consumidor se escribe su propia lista
`owned` a mano. Va aparte si el owner lo quiere valorar.


---

## Resolución (2026-09-02)

**A — pool.** `_build` reusa por índice, con la misma forma que `Menu:_buildRows`. La lista
mantiene ahora **dos** arrays: `self._rows` es el **pool** (orden de creación, estable, nunca se
reordena) y `self._order` es el **orden visual** (referencias al pool). La separación es lo que
hace que el pool y el drag convivan: `_onDragUpdate` sigue reordenando `_order` a su gusto y el
pool no se entera. La creación de una fila salió a `DragList:_makeRow()` (los `SetScript` del
grip capturan `row`, cuya identidad ya es estable de por vida). Las filas sobrantes se ocultan y
se quedan en el pool; un `SetItems` más largo las recicla en vez de crear otras.

**B — gancho de reciclado.** Nueva clave de config `onRowReleased(content, prevItem)`, invocada
por `DragList:_releaseRow(row)`:

- antes de re-renderizar una fila que ya tenía contenido de otro item,
- antes de ocultar una fila sobrante,
- una vez por fila viva en `DragList:Destroy()`.

`row.rendered` guarda el item con el que se renderizó la fila, así que una fila nunca se libera
dos veces seguidas ni se libera sin haberse renderizado.

**El contrato queda dicho** en `docs/components/draglist.md` → sección *Ciclo de vida de la fila*:
`renderRow` corre más de una vez sobre el mismo `content`, y hay **dos** formas correctas de
escribirlo — idempotente (guardar los componentes en el propio `content` y actualizarlos;
recomendada, es la que no necesita ningún gancho) o crear/destruir con `onRowReleased`. Se
explica también el *por qué*: `Theme._listeners` retiene todo componente hasta su `Destroy()`.

**Tests:** `tests/draglist_spec.lua` (13) — no existía spec propio de DragList. Cubren identidad
de fila entre `SetItems`, que el pool no crece al encoger la lista y crece exactamente lo que
falta al crecer, reciclado del `FontString` por defecto, el orden y número de llamadas a
`onRowReleased` (incluido el caso `Destroy`), y que sin `onRowReleased` el pool sigue funcionando.

**Compatibilidad:** aditivo. Un consumidor que hoy no crea nada en `renderRow` no nota el cambio;
uno que sí crea componentes tenía ya la fuga y ahora tiene cómo cerrarla. Coffer puede tirar su
lista `owned` de etiquetas y pasar a la vía idempotente (o a `onRowReleased`).

**No incluido:** el `Craft.scope()` de la nota final va aparte — ver **FR-082**.
