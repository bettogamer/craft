# FR-006 — Input: modo multilínea (TextArea)

**Reportado por:** Sentry (consumer addon)
**Componente:** `Craft/components/Input.lua`
**Tipo:** Feature Request
**Prioridad:** Media-Alta — editor de código y campos de texto largo
**Estado:** ✅ Resuelto (2026-06-11) — vía **componente nuevo `Craft.Textarea`** (no extendiendo Input): shadcn tiene `Textarea` como componente separado. EditBox multilínea + ScrollFrame interno (rueda + cursor-follow), `value`/`placeholder`/`height`/`error`/`maxLetters`/`font`. Ver `docs/components/textarea.md`.

---

## Problema

`Input` fuerza `self._edit:SetMultiLine(false)` — solo admite una línea. No hay forma de tener un área de
texto multilínea (con scroll) para contenido largo.

## Caso de uso (Sentry)

- **Editor de código** Custom/TSU (varias líneas de Lua) — ver `UI-DESIGN §11` (va en ventana aparte, pero
  necesita un control multilínea con scroll).
- Strings de import/export (largos), notas, plantillas de texto.

## Solución propuesta

### API
```lua
Craft.Input:Create(parent, {
  multiline = true,     -- SetMultiLine(true); crece o usa scroll interno
  height    = 200,      -- alto del área (con multiline)
  scroll    = true,     -- envolver en ScrollFrame
  monospace = true,     -- opcional, fuente monoespaciada (código)
  onChange  = function(text) end,
})
```
### Comportamiento
- `multiline=true` → `SetMultiLine(true)`, respeta `height`, `Tab`/`Enter` no cierran el foco.
- `scroll=true` → EditBox dentro de `ScrollFrame` (UIPanelScrollFrameTemplate o equivalente Craft).

## Workaround actual (Sentry)

EditBox multilínea propio (`Sentry/UI/ImportExport.lua`). Sirve, pero sin el estilo/tokens de Craft.

## Impacto

Additivo (sin `multiline`, el `Input` actual no cambia).
