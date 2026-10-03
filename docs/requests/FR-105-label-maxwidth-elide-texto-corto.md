# FR-105 — Label con `maxWidth` elide textos más cortos que el máximo

**Solicitante:** SMRT (2026-10-02), portada de planes de la Timeline (`modules/Timeline/wow/Landing.lua`).
**Componentes:** `components/Label.lua` (`_recalcSize`).
Referencia: build vendoreado 2.28.0.
**Tipo:** Bug.
**Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-02), release 2.31.0.
**Prioridad:** Media. **No bloquea:** SMRT recorta el texto a mano (sin `maxWidth`) mientras tanto.

---

## Síntoma

Una tarjeta por jefe con su nombre en `Craft.Label:Create(f, { weight = "bold", flags = "",
maxWidth = 148 })` y `:SetText(nombre)` después de crearla. En el juego:

- «Sszorak» → «Sszor…», «Ula'tek» → «Ula't…»: textos de ~40-50 px, **muy por debajo** de los
  148 px del máximo, salen cortados.
- Los nombres largos («Nek'zali the Soulcoiler») sí se cortan donde toca, en el máximo.

O sea: cuando el ancho natural es **menor** que `maxWidth`, el texto se elide igual.

## Causa probable (sin verificar)

En `_recalcSize`, con `maxWidth` y `natural < maxWidth`, se hace `text:SetWidth(natural)`: la
FontString queda fijada exactamente a su ancho medido. Dos sospechas:

1. Redondeo de subpíxel: el ancho exacto no basta y WoW elide el último glifo (como el bug de
   FR-025 con las texturas `|T|t`).
2. La medida se toma con la fuente anterior (antes del peso `bold`, o antes de que cargue Inter,
   bug #4) y se queda corta cuando se aplica la definitiva.

## Petición

Que un `Label` con `maxWidth` solo elida cuando el texto de verdad no cabe: p. ej. no fijar el
ancho de la FontString cuando `natural <= maxWidth` (o fijarlo a `maxWidth`, no a `natural`), y
volver a medir tras cambiar la fuente.

## Fallback en el consumidor

SMRT crea el Label sin `maxWidth` y recorta el texto por caracteres midiendo con
`GetTextWidth()` hasta que cabe. Se quitará al re-vendorear el build con el arreglo.

## Resolución

Causa: la sospecha 1 (redondeo sub-píxel). `_recalcSize` fijaba `text:SetWidth(natural)` aunque el
texto cupiera. Fix: `SetWidth` explícito **solo si `natural > maxWidth`**; si cabe, el string queda
sin constraint (auto-size, no puede elidir) y el frame abraza el natural — semántica de `truncate`
en shadcn. La sospecha 2 ya estaba cubierta: `_applyTheme` re-mide tras `applyFont` (también en
cada asentamiento de TTF, bug #4) y `SetText` re-mide siempre.

- Código: `Craft/components/Label.lua` (`_recalcSize`).
- Tests: `tests/label_spec.lua` — 2 regresiones (texto que cabe no fija ancho; largo↔corto alterna).
- Demo: `Craft_Browser/pages/Label.lua` — fila «FR-105» con los nombres de SMRT + botón toggle
  corto/largo que imprime anchos de frame y string.
