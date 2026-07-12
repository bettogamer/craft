# FR-018 — Checkbox: el ancho del frame no incluye el label estático (overflow)

**Reportado por:** Coffer (consumer addon — recreación de Sorted para WoW 12.0.7)
**Componente:** `Craft/components/Checkbox.lua`
**Tipo:** Bug (layout)
**Prioridad:** Media — rompe el layout de cualquier consumidor que ancle un checkbox con label estático por su borde derecho o dentro de un contenedor dimensionado.
**Estado:** Implementado en `dev` (2026-07-12). Una línea en `Checkbox.lua:136` — `self:_recalcWidth()` tras `SetText` inicial en `Create`, mismo patrón que `Button`.

---

## Problema

Un `Craft.Checkbox` creado con un **label string estático** (no señal) termina con el **ancho de frame
sin contar el label**: el `FontString` se pinta pero el `self.frame` queda con ancho `BOX_SIZE + GAP`
(sin `labelW`), así que el texto **desborda por la derecha** del frame.

### Causa raíz (orden de operaciones en `Checkbox:Create`)

1. `self:_applyTheme(...)` corre e invoca `self:_recalcWidth()` — pero el label **aún no tiene texto**
   (`_label:GetStringWidth()` = 0), así que `frame:SetWidth(BOX_SIZE + LABEL_GAP + 0)`.
2. Justo después: `self._label:SetText(self._cfg.label)` — pone el texto **pero NO vuelve a llamar a
   `_recalcWidth()`**.
3. El bind reactivo `R.applyOrBind(self, labelSource, SetLabel)` solo llama a `SetLabel` (que sí
   recalcula) **cuando `label` es una señal**. Con un string plano, `labelSource` es `nil` → nunca se
   recalcula → el frame queda angosto para siempre.

Es decir: solo los labels **reactivos** obtienen el ancho correcto; los **estáticos** no.

## Síntoma observado (Coffer)

Checkbox `[Reagents]` en la barra de acciones de banco, anclado por su borde derecho a la izquierda del
toggle List/Grid. El label "Reagents" se dibujó **encima del toggle** (desbordando el frame angosto) en
vez de quedar contenido a la izquierda. Ver captura en el hilo de D-3a.

## Solución propuesta

Llamar a `self:_recalcWidth()` **después** de `self._label:SetText(...)` en `Create` (o mover el
`SetText` inicial a antes del primer `_recalcWidth`). Un `_recalcWidth` extra tras fijar el texto
estático arregla el ancho sin tocar el path reactivo.

```lua
if self._cfg.label and self._cfg.label ~= "" then
    self._label:SetText(self._cfg.label)
    self:_recalcWidth()          -- <-- faltaba: el texto estático ya está, recalcular ancho
end
```

## Workaround en el consumer (mientras tanto)

Tras crear el checkbox, re-setear el label por API pública para forzar el recálculo:

```lua
local cb = Craft.Checkbox:Create(parent, { label = "Reagents", ... })
cb:SetLabel("Reagents")   -- SetLabel sí llama a _recalcWidth → ancho correcto
```

Funciona (Coffer lo usa hoy), pero es un hack no evidente; de ahí el FR.

## Impacto

Fix puntual, sin cambio de API ni de default. Beneficia a todo consumidor con checkboxes de label
estático anclados por la derecha o metidos en un contenedor dimensionado por el ancho del hijo.
