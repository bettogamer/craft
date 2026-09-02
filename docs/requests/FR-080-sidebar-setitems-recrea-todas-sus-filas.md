# FR-080 — `Craft.Sidebar`: `SetItems` recrea todas sus filas desde cero (misma fuga que FR-079, y además es la ruta reactiva)

**Reportado por:** auditoría de memoria de la librería del 2026-09-02, disparada por FR-079
(Coffer: *"cada vez que refresco coffer, va aumentando su uso de memoria"*).
**Componente:** [`Craft/components/Sidebar.lua`](../../Craft/components/Sidebar.lua) —
`Sidebar:SetItems` / `_addItems` / `AddItem` / `AddSection` / `AddSeparator`
**Tipo:** Bug (fuga de frames dentro de la librería)
**Prioridad:** Media-alta. Es exactamente la forma de FR-079, en un componente que además
**tiene bind reactivo de `items`** — así que una señal que cambie fuga una barra lateral entera
por cada cambio, sin que el consumidor haya llamado a nada.
**Estado:** Abierto.

---

## Problema

`SetItems` oculta la generación anterior y construye una nueva sin reusar nada:

```lua
function Sidebar:SetItems(items, opts)
    ...
    for _, e in ipairs(self._sections) do
        if e.frame then e.frame:Hide(); e.frame:ClearAllPoints() end
    end
    self._sections   = {}
    self._itemFrames = {}
    ...
    self:_addItems(self._cfg.items, 0, nil)   -- → AddSection / AddItem, todo nuevo
```

`_addItems` recorre el árbol llamando a `AddSection` y `AddItem`, que **crean** sus regiones cada
vez. Por generación abandonada:

| Builder | Regiones creadas por llamada |
|---|---|
| `AddSection` | 2 (Frame + FontString) |
| `AddItem` | 7 (Button + bg + icono + label + chevron + …) |
| `AddSeparator` | 2 |

Una sidebar de 20 items con 4 secciones son ~148 regiones abandonadas **por refresco**. En WoW
un frame no se destruye nunca: `Hide()` + `ClearAllPoints()` lo saca de la vista, no de la memoria.

`Craft.Menu`, `Craft.Select`, `Craft.Combobox`, `Craft.RadioGroup` y `Craft.ToggleGroup` ya
poolean por índice, y `Craft.DragList` acaba de hacerlo en FR-079. Sidebar es el último que queda
con esta forma.

## Por qué duele más que en DragList

`items` de Sidebar es una **prop reactiva** (ADR-0013, `AGENTS.md` §"Props reactivas"): el bind
llama a `SetItems` en cada emisión de la señal. El CHANGELOG de la 2.4.0 afirma que ese bind
*"re-renderiza reutilizando frames por índice (sin fugas)"* — es cierto para Select/RadioGroup/
ToggleGroup, y **falso para Sidebar y DragList**. Un consumidor que lea esa línea y ponga la
navegación en una señal fuga sin haber escrito una sola llamada a `SetItems`.

## Complicación real (por la que va aparte de FR-079)

Sidebar no es una lista plana: hay **tres tipos de fila** (`section`, `item`, `separator`), el
árbol es **recursivo** (`children`, `depth`), la altura de fila depende del `depth` (`SUB_H` vs
`sz`), y hay estado por fila que hoy vive en el entry (`_open`, chevron, `itemId`, `collapsible`).
Poolear "por índice" a secas mezclaría tipos entre generaciones. Opciones:

- **Pool por tipo** (`self._pool.section / .item / .separator`), consumiendo del pool que toque
  al recorrer el árbol. Es lo más parecido a lo que ya hacen los demás y no cambia la API.
- **Pool único de filas polimórficas** al estilo `Menu:_renderRow` (una fila que se reconfigura a
  separator/item/section). Más limpio a largo plazo, más caro ahora.

En ambos casos hace falta **neutralizar** la fila reciclada como ya hace `Menu:_renderRow`:
ocultar icono/chevron, soltar el tooltip, resetear `_open`, y quitar el `OnClick` viejo (una fila
reciclada NO puede conservar el `onClick` del item anterior).

## Qué pedimos

1. Que `SetItems` **reuse** las filas de la generación anterior (pool por tipo o pool polimórfico).
2. Que las filas sobrantes se **neutralicen** además de ocultarse (callback, tooltip, id, estado
   de expansión), para que un reciclado no arrastre comportamiento del item anterior.
3. Corregir la afirmación "sin fugas" del CHANGELOG 2.4.0 cuando esto cierre.

## Relacionado

- **FR-079** — misma fuga en `Craft.DragList`, ya cerrada; su `_makeRow` / `_build` / `_releaseRow`
  es la plantilla más pequeña de la solución.
- Sidebar **no** expone un `renderRow`, así que la mitad B de FR-079 (`onRowReleased`) no aplica:
  todo lo que hay dentro de una fila lo crea Craft.
