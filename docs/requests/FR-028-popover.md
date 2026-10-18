# FR-028 — Popover: contenedor flotante anclado genérico

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** nuevo — `Craft/components/Popover.lua` (shadcn: Popover)
**Tipo:** Feature Request
**Prioridad:** Baja-media — infraestructura: FR-027 se construye encima; editores inline de Categorías (M8 Coffer)
**Estado:** ✅ Implementado (2026-07-13, dev — pendiente de release): `Craft/components/Popover.lua`,
spec `docs/components/popover.md`, 19 tests. `Create(config)` SIN `parent` (como Menu — el panel
vive en UIParent/TOOLTIP); extras sobre lo propuesto: `padding` (p-0 para Combobox), `SetWidth`,
`Relayout`, `Toggle`. Sin flip de lado: se reusó la estrategia real de Menu (`SetClampedToScreen`).
FR-027 ya se construyó encima. El refactor de Menu/Select sobre Popover sigue fuera de alcance.

---

## Problema

Craft tiene dos flotantes especializados (`Menu` = lista de acciones, `Dialog` = modal
centrado) pero no el **contenedor anclado genérico** intermedio: un panel no-modal, anclado a
un trigger, que cierra al click-fuera/Esc, con contenido arbitrario. Cada componente que lo
necesita (Select, Menu, Tooltip) reimplementa su propio anclaje/z-order/cierre.

Casos de Coffer (Settings M8):

1. **Base de FR-027 (Combobox)**: el panel buscable ES un Popover con Input+lista dentro.
2. **Editores inline del editor de categorías**: editar una regla-chip existente (p. ej.
   cambiar "incluye"↔"excluye" de una regla de Nombre) sin abrir un Dialog modal — un
   Popover chico anclado al chip con 2-3 controles.

## Solución propuesta

- `Craft.Popover:Create(parent, config)`:
  - `anchor` (frame trigger), `side`/`align` (top/bottom/left/right + start/center/end,
    como shadcn), `offset`.
  - `GetContent()` → frame contenedor para armar contenido arbitrario (mismo contrato que
    `Window:GetContent()`).
  - `open` signal two-way; cierre por click-fuera y Esc; flip automático si no entra en
    pantalla (reusar la lógica de Menu si ya la tiene).
  - Z-order/strata por encima de la ventana de settings (conviven con Dialog).
- Refactor opcional posterior: Menu/Select/Combobox montados sobre Popover (fuera del alcance
  de este FR; pedirlo solo si sale gratis).

## Caso de uso (Coffer)

Plan M8 rediseñado (`SortedBags/docs/plan-m8-settings.md`): FR-027 (fuentes LSM, añadir
regla) + edición inline de reglas en Categorías.

## Workaround actual (Coffer)

`Dialog` modal para editar una regla (pesado para 2 controles) o Menu con acciones fijas.

## Impacto

Componente nuevo, aditivo; a futuro reduce duplicación interna (Menu/Select comparten la
pieza). Riesgo bajo.
