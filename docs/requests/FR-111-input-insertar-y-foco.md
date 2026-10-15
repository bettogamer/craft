# FR-111 — `Craft.Input`: insertar texto en el cursor y avisar al ganar/perder el foco

**Solicitante:** SMRT (módulo «Auras personalizadas», panel «Códigos de texto», spec-A3a D-A3a-5, 2026-10-14).
**Componente:** `Craft/components/Input.lua` (build vendoreado 2.33.0, `CRAFT_BUILD = 35`).
**Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-15), release v2.34.0. Incluye `Get/SetCursorPosition` y el mismo patrón en `Craft.Textarea`. Demos en `Craft_Browser/pages/Input.lua` y `Textarea.lua` (bloques FR-111).
**Tipo:** Mejora (API).
**Prioridad:** Baja. **No bloquea:** SMRT usa un fallback (ver abajo).

---

## Qué falta

El panel de códigos de texto dinámico de SMRT copia el de WeakAuras: una lista de códigos (`%p`, `%n`,
`{rt1}`…) que, al pulsarlos, se **insertan donde está el cursor** del campo de texto, y el panel se
**abre al dar foco al campo** y se cierra al perderlo.

`Craft.Input` no expone ninguna de las dos cosas:

1. No hay `Insert(text)`: solo `SetValue`/`GetValue`, que reemplazan el texto entero y pierden el cursor.
2. No hay `onFocusGained` / `onFocusLost` en la config: el EditBox interno ya tiene `OnEditFocusGained` /
   `OnEditFocusLost` (Input.lua ~l. 201-211, usados para el placeholder y el anillo de foco), pero no
   llaman a nada del consumidor.

## Propuesta

- `Input:Insert(text)`: `self._edit:Insert(text)` + el mismo camino que una tecla del usuario (dispara
  `onChange`, actualiza placeholder y botón de limpiar).
- `Input:GetCursorPosition()` / `SetCursorPosition(n)` opcional, por simetría con el EditBox.
- Config `onFocusGained()` y `onFocusLost()`, llamados desde los scripts que ya existen, después del
  trabajo interno.
- Lo mismo en `Craft.Textarea` si es barato (mismo patrón; WA usa el panel también en textos largos).

## Fallback en SMRT mientras tanto

El código pulsado se **añade al final** del texto (`SetValue(GetValue() .. code)`) y el panel solo se
abre con el icono del campo (`iconTrailing = "braces"`, `onTrailingClick`), no al dar foco.
