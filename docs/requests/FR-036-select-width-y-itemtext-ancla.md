# FR-036 — Select: implementar config.width y ancla simple en itemText

**Reportado por:** Auditoría de fidelidad shadcn (interno, 2026-07-18)
**Componente:** `Craft/components/Select.lua` (shadcn: Select)
**Tipo:** Bug fix
**Prioridad:** Media
**Estado:** ✅ Implementado y verificado in-game (2026-07-18)

---

## Problema

### 1. Drift: `config.width` documentado pero nunca implementado

La prop `width` está documentada en `docs/components/select.md:72` ("Width del trigger: 100% del parent por
defecto (puede fijarse con `config.width`)") y en la tabla Config de `:169` con valor `number | nil`.

Sin embargo, en `Create()` (`Select.lua:48-55`) **nunca se captura en `self._cfg`**:

```lua
self._cfg = {
    options     = config.options     or {},
    value       = config.value,
    placeholder = config.placeholder or "Select...",
    size        = config.size        or "default",
    disabled    = config.disabled    or false,
    onSelect    = config.onSelect,
}
-- ← width está AUSENTE
```

Y el frame raíz solo hace `SetHeight` (`:78`), **nunca `SetWidth`**:

```lua
self.frame:SetHeight(sz.h)  -- ← solo altura
```

**Consecuencia:** `Create(parent, { width=200 })` ignora el 200. Si el caller tampoco fija el ancho, el
trigger queda con ancho=0 (el panel cae a su mínimo `MIN_PANEL_W=144`, pero el trigger raíz permanece a
0, causando desalineación visual).

### 2. Bug potencial — FontStrings con dos anclas horizontales (patrón Bug #2 CLAUDE.md)

Dos FontStrings en el componente usan **cuatro anclas** (LEFT + RIGHT + TOP + BOTTOM), el patrón que causa
invisibilidad con width=0:

- **`_selectedText` (`:272-275`)**: corre en `_applyTheme` (`:406-410`), donde se re-ancla:

```lua
self._selectedText:SetPoint("LEFT",   self._trigger, "LEFT",   TRIGGER_PL, 0)
self._selectedText:SetPoint("RIGHT",  self._trigger, "RIGHT",  -(TRIGGER_PR + CHEVRON_SIZE + GAP), 0)
self._selectedText:SetPoint("TOP",    self._trigger, "TOP",    0, 0)
self._selectedText:SetPoint("BOTTOM", self._trigger, "BOTTOM", 0, 0)
```

  **Salvado** porque `_applyTheme` se re-ejecuta en `onFontsReady` (Weave.effect en el motor de tema).

- **`itemText` (`:272-275` en `_makeItem`)**: se ancla UNA sola vez en la creación del item:

```lua
itemText:SetPoint("LEFT",        itemFrame, "LEFT",   ITEM_PL, 0)
itemText:SetPoint("RIGHT",       itemFrame, "RIGHT",  -ITEM_PR, 0)
itemText:SetPoint("TOP",         itemFrame, "TOP",    0, 0)
itemText:SetPoint("BOTTOM",      itemFrame, "BOTTOM", 0, 0)
```

  **`_buildItems` (`:337-339`) solo re-ancla los frames de items, NUNCA los FontStrings**:

```lua
item.frame:ClearAllPoints()
item.frame:SetPoint("TOPLEFT",  self._scrollChild, "TOPLEFT",  0, -totalH)
item.frame:SetPoint("TOPRIGHT", self._scrollChild, "TOPRIGHT", 0, -totalH)
-- ← item.text nunca se re-ancla
```

**Riesgo:** en boot frío (primera sesión, TTF aún no cargado en cliente), el `itemText` puede quedar
invisible si su frame padre se dimensiona *después* de la creación. La re-medición del tema (en
`onFontsReady`) no alcanza porque `itemText` quedó congelado con sus anclas viejas. Especialmente
grave en dropdowns largos donde los items se crean temprano.

---

## Solución propuesta

### 1. Implementar `config.width`

En `Create()`, capturar la prop:

```lua
self._cfg = {
    options     = config.options or {},
    value       = config.value,
    placeholder = config.placeholder or "Select...",
    size        = config.size or "default",
    disabled    = config.disabled or false,
    onSelect    = config.onSelect,
    width       = config.width,  -- ← AÑADIR
}
```

Luego, en `Create()` tras crear `self.frame`:

```lua
if self._cfg.width then
    self.frame:SetWidth(self._cfg.width)
end
```

Alternativamente, si no se quiere soportar la prop (pero la spec dice que sí):
**borrar `width` de la tabla Config en `docs/components/select.md:169`** (actualizar spec para reflejar
lo real).

### 2. Fijar ancla única en FontStrings

Opciones equivalentes:

**Opción A:** Ancla única + `SetWidth` explícito (patrón Slider/Sidebar):

- `_selectedText`: usar solo `LEFT`, dejar que WoW auto-dimension desde el contenido
  (pero requiere conocer ancho máximo → complicado con chevron).

**Opción B:** Mantener dos anclas, pero re-aplicarlas en `_applyTheme` (como ya hace
`_selectedText`).

**Opción C (recomendada):** Para `itemText`, cambiar a ancla única `LEFT` + `SetWidth` tras conocer
el ancho del frame padre. En `_buildItems`, tras posicionar cada `item.frame`:

```lua
item.frame:SetPoint("TOPLEFT",  self._scrollChild, "TOPLEFT",  0, -totalH)
item.frame:SetPoint("TOPRIGHT", self._scrollChild, "TOPRIGHT", 0, -totalH)

-- Fijar itemText con ancla única + ancho explícito
local availableW = self._scrollChild:GetWidth() - ITEM_PL - ITEM_PR
if availableW > 0 then
    item.text:ClearAllPoints()
    item.text:SetPoint("LEFT", item.frame, "LEFT", ITEM_PL, 0)
    item.text:SetWidth(availableW)
else
    item.text:ClearAllPoints()
    item.text:SetPoint("LEFT", item.frame, "LEFT", ITEM_PL, 0)
end
```

Requiere **verificación in-game en boot frío** (primera sesión del cliente, TTF aún cargando) para
confirmar que los labels de items permanecen visibles.

---

## Caso de uso

Selects de ancho fijo. Ejemplo shadcn: dropdown "Select Currency" con opciones como "USD — United States
Dollar". El componente debe poder fijarse a un ancho explícito (ej. 200px) para layouts responsables
(formularios de settings, Coffer, etc.).

---

## Impacto

- **Fix funcional:** `config.width` completa la API declarada en la spec.
- **Robustez:** elimina el riesgo de FontStrings invisibles en boot frío con width=0.
- **Riesgo bajo:** cambios locales al componente, sin impacto en la API pública.

---

## Notas de prueba

El #2 (itemText ancla) requiere reproducción in-game:

1. Crear un Select con múltiples items (N > 6 para scroll).
2. Primera sesión del cliente (TTF Inter aún no en caché).
3. Iniciar la UI del addon (Craft_Browser / demo) y abrir el Select.
4. **Verificar:** los labels de los items aparecen legibles; no hay text invisible/solapado.
5. Tras `/reload`, revisar que no hay regresión (texto sigue visible).

---

## Implementación (2026-07-18)

`Craft/components/Select.lua`:

1. **`config.width`** — capturado en `self._cfg.width` (nil = fill parent) y aplicado con
   `self.frame:SetWidth(...)` justo tras crear el frame raíz (el `_trigger` lo sigue vía
   `SetAllPoints`; el panel ya deriva su ancho de `_trigger:GetWidth()`). No reactivo.

2. **`itemText` ancla única** — se elimina el doble anclaje horizontal de `_makeItem` (se
   fijaba una sola vez en la creación y nunca se refrescaba). Ahora `_buildItems` (re)aplica en
   cada rebuild: ancla única `LEFT` + `SetWidth(availW)` con
   `availW = max(trigger width, MIN_PANEL_W) - 2 - ITEM_PL - ITEM_PR` (mismo cálculo que
   `_updatePanelSize`, nunca 0). Como `_buildItems` corre dentro de `_applyTheme`, queda cubierto
   por la re-medición de `onFontsReady` (a diferencia del código previo, que solo re-anclaba los
   frames de items, no los FontStrings).

Verificación: `luac -p` OK, luacheck 0/0, taintlint 0/0, suite 292/292. Verificado in-game
(2026-07-18): `config.width` fija el ancho del trigger y los labels de items se ven legibles.
