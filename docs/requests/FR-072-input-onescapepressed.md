# FR-072 — `Craft.Input`: `onEscapePressed` (hoy ESC no hace NADA en un Input enfocado)

**Reportado por:** Coffer (SortedBags), barra de búsqueda top-snap — "si presiono ESC debería cerrar
el search", 2026-07-31
**Componente:** `Craft/components/Input.lua`
**Tipo:** API faltante / comportamiento por defecto discutible
**Prioridad:** Media (afecta a todo Input dentro de una ventana; hay fallback, pero toca scripts del
`EditBox` interno)
**Estado:** 📝 Propuesto

---

## Problema

`Craft.Input` **no registra `OnEscapePressed`** en su `EditBox` interno. Consecuencia en juego: con
el campo enfocado, ESC **no hace absolutamente nada** — ni suelta el focus, ni llega al
`closeOnEscape` de `Craft.Window`/`Dialog` (un `EditBox` con focus se come la tecla antes de que la
binding `TOGGLEGAMEMENU` / `UISpecialFrames` entre en juego). El usuario queda "atrapado" en el
campo y tiene que ir al ratón.

`Craft.Textarea` **sí** lo resuelve (`Textarea.lua:132-133`):

```lua
-- Escape clears focus (does not bubble up to close a parent window).
self._edit:SetScript("OnEscapePressed", function() self._edit:ClearFocus() end)
```

Input debería tener al menos esa misma cortesía, y además dejar al consumidor sobreescribirla: en
un search box revelado por un botón, lo esperado no es "soltar el focus" sino **cerrar la barra**.

## Solución propuesta

1. **Default** igual que Textarea: ESC → `ClearFocus()` (no burbujea, no cierra la ventana padre).
2. **Config `onEscapePressed`** (como ya existe `onEnterPressed`) para que el consumidor decida:

```lua
onEscapePressed = config.onEscapePressed,   -- en _cfg
...
self._edit:SetScript("OnEscapePressed", function(editbox)
    if self._cfg.onEscapePressed then
        self._cfg.onEscapePressed(editbox:GetText())
    else
        editbox:ClearFocus()                 -- default, igual que Textarea
    end
end)
```

Simétrico con `onEnterPressed` (`Input.lua:230-234`): misma forma, mismo sitio, misma firma
(el texto actual como argumento).

### Aplicación en la spec

`docs/components/input.md`: fila `onEscapePressed` en la tabla de config, y una nota de
comportamiento — "ESC suelta el focus por defecto; no cierra la ventana padre".

## Notas

- **Fallback en Coffer mientras tanto** (`Coffer/SearchBox.lua`): alcanzar el `EditBox` interno
  (`input._edit`, con escaneo de hijos por `GetObjectType() == "EditBox"` como red de seguridad) y
  poner el `SetScript("OnEscapePressed", …)` a mano → cierra la barra (`ctx.searchOpen:set(false)`).
  Funciona, pero pisa un script de un widget de la librería: si Craft algún día registra el suyo,
  el orden de registro decide quién gana.
- Ojo al diseñar el default: **no** conviene que ESC burbujee para cerrar la ventana padre (eso es
  justo lo que Textarea documenta evitar). Cerrar algo es decisión del consumidor → callback.

## Alcance mínimo (MVP)

- 1 campo en `_cfg` + 1 `SetScript` (~6 líneas) en `Input.lua`.
- 1 fila + nota en la spec.
- 2 tests en `tests/input_spec.lua`: default suelta el focus; con `onEscapePressed` se invoca el
  callback y NO se suelta el focus por su cuenta.

## Referencias

- Falta: [`Craft/components/Input.lua`](../../Craft/components/Input.lua) (`OnEnterPressed` ~línea 230,
  sin `OnEscapePressed` en todo el archivo)
- Precedente: [`Craft/components/Textarea.lua`](../../Craft/components/Textarea.lua#L132)
- Relacionado: FR-059 (`Focus()`/`ClearFocus()` públicos), FR-016 (botón ✕ de clear)
- Consumidor: Coffer `Coffer/SearchBox.lua`, `Coffer/WinBody.lua` (`AttachSearchBar`)
