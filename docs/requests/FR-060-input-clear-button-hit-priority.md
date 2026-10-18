# FR-060 — `Craft.Input`: la ✕ de `clearable` no recibe el click (la tapa el EditBox)

**Reportado por:** Coffer (SortedBags), M9 F1 — barra de búsqueda con `clearable=true`; el usuario
reporta in-game que "la X para limpiar el textfield no funciona", 2026-07-24
**Componente:** `Craft/components/Input.lua` (`_trailBtn` clearable / `onTrailingClick`)
**Tipo:** Bug (interacción / orden de frame level)
**Prioridad:** Media-Alta (la feature `clearable` FR-016 no dispara su click)
**Estado:** ✅ Implementado y **verificado in-game** (2026-07-24, en dev) — tras crear el EditBox, `Create` sube el botón
trailing con `self._trailBtn:SetFrameLevel(self._edit:GetFrameLevel() + 1)` (guard incluido; cubre
`clearable` y `onTrailingClick`). El mock de tests ahora modela frame levels reales (hijo =
padre+1) para que el assert sea significativo. Spec + 2 tests (`tests/input_spec.lua`, suite 444).
Coffer puede retirar su fallback local al re-vendorear

---

## Problema

En un `Input` con `clearable = true`, el botón ✕ (`self._trailBtn`) **no recibe el click**: al
pulsarlo no pasa nada (ni `Clear()`, ni `onClear`, ni el borrado del texto). La causa es orden de
creación + frame level:

- `self._trailBtn` se crea en `Input.lua:110` (Button hijo de `self.frame`), **antes** que el
  EditBox.
- `self._edit` se crea en `Input.lua:146` (EditBox hijo de `self.frame`) con
  `EnableMouse(true)` (`:149`) y anclado a TODO el ancho del frame
  (`TOPLEFT (0,-PAD_V)` .. `BOTTOMRIGHT (0, PAD_V)`, `:155-156`) — cubre también la zona de la ✕.
- Ambos quedan al **mismo frame level** (hijos del mismo parent, sin `SetFrameLevel`). Con dos
  frames mouse-enabled solapados al mismo nivel, WoW da el click al creado **después** → el
  EditBox gana y se traga el click de la ✕.

`SetTextInsets` (`:157`) evita que el TEXTO se meta bajo la ✕, pero no cambia el área de **mouse**
del EditBox, que sigue cubriendo el botón.

Se manifiesta en el **primer** consumidor de `clearable` con foco real (Coffer M9); pasa
desapercibido en demos sin uso interactivo del ✕.

## Solución propuesta

Subir el `_trailBtn` por encima del EditBox tras crear ambos (una línea):

```lua
-- después de crear self._edit (o al final de Create, con guard)
if self._trailBtn then
    self._trailBtn:SetFrameLevel(self._edit:GetFrameLevel() + 1)
end
```

Aplica igual al modo `onTrailingClick` (mismo `_trailBtn`), que hoy sufriría lo mismo.

Alternativa equivalente: crear el `_trailBtn` **después** del EditBox (reordenar), o darle un
`SetFrameLevel` explícito en su creación.

### Aplicación en la spec / tests

- `docs/components/input.md`: nota en la sección de `clearable`/trailing de que el botón va por
  encima del EditBox (hit priority).
- `tests/input_spec.lua`: assert de que `_trailBtn:GetFrameLevel() > _edit:GetFrameLevel()` (o
  test de que un click simulado en la ✕ llama `Clear`).

## Notas

- **Fallback en Coffer mientras tanto** (`Coffer/SearchBox.lua`):
  `input._trailBtn:SetFrameLevel(input._edit:GetFrameLevel() + 2)` con guard de los campos
  privados. Funciona hoy; se retira al cerrar este FR y re-vendorear.
- Relacionado: FR-016 (clearable ✕ original), FR-059 (`Input:Focus()`).

## Alcance mínimo (MVP)

- 1 línea en `Input:Create` (+ guard).
- 1 assert en tests, 1 nota en spec.

## Referencias

- Implementación: [`Craft/components/Input.lua`](../../Craft/components/Input.lua) (`_trailBtn`
  `:110-143`, `_edit` `:146-157`, `Clear()` `:395`)
- Consumidor: Coffer `Coffer/SearchBox.lua` (M9 F1)
