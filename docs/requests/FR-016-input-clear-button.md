# FR-016 — Input: botón clear (✕) funcional para search-box

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/components/Input.lua`
**Tipo:** Feature Request
**Prioridad:** Media — hay workaround; es pulido de la caja de búsqueda
**Estado:** Implementado en `dev` (2026-07-10, rama `feat/menu`) — `clearable`/`onClear` +
`onTrailingClick` en `Input.lua`, `Input:Clear()`, tests en `tests/input_spec.lua` (11), demo en la
página Input del Browser. El ✕ dentro del input es **extensión Craft** (shadcn no tiene `clearable`;
su patrón de búsqueda es `Input`+`Button` en `ButtonGroup`, cosa distinta).

---

## Problema

`Input` ya soporta `iconLeading="search"` (lupa) — perfecto para un search-box. Pero
`iconTrailing` es **solo una textura decorativa**, no clickeable ni con callback
(`Input.lua:86-94`). Un search-box moderno necesita un **botón clear (✕)** que aparezca cuando
hay texto y vacíe el campo al click. Hoy no hay forma de tenerlo sin overlaysar un botón propio.

## Caso de uso (Coffer)

Caja de búsqueda de la ventana principal (`docs/UI-DESIGN.md` §5.1): lupa a la izquierda, y una
**✕ a la derecha** que limpia la búsqueda y devuelve el foco. Cada tecla refiltra la lista; la
✕ es el "reset" rápido.

```
[🔍  flask of power              (✕)]
 ▲ iconLeading (ok)               ▲ falta: clear clickeable
```

## Solución propuesta

### API (cualquiera de las dos; preferible `clearable`)
```lua
Craft.Input:Create(parent, {
  iconLeading = "search",
  clearable   = true,               -- muestra ✕ al haber texto; al click: SetText("") + onChange("")
  onClear     = function() end,     -- opcional, además de onChange
  onChange    = function(text) end,
})
-- alternativa mínima: hacer iconTrailing clickeable
--   iconTrailing = "x", onTrailingClick = function() end
```

### Comportamiento
- `clearable=true` → botón ✕ (icono Lucide `x`) en la posición trailing, **visible solo cuando
  hay texto** (oculto en vacío). Click: `SetText("")`, dispara `onChange("")` + `onClear()`,
  mantiene/retorna el foco.
- Compatible con `iconLeading` (lupa + clear a la vez).
- Aditivo: sin `clearable`/`onTrailingClick`, el `Input` actual no cambia.

## Workaround actual (Coffer)

Un botón `✕` propio (`Craft.Button` icónico) posicionado como overlay sobre el `iconTrailing`
decorativo, con su propia lógica de show/hide por texto. Funciona, pero reimplementa algo que
el componente debería ofrecer y depende de la posición interna del icono trailing. **No bloquea
M5.**

## Impacto

Cambio pequeño y aditivo en `Input`. Reutilizable por cualquier consumidor con campos de
búsqueda/filtro (Sentry/Beacon).
