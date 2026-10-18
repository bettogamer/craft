# FR-021 — Window: soporte multi-window (raise-on-click + strata configurable)

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/components/Window.lua`
**Tipo:** Feature Request
**Prioridad:** Media — no bloquea (hay workaround), pero el UX multi-window queda pobre sin esto
**Estado:** Implementado en `dev` (2026-07-12). `SetToplevel(true)` en frame raíz; config `strata` (default `"DIALOG"`) → `SetFrameStrata`. Raise-on-click nativo entre ventanas de la misma strata.

---

## Problema

El rediseño de Coffer (ADR-0004) tiene hasta 4 `Craft.Window` visibles a la vez (bolsas +
Bank + Warband + Guild). La multi-instancia funciona (`_instanceCount` genera nombres únicos,
`Window.lua:18,43-44`), pero:

1. **No hay raise-on-click**: el `OnMouseDown` del titleBar solo hace `StartMoving()`
   (`Window.lua:176`) — clickar una ventana parcialmente tapada no la trae al frente. El orden
   Z queda fijado por orden de creación.
2. **Strata fija `"DIALOG"` para todas** (`Window.lua:48`): sin perfil por ventana, cualquier
   diálogo/popup del consumidor compite en la misma strata que las ventanas base.

## Caso de uso (Coffer)

El jugador mueve ítems entre bolsas y 2-3 bancos abiertos; las ventanas se solapan con
frecuencia y espera el comportamiento estándar de ventanas: click = traer al frente.

## Solución propuesta

- **Raise-on-click**: al `OnMouseDown` en cualquier parte del window (no solo titleBar),
  subirlo al tope de sus hermanas — `SetToplevel(true)` en el frame raíz (`Window.lua:43`) es
  probablemente suficiente (WoW gestiona el raise entre frames toplevel de la misma strata);
  si no, gestión explícita de `SetFrameLevel` entre instancias vivas.
- **`config.strata`** opcional (default `"DIALOG"`, sin cambio para consumidores actuales).

Encaja con FR-019 (headless): si el header es del consumidor, el raise no puede depender del
titleBar de Craft — de ahí "en cualquier parte del window".

## Workaround actual (Coffer)

Hook propio de `OnMouseDown` sobre `GetFrame()` de cada window + `SetToplevel`/`SetFrameLevel`
desde el consumidor. Viable, pero es comportamiento de ventana genérico que pertenece al
componente.

## Impacto

`SetToplevel` es aditivo y probablemente deseable para TODO consumidor (una sola Window también
se beneficia frente a otros addons). `config.strata` es opcional con default actual. Requiere
`CRAFT_BUILD` bump.
