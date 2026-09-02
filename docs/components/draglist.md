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
└── row[i]                   (Frame — alto 36; se reposiciona al reordenar y se REUSA en cada rebuild)
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
| `renderRow` | function | nil | `fn(contentFrame, item, index)` rellena la fila; si falta, label por defecto (`item.label` o `tostring`). **`contentFrame` puede venir RECICLADO** — ver *Ciclo de vida de la fila* |
| `onRowReleased` | function | nil | `fn(contentFrame, prevItem)` justo antes de que esa fila se reutilice para otro item, se oculte por sobrante o se suelte en `Destroy()`. Es donde el consumidor destruye lo que creó en `renderRow` |
| `onReorder` | function | nil | `fn(items)` al soltar si el orden cambió; `items` en el nuevo orden |
| `width` | number | 300 | Ancho de la lista/filas |
| `disabled` | boolean | false | Deshabilita el arrastre |

> **Props reactivas (ADR-0013):** `items` y `disabled` aceptan señal/computed. `items` es
> **two-way**: reordenar escribe el nuevo orden de vuelta en la señal (si es escribible),
> antes de `onReorder`; un guard de eco por identidad de tabla evita el rebuild que dispararía
> ese `:set`. `disabled` bindea vía `SetEnabled`.

## Ciclo de vida de la fila (FR-079)

Las filas están **pooleadas**, igual que en `Craft.Menu`: `self._rows` es el pool (orden de
creación, nunca se reordena) y `self._order` es el orden visual (referencias al pool). Un
`SetItems` **reutiliza** los frames existentes, crea solo los que falten y oculta los sobrantes.
Los frames de WoW no se destruyen nunca, así que reconstruir tirando las filas fugaba N frames,
N botones y 3N texturas por refresco.

Consecuencia para el consumidor: **`renderRow` se ejecuta más de una vez sobre el mismo
`contentFrame`**. Hay dos formas correctas de escribirlo, y hay que elegir una:

1. **`renderRow` idempotente** (recomendado): guardar los componentes en el propio `content`
   (`content._label = content._label or Craft.Label:Create(content, …)`) y **actualizarlos** en
   vez de recrearlos. Sin `onRowReleased`, sin listas `owned` a mano.
2. **`onRowReleased(content, prevItem)`**: crear en `renderRow` y destruir en `onRowReleased`.
   Craft lo llama antes de re-renderizar la fila, antes de ocultarla como sobrante y una vez por
   fila viva en `Destroy()`; nunca dos veces seguidas para el mismo render.

> **Por qué importa:** todo componente Craft se registra en `Theme._listeners`, un array fuerte
> que solo `Destroy()` vacía. Un `renderRow` que crea un `Craft.Label` en cada refresco sin
> ninguna de las dos vías fuga un listener por fila y por refresco.

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
- **`renderRow` NO se re-ejecuta durante el drag** — el reorden solo reposiciona filas y cada
  fila lleva su item. Sí se re-ejecuta en cada `SetItems` (rebuild), sobre un `content` reciclado:
  ver *Ciclo de vida de la fila*.
