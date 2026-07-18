# FR-033 — `Craft.Dialog` se renderiza DETRÁS de una `Craft.Window` hermana (misma strata DIALOG)

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/components/Dialog.lua` (frame strata + overlay strata) + `Craft.lua`
(nueva escala de capas `Craft.Strata`)
**Tipo:** Bug + hardening de arquitectura (jerarquía de capas de librería)
**Prioridad:** Media-Alta — un modal abierto desde una `Craft.Window` queda inutilizable
(no se ve, no se puede cerrar, sus botones quedan tapados)
**Estado:** ✅ Resuelto (implementado en `dev` 2026-07-18; pendiente release+bump por el owner
y re-vendoreo en Coffer)

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

Invariante garantizada: **`page (Window) < modal (Dialog) < popover`**. El catcher de
click-outside de los popovers queda implícito en `FULLSCREEN_DIALOG` — entre `modal` y
`popover` — así que un dropdown abierto DENTRO de un modal sigue cerrándose al clicar fuera
y su panel queda por encima del modal.

### 2. Fix del Dialog (Dialog.lua)

- Frame y overlay pasan a la capa **`modal`** (`FULLSCREEN` por defecto) — misma strata para
  ambos, así el backdrop cubre de verdad cualquier `Craft.Window` (que está en `DIALOG`).
- El frame se eleva **1 frame-level por encima** del overlay
  (`SetFrameLevel(overlay:GetFrameLevel() + 10)`) para pintar sobre su propio backdrop. Strata
  y niveles se fijan una sola vez y no cambian → orden estable durante toda la vida del dialog
  (no depende de `Raise()` ni de timing).
- Nuevo config opcional **`strata`** en `Dialog:Create` (default = `Craft.Strata.modal`), como
  ya tiene `Window`; el frame siempre queda 1 nivel sobre su overlay aunque se cambie.

`FULLSCREEN` (modal) queda siempre sobre `DIALOG` (Window) sin importar toplevel/raise — el
raise-on-click solo reordena DENTRO de una strata, nunca cruza a otra. Por eso es determinista.

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
