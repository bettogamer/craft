# FR-019 — Window: modo headless (sin titleBar) para header propio del consumidor

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/components/Window.lua`
**Tipo:** Feature Request
**Prioridad:** Alta — bloquea el rediseño de ventanas de Coffer (ADR-0004); el workaround es frágil
**Estado:** Implementado en `dev` (2026-07-12). Config `header = false` oculta titleBar, `_content` ancla al TOP; método `EnableDragFrom(region)` registra drag handles. `GetTitleBar()` devuelve nil en headless.

---

## Problema

El rediseño de Coffer (ADR-0004, `SortedBags/docs/adr/0004-windows-independientes-por-banco.md`)
usa un MainFrame + un window independiente por banco, todos con un **header propio más delgado**
(toggle grid/list + toolbar de toggles + título centrado + X) para ahorrar espacio vertical.

`Craft.Window` no lo permite: el `_titleBar` se crea SIEMPRE (`Window.lua:161-222`, sin opción
`header`/`titleBar` en config), `_content` ancla a `self._titleBar, "BOTTOMLEFT"` (`:226`) y
`_layout` suma la altura del titleBar incondicionalmente (`:267-291`). `config.closable` solo
quita el botón X y `config.title = ""` solo vacía el texto — la barra y su altura permanecen.
Ocultar `GetTitleBar()` desde el consumidor deja un hueco y rompe el layout (el content no se
re-ancla).

## Caso de uso (Coffer)

4 ventanas (bolsas + Bank + Warband + Guild) donde cada píxel vertical cuenta; el header de
serie duplica funcionalidad (título/X) pero no puede alojar los controles propios (toggle
grid/list, toolbar de toggles de bancos) ni adelgazarse.

## Solución propuesta

Opción de config, p. ej. `header = false` (default `true`, cero cambio para consumidores
actuales):

- No crear `_titleBar` (o crearlo colapsado y excluido de `_layout`).
- `_content` ancla al TOP del frame.
- El drag pasa a ser responsabilidad del consumidor: exponer un helper tipo
  `Window:EnableDragFrom(region)` (o documentar `StartMoving`/`StopMovingOrSizing` sobre
  `GetFrame()`) para que el header propio arrastre la ventana y siga disparando `onMoved`.
- `closable`/`title` se ignoran con `header = false` (el consumidor pone los suyos).
- ESC/`UISpecialFrames` y el resto del comportamiento no cambian.

## Workaround actual (Coffer)

`GetTitleBar():Hide()` + re-anclar `_content` a mano desde el consumidor — depende de internals
(`_content`, orden de `_layout`) y se rompe con cualquier update de Craft. Documentado como
frágil; Coffer prefiere esperar el FR (implementación del rediseño aún congelada por el owner).

## Impacto

Aditivo (nueva key de config con default = comportamiento actual). Requiere `CRAFT_BUILD` bump
para servirlo al consumidor.
