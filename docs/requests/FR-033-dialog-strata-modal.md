# FR-033 — `Craft.Dialog` se renderiza DETRÁS de una `Craft.Window` hermana (misma strata DIALOG)

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/components/Dialog.lua` (frame strata + overlay strata) + `Craft.lua`
(nueva escala de capas `Craft.Strata`)
**Tipo:** Bug + hardening de arquitectura (jerarquía de capas de librería)
**Prioridad:** Media-Alta — un modal abierto desde una `Craft.Window` queda inutilizable
(no se ve, no se puede cerrar, sus botones quedan tapados)
**Estado:** ✅ Resuelto y **verificado in-game** (Craft_Browser, 12.0.7, 2026-07-18): modal sobre
la Window, backdrop oscurece, arrastre + botones + ✕ funcionan. Pendiente release+bump por el
owner y re-vendoreo en Coffer (donde se puede borrar el workaround `liftDialog`).

---

## Problema

`Dialog:Create` fija:

```lua
self.frame:SetFrameStrata("DIALOG")     -- Dialog.lua ~49
...
self._overlay:SetFrameStrata("HIGH")    -- Dialog.lua ~59 (backdrop modal)
```

`Craft.Window` (FR-021) usa por defecto **la misma strata `DIALOG`** + `SetToplevel(true)`,
y se **eleva al hacer clic** (raise-on-click). Resultado: un Dialog abierto DESDE una Window
(caso típico: un botón/acción de la ventana abre un modal de export/import, confirmación, etc.)
nace en la MISMA strata que la Window, que acaba de ser la última elevada → **el Dialog queda
DETRÁS de la Window**. Y el overlay modal está en `HIGH`, que es **más BAJA que `DIALOG`**, así
que el backdrop tampoco cubre la Window (no bloquea clics, no oscurece).

## Síntoma observado (Coffer, in-game 12.0.7, 2026-07-18)

Editor de categorías (M8 F5b): el menú `⋯` abre un `Craft.Dialog` (lg) con un `Craft.Textarea`
para **exportar/importar** una categoría. La ventana de Settings es una `Craft.Window` (560×480,
strata DIALOG, toplevel). Al abrir el diálogo:

- **Aparece detrás** de la ventana de Settings (ambas centradas → el diálogo queda casi
  totalmente tapado).
- **No se puede cerrar**: la ✕ del diálogo queda debajo de la Window.
- **"No tiene botones"**: el botón Importar (parte baja del diálogo) queda tapado por la Window.

Los tres síntomas son la misma causa: strata insuficiente frente a una Window hermana.

## Workaround actual (Coffer)

Tras `dialog:Show()`, el consumidor sube a mano la strata del frame Y del overlay por encima
de `DIALOG`, y hace `Raise()` (accede a `dlg._overlay`, privado — frágil):

```lua
local f = dlg:GetFrame()
f:SetFrameStrata("FULLSCREEN_DIALOG")
f:SetToplevel(true)
if dlg._overlay then dlg._overlay:SetFrameStrata("FULLSCREEN_DIALOG") end
f:Raise()
```

(commit `dev` de Coffer 2026-07-18; `SettingsWin.lua` `liftDialog`.)

## Causa raíz — no era solo el Dialog, faltaba una jerarquía de capas de librería

El bug es síntoma de un problema mayor: **cada componente elegía su strata suelto**, sin una
escala común que garantizara el orden `página < modal < popover`. El reparto era incoherente:

| Elemento | Strata (antes) | Problema |
|---|---|---|
| `Craft.Window` (la "página") | `DIALOG` + toplevel + raise-on-click | — |
| `Craft.Dialog` (frame del modal) | `DIALOG` | **misma que la Window** → queda detrás |
| overlay/backdrop del Dialog | `HIGH` | **por debajo de DIALOG** → no cubre la Window |
| Popovers (Select/Combobox/Menu/Tooltip) | `TOOLTIP` (panel) | ✅ correcto, ya flotan sobre todo |
| Catcher click-outside de popovers | `FULLSCREEN_DIALOG` | ✅ correcto (bajo el panel, sobre el resto) |

Los **popovers NO tenían gap**: sus paneles ya viven en `TOOLTIP` (la strata más alta de WoW)
y sus catchers en `FULLSCREEN_DIALOG`, así que un dropdown abierto dentro de una Window ya
flotaba bien. El único roto era el Dialog.

## Solución implementada

### 1. Escala de capas centralizada — `Craft.Strata` (Craft.lua)

Fuente de verdad única del z-order de toda la librería, mapeada sobre las stratas fijas de WoW
(`BACKGROUND < LOW < MEDIUM < HIGH < DIALOG < FULLSCREEN < FULLSCREEN_DIALOG < TOOLTIP`):

```lua
Craft.Strata = {
    content = "MEDIUM",     -- contenido normal in-page (Panels heredan el del padre)
    page    = "DIALOG",     -- Craft.Window — el "main frame" / página del addon
    modal   = "FULLSCREEN", -- Craft.Dialog (frame + backdrop; frame 1 nivel sobre el backdrop)
    popover = "TOOLTIP",    -- Select/Combobox/Menu/Popover/Tooltip (siempre arriba)
}
```

```lua
Craft.Strata = {
    content      = "MEDIUM",             -- contenido normal in-page
    page         = "DIALOG",             -- Craft.Window — el "main frame" / página
    modalOverlay = "FULLSCREEN",         -- Craft.Dialog backdrop (sobre la Window, bajo el frame)
    modal        = "FULLSCREEN_DIALOG",  -- Craft.Dialog frame (sobre su backdrop + cualquier Window)
    popover      = "TOOLTIP",            -- Select/Combobox/Menu/Popover/Tooltip (siempre arriba)
}
```

Invariante garantizada: **`page (Window) < modalOverlay < modal (Dialog) < popover`**. El
catcher de click-outside de los popovers está en `FULLSCREEN_DIALOG` (igual que el frame del
modal), así que un dropdown abierto DENTRO de un modal sigue cerrándose al clicar fuera y su
panel (TOOLTIP) queda por encima.

### 2. Fix del Dialog (Dialog.lua)

- El frame va a la capa **`modal`** (`FULLSCREEN_DIALOG`) y el overlay a **`modalOverlay`**
  (`FULLSCREEN`), una strata **por debajo**. Ambos por encima de cualquier `Craft.Window`
  (`DIALOG`), así que el backdrop la cubre y el modal flota sobre ella.
- **Stratas DISTINTAS, no misma strata + frame-level.** El overlay tiene `EnableMouse(true)`
  (traga clics a la UI de abajo); si compartiera la strata del frame se tragaría también los
  botones y la ✕ del propio dialog (solo cerraría con Escape). Con el frame en una strata
  estrictamente superior, sus hijos ganan el mouse — la misma relación que el `DIALOG` sobre
  `HIGH` original.
- Nuevo config opcional **`strata`** en `Dialog:Create` (default = `Craft.Strata.modal`), como
  ya tiene `Window`; el overlay siempre va en `Craft.Strata.modalOverlay`.

`FULLSCREEN_DIALOG` (modal) queda siempre sobre `DIALOG` (Window) sin importar toplevel/raise
— el raise-on-click solo reordena DENTRO de una strata, nunca cruza a otra. Determinista.

- El frame del modal (y su overlay) se **parentan a `UIParent`**, no al `parent` del caller.
  Un modal es de nivel de pantalla; si el frame cuelga de la jerarquía del caller, su strata
  alta no se honra de forma fiable frente al overlay (hermano de UIParent). Ver post-mortem.

> ⚠️ **Post-mortem (dos regresiones y su corrección durante la implementación):**
>
> **(1) Misma strata + frame-level.** El primer intento puso frame + overlay en la MISMA strata
> (`FULLSCREEN`) separados por `SetFrameLevel`. In-game rompió TODOS los clics (solo Escape):
> el overlay full-screen con `EnableMouse` se comía los clics pese al frame-level. → Se pasó a
> stratas DISTINTAS (frame estrictamente sobre el overlay).
>
> **(2) Frame parentado al caller.** Con stratas distintas, el backdrop oscurecía pero el frame
> SEGUÍA sin recibir mouse (no se podía arrastrar ni clicar botones). Causa: el frame se creaba
> como hijo de `parent` (el contenido del Craft_Browser, dentro de un `ScrollFrame` en `HIGH`).
> **Una strata alta pedida por un frame enterrado en la jerarquía del caller NO se honra de
> forma fiable frente a un hermano de UIParent** (el overlay), así que el `FULLSCREEN_DIALOG`
> del frame no superaba al `FULLSCREEN` del backdrop y este se comía el mouse. → Se parenta el
> frame a `UIParent` (como el overlay y los paneles de popover, que sí flotan bien).
>
> **Lecciones:** (a) para "backdrop modal que bloquea abajo pero deja clicable arriba", el
> contenido va en una strata **estrictamente superior** al backdrop, nunca misma-strata +
> frame-level; (b) un frame que debe flotar sobre toda la UI se parenta a **`UIParent`**, no al
> frame del caller — la strata no basta si el frame está sepultado en otra jerarquía.

### 3. Window (Window.lua)

Su default de strata ahora apunta a `Craft.Strata.page` (mismo valor `DIALOG`, sin cambio de
comportamiento) para que la escala sea la única fuente de verdad.

## Impacto

- El patrón "una Window abre un Dialog" (muy común) funciona sin tocar nada: el modal flota
  sobre la ventana y el backdrop la oscurece y bloquea.
- **Coffer puede eliminar el workaround** de `SettingsWin.lua` `liftDialog` (ya no hace falta
  hurgar en el campo privado `_overlay` ni subir stratas a mano) tras re-vendorear el build.
- Los consumidores que usan Dialog sin Windows por encima no notan regresión: el modal sube
  respecto a la UI normal pero sigue por debajo de `TOOLTIP` (popovers/tooltips).
- **Sin cambios en los popovers** (Select/Combobox/Menu/Tooltip): ya estaban correctos; no se
  tocó su código, cero riesgo de regresión en su dismissal.

## Verificación

- `luac -p` OK · `luacheck` OK · suite de tests OK · `taintlint` OK.
- Los popovers no tienen spec afectado (paneles TOOLTIP intactos).
- Pendiente de verificación in-game 12.0.7 por el owner (bump de build antes de re-vendorear:
  un build empatado no gana el registro LibStub, ver CLAUDE.md #1).
