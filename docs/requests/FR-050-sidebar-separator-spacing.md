# FR-050 — `Craft.Sidebar`: separador pegado al último item del grupo anterior

**Reportado por:** owner, verificación in-game de la demo Card + Sidebar (2026-07-19)
**Componente:** `Craft/components/Sidebar.lua` (`_rebuildLayout`) — shadcn: `.cn-sidebar-separator`
**Tipo:** Bug de layout (espaciado vertical asimétrico)
**Prioridad:** Media (visible en cualquier sidebar con `AddSeparator` entre grupos)
**Estado:** ✅ Implementado (2026-07-19) — `_rebuildLayout`: el separador cierra el grupo con
`pad` antes y resetea `started` (el bloque siguiente abre con un solo `pad`) → 8px/8px como Lyra.
Spec § Group padding actualizado + 2 tests de posiciones (suite 379).

---

## Problema

El separador horizontal queda **pegado (0px) al último item del grupo anterior**, mientras que
hacia abajo el siguiente section header agrega su apertura de grupo completa (16px). El espaciado
queda asimétrico: `item │sep ················ 16px ─ header`.

**Evidencia:** [`Sidebar.lua` `_rebuildLayout`, rama separator (~488-490)](../../Craft/components/Sidebar.lua#L488-L490)
— el bloque de "Group vertical padding" del layout solo suma padding antes de **sections**
(`pad*2` entre grupos) o al abrir el primer bloque; un entry `separator` no suma nada antes de
posicionarse → cae inmediatamente después del item previo. Visto in-game en la demo
(`Craft_Browser/pages/Panel.lua:652`): el separador toca el fondo del item activo "Spending".

## Referencia Lyra

`.cn-sidebar-separator { bg-sidebar-border mx-2 }` — sin margen vertical propio, pero en shadcn el
separador vive **entre dos `SidebarGroup` con `p-2`**: el grupo anterior aporta 8px de padding
inferior y el siguiente 8px superior → **8px arriba / 8px abajo** del separador, simétrico.

## Solución propuesta

En `_rebuildLayout`, tratar el separador como **cierre de grupo**:

- Antes de posicionarlo: `cursorY += pad` (8px — cierre `p-2` del grupo anterior), solo si ya hay
  un bloque abierto (`started`).
- Después de posicionarlo: `started = false`, de modo que el siguiente entry (section o item)
  **abra** su bloque con un solo `pad` (8px) en vez del `pad*2` de sección consecutiva.

Resultado: `item ─ 8px ─ separador(1px) ─ 8px ─ header`, como Lyra. Sin cambios de API.

- Tests en `tests/sidebar_spec.lua`: posiciones relativas item→separador→header (gap 8/8) vía
  los puntos del mock (`_pointsByAnchor`).
- Spec `docs/components/sidebar.md`: documentar el espaciado del separador en "Group padding".

## Referencias

- Spec: [`docs/components/sidebar.md`](../components/sidebar.md) (§ Group padding `p-2`)
- CSS Lyra: `.cn-sidebar-separator` en [`docs/reference/lyra-components.css`](../reference/lyra-components.css)
