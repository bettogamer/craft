# FR-069 — `Craft.Slider` SECUESTRA la rueda dentro de un `Craft.Scroll`

**Reportado por:** Coffer (SortedBags) — Ajustes ▸ Apariencia, 2026-07-31. Owner: *"cuando hacemos
scroll y justo el ratón se queda sobre un slide, el evento pasa al slide cambiando datos que no
queremos cambiar"*.
**Componente:** [`Craft/components/Slider.lua`](../../Craft/components/Slider.lua) —
spec [`docs/components/slider.md`](../components/slider.md)
**Tipo:** Bug de interacción (mutación de datos NO intencionada)
**Prioridad:** **Alta** — no hay error ni aviso: el usuario cree que ha desplazado la página y en
realidad ha cambiado un ajuste (y en Coffer varios de esos ajustes son de geometría → piden
/reload).
**Estado:** Abierto — Coffer lleva el workaround de abajo desde hoy.

---

## Problema

`Slider` engancha la rueda a su frame raíz, incondicionalmente:

```lua
-- Slider.lua:193
self.frame:EnableMouseWheel(true)
self.frame:SetScript("OnMouseWheel", function(_, delta)
    if self._disabled then return end
    local v = self._value + delta * self._step
    ...
```

En WoW la rueda la recibe el frame **más alto bajo el cursor** que la tenga habilitada, y **no se
propaga** al resto de la pila. Un slider dentro de una página con scroll (`Craft.Scroll`, que
engancha la rueda en su `_scrollFrame` y en su raíz — [`Scroll.lua:135-156`](../../Craft/components/Scroll.lua))
está por encima de ese `ScrollFrame`, así que **mientras el cursor pase por encima de un slider la
página deja de desplazarse y lo que se mueve es el valor**.

Y es un choque garantizado, no un caso raro: la razón de existir de una página con scroll es que
hay más controles que alto, y un slider es un control ancho que ocupa toda la fila — al desplazar
una página de ajustes el cursor cruza sliders sí o sí. El daño es asimétrico: el scroll perdido se
nota y se corrige; el valor cambiado es silencioso, y a mitad de gesto el usuario ni mira la fila.

Contraste con el resto de la librería: `Scroll`, `Select` (FR-066) y `Combobox` enganchan la rueda
en frames que **son** superficies de scroll. `Slider` es el único que se la queda siendo un control
de formulario dentro de otra superficie desplazable.

## Reproducción

```lua
local scroll = Craft.Scroll:Create(parent)
local child  = scroll:GetScrollChild()
-- apilar ~15 filas en `child`, con 3-4 Craft.Slider entre ellas, hasta pasarse del alto
```
Rueda hacia abajo desde arriba del todo: la página baja hasta que el cursor cae sobre un slider;
ahí se para y el slider empieza a cambiar de valor.

## Propuestas

**A (recomendada) — `config.wheel` (default `false` dentro de contexto scrolleable).** Un flag
público para apagar la rueda; el consumidor la enciende si su slider vive en una superficie no
desplazable. Cambiar el default es *breaking* de comportamiento, pero el comportamiento actual es
justamente el defectuoso, y arrastrar el thumb / clicar la pista siguen siendo el gesto principal
del componente — apagar la rueda no le quita ninguna función exclusiva.

**B — reenviar en vez de consumir.** Si el gesto no "es para" el slider (sin modificador, sin foco
previo), buscar el ancestro con `IsMouseWheelEnabled()` y llamar a su `OnMouseWheel`. Conserva la
afordancia sin romper el scroll, pero deja el ajuste tras un gesto oculto (Ctrl+rueda) y mete
lógica de recorrido de jerarquía en un componente de formulario.

**C — `Craft.Scroll` reclama la rueda de sus descendientes.** Que sea el contenedor el que apague
la rueda de los sliders que cuelgan de él. Resuelve el caso de golpe (ningún consumidor tiene que
acordarse) pero es magia a distancia y `Scroll` tendría que reaccionar a hijos añadidos después.

En cualquiera de las tres, **el spec debería decir explícitamente qué pasa con la rueda dentro de
un `Scroll`** — hoy no lo menciona, y el consumidor se entera in-game.

## Mientras tanto (workaround en el consumidor)

Coffer envuelve la creación en un helper (`SettingsWin.lua`, `newSlider`) que apaga la rueda del
frame raíz justo después de crear el slider:

```lua
local function newSlider(parent, config)
  local slider = ns.Craft.Slider:Create(parent, config)
  slider:GetFrame():EnableMouseWheel(false)   -- la rueda es del Craft.Scroll de la página
  return slider
end
```

Con la rueda deshabilitada WoW se salta ese frame y la muesca llega al `ScrollFrame` de debajo, así
que la página vuelve a desplazarse. Funciona y no toca internos de Craft, pero es una decisión
tomada por **cada consumidor uno a uno** (y hay que acordarse en cada slider nuevo: los 9 de Ajustes
pasan hoy por el helper). Se revertiría en cuanto cierre este FR.
