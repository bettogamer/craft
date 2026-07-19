# FR-049 — `Craft.Sidebar`: chevron del árbol a 16px (o documentar 14px)

**Reportado por:** shadcn-auditor de `Craft.Sidebar` (2026-07-19)
**Componente:** `Craft/components/Sidebar.lua` (extensión propia FR-008 — árbol colapsable)
**Tipo:** Consistencia interna (tamaño de icono)
**Prioridad:** Baja (cosmético)
**Estado:** 🅿️ Propuesto (2026-07-19). No implementado.

---

## Problema

El chevron del árbol colapsable usa `CHEV_SIZE = 14` mientras el resto de iconos de fila del
Sidebar usan 16px (`ICON_SIZE = 16`, convención Lyra `[&_svg]:size-4` = 16px para todos los `<svg>`
de la fila).

**Evidencia:** [`Sidebar.lua:41-42`](../../Craft/components/Sidebar.lua#L41-L42) (`ICON_SIZE = 16`
vs `CHEV_SIZE = 14`).

**Contexto:** el árbol colapsable (FR-008) es una extensión propia de Craft — no hay un
`SidebarMenuSub`+chevron formal en el registry vanilla de shadcn con una clase CSS fija citable, así
que esto **no** es una divergencia contra una regla Lyra explícita, sino una **inconsistencia
interna** (14 vs 16) entre iconos hermanos en la misma fila.

## Solución propuesta

Una de dos:

- **Homologar:** `CHEV_SIZE = 16` (igual que `ICON_SIZE`), salvo que 14 sea una decisión deliberada
  de "tightening".
- **Documentar:** si el 14 es intencional (chevron ligeramente más pequeño que el icono principal
  para jerarquía visual), añadir un comentario en la línea que lo justifique, igual que se documentó
  `INDENT` como intencional (línea 43).

## Alcance mínimo (MVP)

- Un solo cambio de constante (`CHEV_SIZE`) o un comentario. Sin API pública ni tests nuevos
  (salvo un assert de tamaño si se quiere blindar).

## Referencias

- Spec: [`docs/components/sidebar.md`](../components/sidebar.md)
- Extensión de árbol: FR-008
