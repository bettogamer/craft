# FR-074 — `Craft.Select`: error Lua por frame al abrir el panel en 12.1 (`MouseIsOver` ya no existe)

**Reportado por:** Bis (Craft vendoreado en `Bis/libs/Craft/`), WoW **12.1**, 2026-08-13
**Componente:** `Craft/components/Select.lua`
**Tipo:** Bug — API de FrameXML desaparecida en 12.1
**Prioridad:** Alta (spam de error Lua mientras el desplegable está abierto; el cierre por click
fuera deja de funcionar)
**Estado:** ✅ Implementado (pendiente verificación in-game)

---

## Problema

Con el panel del Select abierto, el cliente escupe un error **por cada frame**:

```
151x Bis/libs/Craft/components/Select.lua:255: attempt to call a nil value
[Bis/libs/Craft/components/Select.lua]:255: in function <Bis/libs/Craft/components/Select.lua:254>
```

El watcher de "click fuera" del panel llamaba al **global de FrameXML `MouseIsOver(region)`**:

```lua
self._panel:SetScript("OnShow", function()
    self._panel:SetScript("OnUpdate", function()
        if not MouseIsOver(self._panel) and not MouseIsOver(self._trigger) then   -- ← nil en 12.1
```

En **12.1 ese global ya no existe**. Al ser un `OnUpdate`, el error se repite ~cada frame (de ahí
el contador 151x) y, como el handler aborta en la primera línea, **el desplegable ya no se cierra
al hacer click fuera**.

`MouseIsOver` era el único global de FrameXML que Craft llamaba **sin guarda** (el otro candidato,
`OpacitySliderFrame` en `ColorSwatch.lua:201`, ya se lee con `if OpacitySliderFrame and …`). El
resto del código de Craft ya usaba el método de widget (`Slider.lua:224`,
`docs/components/select.md`, `docs/components/tooltip.md`).

## Solución aplicada

Usar el **método de widget** `region:IsMouseOver()` — API C del widget, no FrameXML, con la misma
semántica (rect de la región, con offsets opcionales):

```lua
-- Region:IsMouseOver() (widget method), NOT the global MouseIsOver(): that
-- FrameXML helper no longer exists in 12.1 and calling it errors once per
-- frame while the panel is open ("attempt to call a nil value").
self._panel:SetScript("OnShow", function()
    self._panel:SetScript("OnUpdate", function()
        if not self._panel:IsMouseOver() and not self._trigger:IsMouseOver() then
```

### Guardarraíles añadidos

- **`.luacheckrc`**: `MouseIsOver` **fuera** de `globals` (con comentario), de modo que
  reintroducirlo lo caza el linter como global indefinido en vez de in-game.
- **`tests/mock_wow.lua`**: se declara `IsMouseButtonDown` (faltaba) y **a propósito NO** se declara
  `MouseIsOver`, así el mock refleja el cliente 12.1.
- **`tests/select_spec.lua`**: bloque *outside-click watcher* — el tick corre sin error y pregunta a
  panel/trigger por su propio `IsMouseOver`. Con el código viejo, el primer test falla.

## Regla general (para todo Craft)

Los **globales Lua de FrameXML** son API frágil y sin contrato: Blizzard los mueve o los borra entre
parches (12.1 se llevó `MouseIsOver`). En Craft:

1. Preferir **siempre** el método de widget equivalente (`region:IsMouseOver()`,
   `frame:IsMouseWheelEnabled()`, …) frente al helper global.
2. Si un global de FrameXML es inevitable, **leerlo con guarda** (`if X and X.Method then`) y dar
   fallback — nunca llamarlo a pelo, y menos dentro de un `OnUpdate`.
3. Todo global de FrameXML que Craft use debe estar en `globals` de `.luacheckrc` **y** en
   `tests/mock_wow.lua`; si no está en el mock, la suite no cubre esa ruta.

## Verificación

- `luac -p` OK; `luacheck` 0 warnings / 0 errors (38 archivos).
- Suite completa: **578 passed, 0 failed** (+2 nuevos en `select_spec`).
- Pendiente: abrir un Select in-game en 12.1 → sin errores Lua y el panel cierra al clicar fuera.

## Referencias

- Fix: [`Craft/components/Select.lua`](../../Craft/components/Select.lua#L252) (watcher OnShow/OnUpdate)
- Precedente correcto: [`Craft/components/Slider.lua`](../../Craft/components/Slider.lua#L224)
- Alternativa de diseño (no aplicada aquí): `Craft.Popover` cierra con un **catcher** a pantalla
  completa (`Popover.lua:82-87`) en vez de sondear en `OnUpdate`. Migrar Select al mismo patrón
  eliminaría el `OnUpdate` entero — candidato a FR de seguimiento, no a un hotfix.
- Consumidor: Bis (`Bis/libs/Craft/` — re-vendorear tras el próximo build)
