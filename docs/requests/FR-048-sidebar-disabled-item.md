# FR-048 — `Craft.Sidebar`: estado Disabled de item (implementar o limpiar spec)

**Reportado por:** shadcn-auditor de `Craft.Sidebar` contra CSS Lyra (2026-07-19)
**Componente:** `Craft/components/Sidebar.lua` (shadcn: `sidebar` — `.cn-sidebar-menu-button`
`disabled:pointer-events-none disabled:opacity-50`)
**Tipo:** Divergencia doc↔código (estado documentado sin implementación) — decisión de alcance
**Prioridad:** Media (contrato roto: el spec promete algo que el código no hace)
**Estado:** ✅ Implementado (2026-07-19, Opción A) — `items[i].disabled` en `AddItem` +
`_colorItem`/`_updateChevron` (muted a=0.5, precedencia sobre activo), `EnableMouse(false)`
(chevron incluido), spec actualizado (Estados, Config API, nota de implementación) y 5 tests
en `tests/sidebar_spec.lua` (suite 375).

---

## Problema

El spec promete un estado **Disabled** para items del Sidebar, pero **no existe ninguna
implementación** en el `.lua`:

- Spec: [`docs/components/sidebar.md:177`](../components/sidebar.md#L177) (tabla Estados: "Item |
  Disabled | Texto `t.mutedForeground` con a=0.5, `EnableMouse(false)`") y
  [`:196`](../components/sidebar.md#L196) (mapa de tokens repite lo mismo).
- Código: [`Sidebar.lua` `AddItem` (531-646)](../../Craft/components/Sidebar.lua#L531) — no lee
  `itemConfig.disabled` en ningún punto (búsqueda de `disabl` → 0 coincidencias).
- Además la tabla de **Config API** del mismo spec (campos de `items[i]`) **tampoco** lista
  `disabled` como parámetro → la fila de "Estados" está huérfana, sin contraparte de API.

**Escenario de fallo:** un consumer que siga el spec y pase `{ id="x", label="Y", disabled=true }`
esperando un item no-clickeable con texto atenuado obtiene un item normal, totalmente interactivo y
con color activo/hover.

## Referencia Lyra

`.cn-sidebar-menu-button` incluye `disabled:pointer-events-none disabled:opacity-50` (y la variante
`aria-disabled`). En shadcn el item deshabilitado no recibe eventos y baja a opacidad 50%.

## Decisión requerida (dos caminos)

**Opción A — Implementar** (si Disabled es alcance del componente):
- `AddItem` lee `itemConfig.disabled`. Si true:
  - `itemFrame:EnableMouse(false)` (sin hover/click).
  - Label + icono a `t.mutedForeground` con `a=0.5` (equivalente a `opacity-50` sobre el
    foreground), sin resaltado de hover/activo.
  - No registrar `OnClick`/`OnEnter`/`OnLeave` (o hacerlos no-op).
- Documentar `disabled` en la tabla de Config API de `items[i]`.
- Tests en `tests/sidebar_spec.lua`: item disabled no dispara `OnClick`, usa color muted, mouse off.

**Opción B — Limpiar spec** (si Disabled queda fuera de MVP, como otras omisiones ya listadas en
"Diferencias conocidas vs shadcn"):
- Quitar la fila "Item | Disabled" de la tabla de Estados y la fila de token muted-disabled del
  mapa; moverlo a "Diferencias conocidas" como no-implementado. Trabajo de doc-writer, sin código.

**Recomendación:** decidir según si algún consumer real (Beacon/Coffer) necesita items
deshabilitados en su nav. Si no hay demanda, Opción B (más barata y honesta). Si el diseño lo pide,
Opción A.

## Referencias

- Spec: [`docs/components/sidebar.md`](../components/sidebar.md)
- CSS Lyra: `.cn-sidebar-menu-button` (`disabled:*`) en [`docs/reference/lyra-components.css`](../reference/lyra-components.css)
