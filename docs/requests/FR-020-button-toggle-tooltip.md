# FR-020 — Button/ToggleGroup: tooltip nativo (para botones icon-only)

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/components/Button.lua`, `Craft/components/ToggleGroup.lua`
**Tipo:** Feature Request
**Prioridad:** Media — hay workaround razonable (envolver con `Craft.Tooltip` a mano)
**Estado:** Implementado en `dev` (2026-07-12). Config `tooltip` en `Button:Create` y por segmento en `ToggleGroup` (e.g. `{ id, icon, tooltip }`); tooltip visible aun con disabled. Suite: 198 tests.

---

## Problema

Los botones icon-only (`size = "icon"/"icon-xs"/...`, `Button.lua:22-26`) no tienen forma de
comunicar su nombre: ni `Button:Create` (config `Button.lua:42-51`) ni los segmentos de
`ToggleGroup` (`seg.icon`, `ToggleGroup.lua:173`) aceptan un parámetro de tooltip. Todo
consumidor que use iconos sin label (patrón que Craft mismo fomenta con los tamaños `icon-*`)
tiene que cablear `OnEnter`/`OnLeave` + `Craft.Tooltip` a mano por cada botón.

## Caso de uso (Coffer)

Decisión del owner (ADR-0004): la toolbar del MainFrame lleva un toggle icon-only por window de
banco (`landmark`/`vault`/`users`) "con los nombres en tooltips". También aplica al toggle
grid/list y a futuros botones del footer (Sell Trash, Disenchant — iconos de FR-017).

## Solución propuesta

- `Button:Create(parent, { ..., tooltip = "Banco" })` — muestra `Craft.Tooltip` on hover,
  anclado al botón; nil = sin tooltip (comportamiento actual).
- `ToggleGroup`: `tooltip` por segmento (`{ id = "bank", icon = "landmark", tooltip = "Banco" }`).
- Respetar `disabled` (mostrar tooltip igualmente o no — a criterio de Craft; Coffer prefiere
  mostrarlo también deshabilitado, explica por qué está gris).

## Workaround actual (Coffer)

Envolver cada botón con scripts `OnEnter`/`OnLeave` sobre `GetFrame()` invocando
`Craft.Tooltip`. Funciona, pero es boilerplate repetido en cada consumidor y por cada botón.

## Impacto

Aditivo (key de config opcional, default sin tooltip). Sin cambio visual ni de API para
consumidores actuales.
