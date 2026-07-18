# FR-039 — Panel: slot `CardAction` (acción en esquina superior derecha del header)

**Reportado por:** Verificación in-game del Form Card "Payout Threshold" (Craft_Browser, 2026-07-18)
**Componente:** `Craft/components/Panel.lua` (shadcn: Card / `CardAction`)
**Tipo:** Feature (nueva API pública — requiere aprobación del maintainer)
**Prioridad:** Baja
**Estado:** 🕓 Propuesto

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

El Form Card en `Craft_Browser/pages/Panel.lua` omite el ✕ (queda anotado en el `NOTE:` del
render). No bloquea la demo.
