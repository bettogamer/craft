# FR-101 — `Craft.Tooltip`: apartarse del outline global (`fontFlags`) por tooltip

**Solicitante:** SMRT (módulo Timeline, tooltips de los casteos del jefe, 2026-09-28).
**Componente:** `Craft/components/Tooltip.lua`, v2.26.0 (`139bce1`).
**Tipo:** Feature.
**Prioridad:** Baja. **No bloquea:** mientras tanto el tooltip de SMRT sigue con el contorno del
tema.

---

## Qué falta

`Tooltip.lua:166` aplica la fuente con `Craft.Theme.applyFont(_tooltip._text, t.font, FONT_SIZE)`
sin 4.º argumento, así que el tooltip siempre hereda el outline global (`t.fontFlags`). FR-092 ya
dio a `applyFont` el parámetro `flags` para que UN elemento se aparte del flag global, pero
`Tooltip.Show`/`Attach` no lo exponen en su `config`.

## Caso de uso

El owner de SMRT tiene outline activo en el tema. En la línea de tiempo (lienzo oscuro, texto
claro) quitó el contorno a todos los textos del lienzo con `applyFont(fs, path, size, "")` y se
lee mejor. El tooltip de un casteo (`Craft.Tooltip.Show(btn, { text = ..., side = "top" })`) es
lo único que queda con contorno, y es justo el texto más largo.

## Propuesta de API

```lua
Craft.Tooltip.Show(anchor, { text = "...", fontFlags = "" })   -- "" = sin contorno
Craft.Tooltip.Attach(frame, { text = "...", fontFlags = "" })
```

- `fontFlags` nil (default) = comportamiento actual (el flag global del tema).
- Como el tooltip es un singleton, el flag se aplica en cada `Show` (el siguiente `Show` sin
  `fontFlags` vuelve al del tema) — no debe "pegarse" de una llamada a otra.

## Criterio de aceptación

- `Show` con `fontFlags = ""` con el tema en `"OUTLINE"` → texto sin contorno; el siguiente
  `Show` sin la opción → con contorno.
- Spec en busted del reset entre llamadas.

---

## Resolución — IMPLEMENTADO en dev (2026-09-28, pendiente verificación in-game)

- `config.fontFlags` en `Show`/`Attach`, pasado como 4.º arg de `applyFont`. Se asigna en
  CADA `Show` (también cuando es nil), así que no se pega; un cambio de tema con el tooltip
  abierto respeta el override de ese Show.
- Tests: `tests/tooltip_spec.lua` (nuevo, 5 casos incl. el reset). Demo: página Tooltip del
  Browser, fila "FR-101 fontFlags" (activar "Font outline" en Theme para comparar).
