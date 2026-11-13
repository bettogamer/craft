# FR-147 — `Theme.hairline` y `Theme.pixelInset`: líneas e insets de 1 px declarativos

**Solicitante:** Craft (revisión de NaowhForever, 2026-11-13).
**Componente:** `Craft/theme/Theme.lua`; usuarios: Separator, Section, Tabs, Window, Sidebar, Badge,
Select, Combobox (insets de relleno `px1`).
**Tipo:** Refactor / API interna.
**Prioridad:** Baja. **Depende de:** FR-142 (fase 2, re-ajuste por región).
**Estado:** implementado en dev (2026-11-13, sin release). `Craft.Theme.hairline(tex, axis
[, anchorTo, edge, n])`, `Craft.Theme.pixelInset(region, n, relativeTo)` (n < 0 = hacia fuera) y el
genérico `Craft.Theme.onPixelRefit(region, fn)`, todos sobre el registro de FR-142. `AnchorBorder` usa
`hairline` para las tiras sup/inf. Migrados sin cambio de geometría: Badge (`_bg` inset), Window
(`_bg` inset); Separator ya queda cubierto porque `SetPixelWidth/Height` se registran solos. El resto de
los ~27 sitios `px1` siguen re-aplicándose en su `_applyTheme`, que `RefreshPixels` re-ejecuta; se
migrarán cuando se toquen.

---

## Necesidad

Hoy cada componente repite a mano la misma receta: `local px1 = Craft.Theme.px(1, frame)` en
`_applyTheme` + `SetPoint(..., px1, -px1)` para insetar un relleno, o `SetPixelHeight(tex, 1)` +
dos anclas para un separador. Son ~27 sitios con la misma lógica y cada uno debe acordarse de
re-aplicarla al cambiar la escala (FR-142).

NaowhForever lo expresa una vez por región: `ns.PixelInset(region, n, relativeTo)` y `ns.Border`
con `SetPixels(n)` (`Core/Core.lua:666-720`), y su registro de ajuste lo re-aplica solo.

## Propuesta

Sobre el registro de FR-142:

- `Craft.Theme.hairline(tex, axis, anchorTo)`: tira de 1 px físico horizontal (`"h"`) o vertical
  (`"v"`), anclada a lo largo de `anchorTo`; se re-ajusta sola.
- `Craft.Theme.pixelInset(region, n, relativeTo)`: `region` ocupa `relativeTo` menos `n` px físicos
  por lado (n negativo = hacia fuera, para anillos concéntricos / `ring-offset` en el futuro); se
  re-ajusta sola.
- `AnchorBorder` pasa a apoyarse en `hairline`.
- Migrar componente a componente (sin cambio visual), empezando por Badge (`_bg` inset), Window
  (`Window.lua:435`) y Separator.

## Criterio de aceptación

- Specs de los helpers con `GetEffectiveScale` simulado (dos escalas → dos grosores).
- Suite completa sin cambios de geometría en los componentes migrados.

## Referencias

`docs/research/naowhforever-ui-patterns.md` §1.2 y §4; FR-142; FR-058.
