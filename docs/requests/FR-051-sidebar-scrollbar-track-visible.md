# FR-051 — `Craft.Sidebar`: track del scrollbar visible sin overflow (divergencia spec↔código)

**Reportado por:** owner, verificación in-game de la demo Card + Sidebar (2026-07-19)
**Componente:** `Craft/components/Sidebar.lua` (`_updateSbar`) — scrollbar custom de 4px
**Tipo:** Divergencia spec↔código (el spec ya define el comportamiento correcto)
**Prioridad:** Media (línea vertical fantasma en el borde derecho de TODO sidebar sin overflow)
**Estado:** ✅ Implementado (2026-07-19) — `_updateSbar` oculta/muestra `_sbarFrame` completo
(track + thumb) según `childH > viewH`, como ya decía el spec. 2 tests de visibilidad (suite 379).

---

## Problema

El **track** del scrollbar (`_sbarTrack`, `t.sidebarForeground` a=0.08, alto completo) se pinta
**siempre**, aunque el contenido quepa y no haya nada que scrollear. Cuando no hay overflow solo se
oculta el **thumb** — la franja tenue de 4px queda visible en el borde derecho (visto in-game en la
demo Card + Sidebar, que no tiene overflow).

**Evidencia:**
- Código: [`Sidebar.lua` `_updateSbar` (~314-318)](../../Craft/components/Sidebar.lua#L314-L318) —
  `if childH <= viewH or trackH <= 0 then self._sbarThumb:Hide(); return end` → solo el thumb;
  `_sbarFrame`/`_sbarTrack` nunca se ocultan.
- Spec: [`docs/components/sidebar.md` § Scrollbar custom](../components/sidebar.md) — dice
  explícitamente "**Solo es visible cuando `childH > viewH`**" y su snippet usa
  `self._sbarFrame:Show()/Hide()`. El código nunca implementó el Hide del frame.

## Referencia shadcn

`SidebarContent` es `overflow-auto`: la barra de scroll **solo aparece cuando hay overflow**
(comportamiento nativo del navegador). Un track permanente no existe en Lyra.

> Nota de diseño (pregunta del owner): el ScrollFrame interno **sí es intencional** — replica
> `SidebarContent` con `overflow-auto` de shadcn (la navegación scrollea de forma independiente
> del resto de la UI cuando la lista supera la altura del sidebar). Lo no intencional es
> únicamente el track siempre visible.

## Solución propuesta

En `_updateSbar`, ocultar/mostrar el **frame completo** (track + thumb), como ya dice el spec:

```lua
if childH <= viewH or trackH <= 0 then
    self._sbarFrame:Hide()
    return
end
self._sbarFrame:Show()
```

Sin cambios de API. Opcional (fuera de MVP): reclamar los 4px de `SBAR_W` en el ancho del `_child`
cuando no hay overflow — hoy el gap se reserva siempre; mantenerlo evita reflow al aparecer el
scrollbar (mismo trade-off que `scrollbar-gutter: stable`).

- Tests en `tests/sidebar_spec.lua`: `_sbarFrame` oculto cuando `childH <= viewH`, visible con
  overflow (forzando alturas en el mock).

## Referencias

- Spec: [`docs/components/sidebar.md`](../components/sidebar.md) (§ Scrollbar custom — snippet de visibilidad)
