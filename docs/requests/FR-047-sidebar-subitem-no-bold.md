# FR-047 — `Craft.Sidebar`: sub-item activo no debe ir en negrita

**Reportado por:** shadcn-auditor de `Craft.Sidebar` contra CSS Lyra (2026-07-19), al auditar el
demo "Card + Sidebar — Financial dashboard nav"
**Componente:** `Craft/components/Sidebar.lua` (shadcn: `sidebar` — `.cn-sidebar-menu-sub-button`)
**Tipo:** Fidelidad (font-weight incorrecto en un estado de un componente existente)
**Prioridad:** Media (visible en cualquier árbol colapsable con item anidado activo)
**Estado:** 🅿️ Propuesto (2026-07-19). No implementado.

---

## Problema

`_colorItem` aplica `t.fontMedium` a **cualquier** item activo sin distinguir profundidad. Pero el
CSS Lyra real solo define `font-weight: medium` para `data-active` en el nivel raíz
(`.cn-sidebar-menu-button`), **NO** en el sub-button anidado (`.cn-sidebar-menu-sub-button`):

```css
/* docs/reference/lyra-components.css */
.cn-sidebar-menu-button:where([data-active]…)     { background-color: var(--sidebar-accent); font-weight: var(--font-weight-medium,500); color: … }  /* CON font-weight */
.cn-sidebar-menu-sub-button:where([data-active]…) { background-color: var(--sidebar-accent);                                             color: … }  /* SIN font-weight */
```

**Evidencia (Craft):** [`Sidebar.lua:373-385`](../../Craft/components/Sidebar.lua#L373-L385)
(`_colorItem`, rama `isActive`) — `Craft.Theme.applyFont(entry.labelFs, t.fontMedium or t.font,
ITEM_FONT)` se ejecuta igual para `depth==0` y `depth>0`.

**Escenario de fallo:** un árbol con `children` (FR-008) donde se selecciona un item anidado
(`SetActiveItem("aura1")`, depth>0) → su label sale en negrita cuando Lyra lo mantiene en peso
regular. La cabecera raíz colapsable, si es la activa, sí debe ir en medium.

## Solución propuesta

En `_colorItem`, condicionar el peso de la fuente a la profundidad del item:

- `depth == 0` y activo → `t.fontMedium` (comportamiento actual, correcto).
- `depth > 0` → `t.font` **siempre** (activo o no).

Requiere que `_colorItem` conozca la profundidad del `entry` — verificar si `entry.depth` ya se
guarda en `AddItem` (se pasa `depth` como parámetro); si no está persistido en el `entry`, añadirlo.

## Alcance mínimo (MVP)

- Solo el peso de fuente del sub-item activo. Sin cambios de API pública.
- El fondo `t.sidebarAccent` del sub-item activo se mantiene (eso Lyra SÍ lo aplica).

## Consideraciones de implementación

- **Tests:** añadir a `tests/sidebar_spec.lua` — un item `depth>0` activo usa `t.font` (no
  `t.fontMedium`); un item raíz activo sigue usando `t.fontMedium`.
- **Spec:** ya corregido en `docs/components/sidebar.md` (la fila "Sub-button/Active" nunca listó
  font-medium; se añadió nota explícita en §"Item activo en negrita").

## Referencias

- Spec: [`docs/components/sidebar.md`](../components/sidebar.md)
- CSS Lyra: `.cn-sidebar-menu-sub-button` en [`docs/reference/lyra-components.css`](../reference/lyra-components.css)
- Extensión de árbol: FR-008 (children/colapsable)
