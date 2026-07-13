# FR-023 — Button: estado toggle (pressed) + `SetIcon` post-Create

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/components/Button.lua`
**Tipo:** Feature Request
**Prioridad:** Media — hay workarounds con API pública (`SetVariant`, botones superpuestos)
**Estado:** Implementado en dev (2026-07-12) — decisión del owner: el toggle NO va como config de Button (rompe la taxonomía shadcn); implementado como **componente nuevo `Craft.Toggle`** (shadcn `Toggle`/Radix: hermano de Button, variants default/outline), reutilizando el chasis de Button + el patrón fill signal→tween de ToggleGroup. Corrección de spec del owner contra el estilo Lyra real (`style-lyra.css` `.cn-toggle`): el pressed pinta con **`muted`** (mismo token que hover y que el fill de ToggleGroup) — el `accent` que decía el registry base new-york-v4 no es el norte de Craft; el texto no cambia de color en pressed. `Button:SetIcon(name)` aceptado tal cual (mutar `_cfg.icon` + re-pase de tema). Spec: `docs/components/toggle.md`; tests: `tests/toggle_spec.lua` (14) + 3 specs de `SetIcon` en `tests/button_spec.lua`.

---

## Problema

Dos huecos para botones icon-only que representan ESTADO, no solo acción:

1. **Sin estado pressed/toggle.** `Button` solo tiene el efecto momentáneo de `_onMouseDown`
   (traslación -1px, `Button.lua:372-375`). No hay forma soportada de dejar un botón
   "presionado" (estilo shadcn `Toggle` / `aria-pressed`). `ToggleGroup` no sirve para toggles
   INDEPENDIENTES: es selección única por diseño (`ToggleGroup.lua:6`).
2. **Sin `SetIcon`.** El icono solo se fija en `Create` (`config.icon`); la superficie pública
   (`Button.lua:383-422`) expone `SetText`/`SetEnabled`/`SetVariant`/`SetSize` pero no permite
   cambiar el icono después — un botón que alterna icono según estado no se puede hacer sin
   mutar `_cfg` a mano.

## Caso de uso (Coffer)

Decisión del owner (ADR-0004): la toolbar del MainFrame lleva **un toggle icon-only por window
de banco** (`landmark`/`vault`/`users`) — presionado = window abierto, click abre/cierra; son
independientes entre sí (puede haber 0..3 presionados) → `ToggleGroup` no aplica. Y cada header
lleva **UN botón grid/list que alterna su icono** (▦/☰, FR-022) al click.

## Solución propuesta

- `Button:Create(parent, { ..., toggle = true, pressed = false, onToggle = fn(pressed) })` —
  o el subset que Craft prefiera: basta un `SetPressed(bool)` + estilo visual de presionado
  (p. ej. el fill de segmento activo de ToggleGroup) para que el consumidor cablee el resto.
- `Button:SetIcon(name)` — re-pinta con el icono nuevo (el pintado ya relee `_cfg.icon` en
  `_positionChildren`/`_applyTheme`, `Button.lua:328`; faltaría solo el setter público).

## Workaround actual (Coffer)

- Pressed: alternar `SetVariant("secondary"/"ghost")` — funciona pero el estilo "presionado"
  queda a criterio del consumidor y no anima como el fill de ToggleGroup.
- Icono alternante: DOS botones superpuestos en un host frame y swap de visibilidad.

## Impacto

Aditivo (config opcional + dos métodos). Sin cambio para consumidores actuales.
