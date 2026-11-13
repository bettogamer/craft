# FR-148 — Tooltips callados mientras hay un `Craft.Menu` abierto

**Solicitante:** Craft (revisión de NaowhForever, 2026-11-13).
**Componente:** `Craft/components/Tooltip.lua` (`Attach`), `Craft/components/Menu.lua`.
**Tipo:** Comportamiento / fidelidad shadcn.
**Prioridad:** Baja.
**Estado:** implementado en dev (2026-11-13, sin release). `Craft.Menu.IsAnyOpen()` /
`Craft.Menu.Contains(frame)` sobre un conjunto de menús abiertos en la tabla COMPARTIDA `Craft`
(todas las copias embebidas lo ven); solo cuenta un menú abierto y con el panel visible (uno recortado
con su ancla, FR-086, no calla nada). `Tooltip.Attach` no abre (ni en el disparo diferido) si hay menú
abierto y el ancla no está dentro. `Tooltip.Show` explícito no se toca. Specs en `tests/menu_spec.lua`;
demo en la página Menu del Browser. **Pendiente in-game.**

---

## Necesidad

Con un menú abierto, pasar el ratón por encima de otros controles con tooltip enseña sus tooltips
encima o al lado del menú. En shadcn esto no pasa: el `DropdownMenu` de Radix es modal por defecto
(bloquea los eventos de puntero fuera del contenido), así que ningún tooltip de fuera se abre
mientras el menú está abierto.

NaowhForever lo hace con una consulta global: `ns.MenuOpen()` (`Shared/UI/Menus.lua:326-329`), que su
helper de tooltip mira antes de mostrar nada (`Shared/UI/Parts.lua:~25`).

## Propuesta

- `Craft.Menu` lleva la cuenta de menús abiertos (raíz y submenús) y expone `Craft.Menu.IsAnyOpen()`.
- `Tooltip.Attach` no abre el tooltip si hay un menú abierto y el ancla **no** está dentro de ese menú
  (los tooltips nativos de las filas del menú, FR-085, siguen funcionando).
- Al cerrarse el menú, no se abre nada solo: el tooltip aparece al siguiente `OnEnter`.

## Criterio de aceptación

- Spec: con un menú abierto, `OnEnter` sobre un control externo con tooltip no lo muestra; dentro del
  menú sí.
- Demo en la página Menu del Browser: botón con tooltip al lado del trigger.

## Referencias

`docs/research/naowhforever-ui-patterns.md` §2 (fila Supresión de tooltips); FR-084/085 (Menu),
FR-081 (Tooltip.Attach).
