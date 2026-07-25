# FR-059 — `Craft.Input`: método público `Focus()` / `ClearFocus()`

**Reportado por:** Coffer (SortedBags), M9 F1 búsqueda — barra de búsqueda "top-snap" revelada por un botón, 2026-07-24
**Componente:** `Craft/components/Input.lua` (API pública)
**Tipo:** API faltante (UX de reveal / focus programático)
**Prioridad:** Baja-Media (hay fallback trivial, pero toca un campo privado)
**Estado:** ✅ Implementado (2026-07-24, en dev) — `Input:Focus()` / `ClearFocus()` / `HasFocus()`
en `Craft/components/Input.lua`; `Focus()` es **no-op si el campo está `disabled`** (criterio del
owner: un EditBox deshabilitado no acepta escritura, llevarle el caret solo ocultaría el
placeholder). `HasFocus()` normaliza a booleano. Spec + 3 tests (`tests/input_spec.lua`, suite 442)

---

## Problema

`Craft.Input` no expone forma pública de **enfocar** (o desenfocar) el campo por código. La API
pública actual es `SetValue`/`Clear`/`GetValue`/`SetEnabled`/`SetError`/`SetPlaceholder`/
`GetFrame`/`Destroy` — ninguna da el focus. Internamente el `EditBox` se enfoca en `Clear()`
(`self._edit:SetFocus()`), así que la capacidad ya existe, solo no está expuesta.

**Caso de uso (Coffer):** una barra de búsqueda que aparece con animación al pulsar un botón
(lupa) debe dejar el cursor listo para escribir **sin un segundo clic** — el patrón universal de
"toggle search → type". Al cerrar la barra conviene soltar el focus. Hoy Coffer lo resuelve
alcanzando el campo privado `input._edit:SetFocus()` / `:ClearFocus()`, lo cual funciona pero
depende de un detalle interno (`_edit`) que un refactor de Craft podría renombrar.

## Solución propuesta

Añadir dos métodos triviales a `Input`:

```lua
function Input:Focus()      self._edit:SetFocus()      end
function Input:ClearFocus() self._edit:ClearFocus()    end
```

Opcional (nice-to-have, mismo espíritu): `Input:HasFocus()` → `self._edit:HasFocus()`.

### Aplicación en la spec

`docs/components/input.md`: añadir `Focus()` / `ClearFocus()` (`HasFocus()`) a la tabla de API
pública, notando que respetan `disabled` si se quiere (un `Focus()` sobre un input deshabilitado
podría ser no-op — a criterio del owner).

## Notas

- **Fallback en Coffer mientras tanto:** `input._edit and input._edit:SetFocus()` /
  `:ClearFocus()` (guardado por si el campo cambia). Ningún bloqueo — es puramente ergonomía.
- Relacionado con el patrón de reveal animado: no requiere cambios de layout ni de tema, solo el
  passthrough al `EditBox`.

## Alcance mínimo (MVP)

- 2 métodos (2–3 líneas) en `Input.lua`.
- 1 fila en la spec.
- (Opcional) assert en `tests/input_spec.lua` de que `Focus()` no lanza.

## Referencias

- Implementación: [`Craft/components/Input.lua`](../../Craft/components/Input.lua) (`_edit`,
  `SetFocus` ya usado en `Clear()` línea ~401)
- Consumidor: Coffer `Coffer/WinBody.lua` (barra top-snap de búsqueda, M9 F1) + `Coffer/SearchBox.lua`
