# FR-078 — `Craft.Window`: el pivote del zoom se captura del rectángulo de un frame OCULTO, así que una ventana reposicionada antes de abrir salta al centro de la pantalla

**Reportado por:** Coffer (addon de bolsas para WoW 12.1) — MainFrame, ventanas de banco,
Ajustes y Monedas: todas persisten su posición en SavedVariables.
Síntoma del owner (2026-08-26 y otra vez el 2026-08-27, tras dos intentos de arreglo del lado
del consumidor): *"abro el main window, lo cierro, se va al medio y se cierra, abro y aparece al
medio"*.
**Componente:** [`Craft/components/Window.lua`](../../Craft/components/Window.lua) —
`captureZoomAnchor` / `_applyScale`
**Tipo:** Bug (la captura del pivote confía en `GetCenter()` de un frame que puede estar oculto)
**Prioridad:** Alta — afecta a **cualquier** consumidor que restaure una posición persistida, que
es el caso normal de una ventana movible. El fallo es silencioso y se lee como "mi restauración no
funciona", que es donde se pierden las horas: el `SetPoint` del consumidor es correcto y aun así
la ventana acaba en el centro exacto de la pantalla.
**Estado:** ✅ Cerrado — implementado y **verificado in-game** (2026-08-28, 12.1), released en
**v2.16.0**. **A + B + C + D**, resueltas por una sola idea: **el pivote se deriva del ANCLA, nunca del
rectángulo**. Ver "Resolución" al final.

---

## Problema

El zoom de apertura/cierre re-ancla el frame en CADA tick por `CENTER`, con un pivote que se
captura al voltear la señal `_open`:

```lua
local function captureZoomAnchor()
    local f = self.frame
    if not f then return end
    local fx, fy = f:GetCenter()          -- ← aquí
    local ux, uy = UIParent:GetCenter()
    if not (fx and ux) then
        self._zoomBaseX, self._zoomBaseY = 0, 0   -- ← y aquí
        return
    end
    ...
end

self._effects[#self._effects + 1] = Weave.effect(function()
    self._open()               -- track: recapture the resting offset on each flip
    captureZoomAnchor()
end)
```

El comentario del código dice que la captura lee "la posición de reposo (la que el usuario haya
arrastrado)". Eso es cierto **al cerrar** (el frame está a la vista) pero **no al abrir**: en el
instante en que `_open` pasa a `true` el frame sigue oculto — es el efecto de `shown`, más abajo,
el que lo muestra. Y **WoW no recalcula el rectángulo de un frame oculto**: un `SetPoint` hecho
mientras está escondido queda escrito, pero `GetCenter()` sigue devolviendo la geometría anterior
(o `nil` si el frame no llegó a tener una).

Las dos ramas fallan, y la segunda es la que se ve:

1. **Rectángulo viejo** → el pivote sale de donde estaba la ventana ANTES de reposicionarla, así
   que el `SetPoint` del consumidor no llega a verse nunca.
2. **`GetCenter()` → nil** → `_zoomBaseX, _zoomBaseY = 0, 0` → `_applyScale` ancla
   `CENTER, UIParent, CENTER, 0, 0`: **el centro exacto de la pantalla**. Y como el pivote es
   estado persistente del componente, ahí se queda para todas las aperturas siguientes.

El caso 2 también explica el salto *al cerrar* por la ruta de ESC: Blizzard llama a `frame:Hide()`
directamente (`UISpecialFrames`) y el `HookScript("OnHide")` de Window vuelca `_open:set(false)`
**con el frame ya oculto** → captura → `nil` → pivote 0,0 → el frame salta al centro y ahí se
desvanece. Es literalmente lo que describe el owner: *"se va al medio y se cierra"*.

## Cómo reproducirlo

1. Una `Craft.Window` movible cuya posición se persista.
2. Arrastrarla a una esquina, cerrarla con **ESC**.
3. Reabrirla habiendo hecho `frame:ClearAllPoints()` + `frame:SetPoint("TOPLEFT", …)` **antes** de
   `win:Show()` (que es la única ventana de tiempo que el consumidor tiene: en cuanto `_open`
   voltea, `_applyScale` pisa cualquier ancla propia).
4. La ventana aparece centrada, no en la esquina.

## Propuestas

**A (mínima, ataca la rama del `nil`).** No aceptar `0,0` como pivote cuando `GetCenter()` no
contesta: si el frame está oculto y hay un ancla explícita, derivar el centro de ella
(`GetPoint()` + `GetSize()`), y si de verdad no hay nada, **conservar el pivote anterior** en vez
de mandar la ventana al centro. Perder precisión un tick es infinitamente mejor que teletransportar
la ventana.

**B (la que arregla el caso real).** Capturar el pivote **cuando el rectángulo es válido**, no en
el flanco de la señal: al abrir, recapturar en el primer tick con el frame ya mostrado (o forzar el
`Show()` antes de la captura, que es lo que hace hoy el consumidor a mano). El pop no cambia: el
tween sigue arrancando en `motionZoomFrom`.

**C (API, la que a un consumidor le gustaría).** `Window:SetPosition(point, relTo, relPoint, x, y)`
—o un `config.position` reactivo— que sea el sitio **oficial** de colocar la ventana, y que
mantenga el pivote del zoom sincronizado por dentro. Hoy no existe ese contrato: el consumidor
tiene que hacer `ClearAllPoints`+`SetPoint` sobre `GetFrame()` sabiendo que la animación le va a
pisar el ancla, lo cual ya es de por sí una fuga de abstracción. Con C, A y B pasan a ser detalles
internos.

**D (documentación, en cualquier caso).** Que `docs/components/window.md` diga explícitamente que
el frame raíz está anclado por `CENTER` mientras vive el componente, que cualquier ancla puesta
desde fuera dura hasta el siguiente tick de zoom, y cuál es el momento correcto de restaurar una
posición guardada.

## Mitigación en el consumidor (Coffer, hoy)

Restaurar la posición **justo antes de cada `Show()`**, y —porque un `SetPoint` sobre un frame
oculto no se ve reflejado— **mostrar el frame antes de anclarlo**: con `_open` todavía en `false`
su alfa es 0, así que es invisible, pero WoW ya le resuelve la geometría y el `GetCenter()` que
Craft lee un instante después es el bueno.

```lua
local function restorePos()
  local px, py = slot.x:peek(), slot.y:peek()
  if type(px) ~= "number" or type(py) ~= "number" then return end
  local r = uiRatio(frame)
  if not frame:IsShown() then frame:Show() end   -- alfa 0: invisible, pero con rectángulo válido
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", px / r, py / r)
  frame:GetCenter()                              -- fuerza el recálculo del rectángulo
end
```

Funciona, pero se apoya en dos cosas internas de Craft que un consumidor no debería tener que
saber: que el alfa está atado a `_open` (si algún día la ventana cerrada dejara de estar a alfa 0,
esto haría un flash) y que la captura del pivote ocurre en el flanco de esa misma señal. Es el
apaño de mientras, no la solución.


## Ampliación (2026-08-27, tras dos rondas más in-game)

La mitigación de arriba **no bastaba**, y las dos razones afinan lo que el arreglo en Craft tiene
que cubrir:

1. **El volteo del CIERRE también captura.** Restaurar antes de `Show()` deja la apertura bien,
   pero el pivote que manda durante el fundido de salida se captura al poner `_open` en `false` —
   y ese es el que se ve, porque el jugador está mirando la ventana mientras se va al centro. El
   pivote malo además se queda puesto para el volteo siguiente.

2. **El fallo tiene dos formas, y `GetCenter() == nil` es solo una.** La otra es que devuelva el
   rectángulo **viejo** (el frame se movió o se re-ancló y WoW aún no lo ha resuelto). Si ese
   valor viejo era la posición de fábrica —ventana centrada al crearse—, el resultado vuelve a ser
   el centro de la pantalla, pero con un `_zoomBase` que **no** es `0,0`. Un arreglo que solo
   blinde el caso `nil` deja pasar esta mitad.

Lo que Coffer hace ahora (`WinFrame.guardZoom`) es rodear **todos** los volteos de `_open` y, si el
pivote capturado no coincide con el que sale de la posición persistida, sobrescribir
`_zoomBaseX`/`_zoomBaseY` y llamar a `_applyScale`. Es decir: el consumidor escribe dos campos
privados de `Craft.Window` en cada apertura y cada cierre de cinco ventanas. Funciona, pero es
justo la clase de apaño que un `Window:SetPosition(point, relTo, relPoint, x, y)` oficial —dueño de
la posición y del pivote, sin que el consumidor toque nada interno— haría innecesario.

**Detalle útil para implementarlo:** el pivote se puede derivar SIN leer el rectángulo, que es lo
que falla. Con la posición conocida (esquina superior izquierda), el tamaño y las escalas:

```lua
-- centro de la ventana, en unidades de UIParent (r = frame:GetEffectiveScale() / UIParent:GetEffectiveScale())
local cx = left + frame:GetWidth()  * r / 2
local cy = top  - frame:GetHeight() * r / 2
local ux, uy = UIParent:GetCenter()
local k = UIParent:GetEffectiveScale() * frame:GetScale() / frame:GetEffectiveScale()
pivotX, pivotY = (cx - ux) * k, (cy - uy) * k
```

---

## Resolución (2026-08-28, en `dev`)

**La idea que cierra las cuatro propuestas es una sola:** el pivote se deriva del **ancla**
(`GetPoint` + `GetSize`), no del rectángulo. El ancla es lo que `SetPoint` **escribió** — nunca
está rancia y existe con el frame oculto —, así que desaparecen de golpe las dos formas del
fallo que describe la ampliación: la rama `nil` y la del rectángulo viejo. Es además
**idempotente contra nuestras propias escrituras**: `_applyScale` ancla por `CENTER` con
`pivote/escala`, y re-derivar ese ancla devuelve el mismo pivote a cualquier escala, así que
el volteo del cierre (el que ve el jugador) ya no puede desplazar nada.

- **A** — ya no existe la rama `0,0`. Si ni el ancla ni el rectángulo pueden contestar, se
  **conserva el pivote anterior**.
- **B** — innecesaria: no hay que esperar a que el frame esté mostrado, porque no se lee el
  rectángulo. El consumidor puede dejar de hacer `Show()` antes de anclar.
- **C** — `Window:SetPosition(point, relTo, relPoint, x, y)` + `Window:GetPosition()`. Escribe
  el ancla, re-deriva el pivote y re-aplica la escala en una llamada. `x`/`y` en **unidades de
  UIParent** (no del frame): un par persistido sobrevive a un cambio de `scale`, que era el
  otro pie del que cojeaba la vía manual. `GetPosition()` devuelve una tupla que `SetPosition`
  acepta, así que guardar/restaurar hace round-trip exacto. `Center()` pasa por ahí.
- **D** — `docs/components/window.md` dice ahora explícitamente que el frame raíz está anclado
  por `CENTER` mientras vive el componente, que cualquier ancla puesta desde fuera dura hasta
  el siguiente tick, y cuál es el momento correcto de restaurar (`SetPosition`, en cualquier
  momento, también oculta).

**Un hallazgo extra, que el FR no preveía:** la captura y `_applyScale` estaban en **dos
effects distintos**, y el orden entre ellos lo decidía el scheduler. Si `_applyScale` corría
primero en un volteo, pisaba con el pivote viejo el ancla que el consumidor acababa de
escribir, y la captura de detrás re-derivaba fielmente ese valor rancio — el bug sobrevivía al
arreglo. Salió al correr la suite entera (el spec pasaba en solitario y fallaba acompañado).
Ahora son **un solo effect**, capturar-y-aplicar en ese orden, con la captura limitada al
volteo real de `_open` (a media animación el frame está escalado y derivar el centro desde un
ancla que no sea `CENTER` metería el zoom dentro del pivote).

También se re-deriva el pivote al soltar un **arrastre** y un **resize**, que reescriben el
ancla y mueven el centro.

**Para el consumidor:** se puede retirar `WinFrame.guardZoom` y el `restorePos()` que muestra
el frame antes de anclarlo. La restauración pasa a ser una línea, en cualquier momento y con la
ventana oculta:

```lua
win:SetPosition("TOPLEFT", UIParent, "BOTTOMLEFT", px, py)   -- unidades de UIParent
-- y al guardar:
local _, _, _, x, y = win:GetPosition()
```

Cubierto por `tests/window_spec.lua` (12 casos): restauración con el frame oculto, la ruta de
ESC (`OnHide` con el frame ya oculto), idempotencia a través de volteos y de `SetBaseScale`,
conservación del pivote cuando nada puede contestar, el fallback al rectángulo, y el
round-trip `SetPosition`/`GetPosition`.
