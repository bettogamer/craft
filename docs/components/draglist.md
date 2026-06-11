# Component: DragList

> **Craft-original** — shadcn **no** tiene lista reordenable / sortable. Lista vertical de filas
> con handle `grip-vertical` para reordenar por arrastre. WoW frame base: `Frame` por fila +
> `Button` (grip) con `RegisterForDrag`.

## Propósito

Reordenar por prioridad: listas de enrutado, condiciones, multi-triggers. El usuario arrastra
el handle de una fila y la lista se reordena en vivo; al soltar se confirma el nuevo orden.

## Jerarquía de frames WoW

```
draglist.frame              (Frame — alto = n·36 + (n-1)·4)
└── row[i]                   (Frame — alto 36; se reposiciona al reordenar, no se recrea)
    ├── dragBg               (Texture BACKGROUND — bg-muted, visible al arrastrar "lift")
    ├── divider              (Texture BORDER 1px — border-b entre filas)
    ├── grip (Button)        (handle grip-vertical, RegisterForDrag "LeftButton")
    │   └── gripTex          (Texture — icono grip-vertical, muted→foreground en hover)
    └── content (Frame)      (área del consumidor; renderRow la rellena, o label por defecto)
```

## Dimensiones / tokens

| Elemento | Valor / Token |
|---|---|
| Alto de fila | 36px |
| Gap entre filas | 4px |
| Grip | 16px (`grip-vertical`), padding izq 8px |
| Gap grip→content | 8px |
| Font label (default) | `t.font`, 12px |
| Grip | `t.mutedForeground` → `t.foreground` (hover) |
| Divider | 1px `t.border` |
| Lift (arrastrando) | `t.muted` + `SetAlpha(0.95)` + frame level +10 |

## Mecánica de drag (Craft-original)

- El grip usa `RegisterForDrag("LeftButton")` → `OnDragStart`/`OnDragStop`.
- Durante el arrastre, un `OnUpdate` en el frame raíz hace que la fila arrastrada **siga el
  cursor** (`GetCursorPosition() / UIParent:GetEffectiveScale()` vs `frame:GetTop()`), **no** se
  usa `StartMoving` (que movería el frame fuera de la lista).
- El **slot destino** se deriva de la banda del cursor (`floor(relY / step)`); si cambia, la
  fila se reinserta en `_order` y el resto se re-anclan → **reorden en vivo**.
- Al soltar, la fila encaja en su slot y, si el orden cambió, se reconstruye `items` y se
  dispara `onReorder(items)`.
- Las filas **no se recrean** al reordenar (solo se reposicionan), así que cada fila queda
  ligada a su item: `renderRow(content, item, index)` corre **una vez** por item al construir.

## Config — `Create(parent, config)`

| Clave | Tipo | Default | Descripción |
|---|---|---|---|
| `items` | table | `{}` | Lista de datos (tabla u otro); el orden inicial |
| `renderRow` | function | nil | `fn(contentFrame, item, index)` rellena la fila; si falta, label por defecto (`item.label` o `tostring`) |
| `onReorder` | function | nil | `fn(items)` al soltar si el orden cambió; `items` en el nuevo orden |
| `width` | number | 300 | Ancho de la lista/filas |
| `disabled` | boolean | false | Deshabilita el arrastre |

## API pública

| Método | Descripción |
|---|---|
| `SetItems(items)` | Reconstruye la lista con nuevos datos |
| `GetItems()` | Items en el orden actual |
| `SetEnabled(bool)` | Habilita/deshabilita el arrastre |
| `GetFrame()` | Frame raíz |

## Notas de implementación

- **Sin animación de "hueco"**: el reorden mueve las filas instantáneamente al cruzar bandas
  (no hay tween del gap). Suficiente para el caso de uso; animar requeriría interpolar posiciones.
- **Scroll**: la lista crece en alto con los items. Para muchas filas, envolver en `Craft.Scroll`
  desde el consumidor (DragList no scrollea por sí mismo). El cálculo de slot usa `frame:GetTop()`,
  válido dentro de un scroll child mientras esté visible.
- **`renderRow` corre una vez** — no re-renderizar por índice durante el drag; la fila lleva su item.
