# FR-039 — Panel: slot `CardAction` (acción en esquina superior derecha del header)

**Reportado por:** Verificación in-game del Form Card "Payout Threshold" (Craft_Browser, 2026-07-18)
**Componente:** `Craft/components/Panel.lua` (shadcn: Card / `CardAction`)
**Tipo:** Feature (nueva API pública — requiere aprobación del maintainer)
**Prioridad:** Baja
**Estado:** ✅ Implementado (en `dev`, 2026-07-18) — pendiente verificación in-game + bump/release

---

## Problema

shadcn `Card` ofrece el slot **`CardAction`**: un área en la esquina superior derecha
del header para acciones/badges/iconos complementarios (típicamente un botón ✕ de cerrar,
un icono, o un badge de estado). El ejemplo real "Payout Threshold" de shadcn muestra un
botón ✕ ahí.

`Craft.Panel` **no** implementa este slot (omisión de alcance MVP documentada en
`docs/components/panel.md` §"Diferencias conocidas vs shadcn" y `docs/design-reference.md`
§9.1). Al portar el Form Card a Craft_Browser el header queda sin el ✕ que sí aparece en la web.

**Escenario:** reproducir un Card de shadcn con acción de header (cerrar/menu/badge) → no hay
punto de anclaje ni API para colocar el widget en la esquina superior derecha del header, sin
solaparse con el `title`/`description`.

## Solución propuesta

Añadir un slot de acción al header, análogo a `GetContent()`/`GetFooter()`:

- Un método `Panel:GetHeaderAction()` (o `ShowHeaderAction(width)`) que devuelva un frame
  anclado a `TOPRIGHT` del header, alineado verticalmente con el `title`.
- El `title`/`description` deben reservar el ancho de la acción (no pasar por debajo de ella)
  — en shadcn el grid del header es `[1fr auto]` con la acción en la 2ª columna,
  `row-span` completo y `justify-self-end`.
- El caller instancia dentro su propio widget (p. ej. `Craft.Button` variant `ghost`/`icon`
  con el icono `x`), igual que hoy se hace con el footer.

Referencia shadcn (`card.tsx`): `CardAction` = `col-start-2 row-span-2 row-start-1
self-start justify-self-end`.

## Caso de uso

- Form Card "Payout Threshold" (Craft_Browser) — botón ✕ de cerrar en el header.
- Cualquier consumidor (Coffer, Beacon) que quiera un Card con acción/badge de header.

## Impacto

Cambio de **API pública** de `Craft.Panel` (nuevo método) → requiere aprobación del maintainer
y, según su criterio, entrada en el registro de cambios + bump de build. Aditivo: no altera el
comportamiento de panels existentes (sin acción → header idéntico al actual).

## Workaround actual

~~El Form Card en `Craft_Browser/pages/Panel.lua` omite el ✕ (queda anotado en el `NOTE:` del
render).~~ Resuelto — la demo ya muestra el ✕.

## Resolución (en `dev`)

Implementado sobre `Craft.Grid` (FR-040), que era el consumidor previsto del motor `[1fr auto]`:

- **API nueva** en `Craft.Panel`: `config.action` (Frame prebuilt, reparentado al header),
  `SetHeaderAction(frame)` / `GetHeaderAction()`. Aditivo — panels sin acción conservan el
  layout de header histórico (ancla única) sin cambios de conducta.
- **Layout**: con acción, el header se maqueta con `Craft.Grid.new(header, {columns={"1fr","auto"}})`
  — la columna `1fr` apila título/descripción, la `auto` lleva la acción `justify-self:end`,
  `self-start`, `row-span` completo. El título pasa a `SetWordWrap(false)` (`truncate`). Filas en
  px para no depender del alto natural de FontString en `Grid:Add`. Alto del header =
  `lg + max(texto, acción)`.
- **Robustez**: `panel.frame:HookScript("OnSizeChanged")` recomputa el header si el panel se
  dimensiona tras `Create()` (el guard de ancho 0 de Grid haría no-op en el primer layout).
- **Demo**: `Craft_Browser/pages/Panel.lua` — el Form Card "Payout Threshold" muestra un
  `Craft.Button` variant `ghost` size `icon` con icono `x` como CardAction.
- **Tests**: `tests/panel_spec.lua` NUEVO (7 tests) — path manual sin cambios + geometría del
  grid `[1fr auto]` + crecimiento de alto + `SetHeaderAction(nil)` revierte a manual.
- **Verificación local**: `luac -p` OK, luacheck 0/0, taintlint 0/0, suite 315 tests.

Pendiente maintainer: verificación in-game, bump de build (`bump-build.sh`) + release + re-vendoreo.
