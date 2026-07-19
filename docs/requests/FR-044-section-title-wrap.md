# FR-044 — `Craft.Section`: título del trigger envuelve + `line-height` 16 (header dinámico)

**Reportado por:** Auditoría de `Craft.Section` (shadcn-auditor) al portar el demo "FAQ card"
(Tabs + Accordion) a Craft_Browser (2026-07-19)
**Componente:** `Craft/components/Section.lua` (shadcn: `accordion` — `.cn-accordion-trigger`)
**Tipo:** Bug / fidelidad (dimensiones + layout de un componente existente)
**Prioridad:** Media (título largo en card angosta se dibuja **encima** del chevron)
**Estado:** ✅ Implementado (2026-07-19). `LINE_H 14→16`, `HEADER_H` constante → header
**dinámico** derivado del título envuelto; `_title` con `SetWordWrap(true)` + ancho reservado
para el chevron. Tests nuevos en `tests/section_spec.lua` (6 casos); spec
`docs/components/section.md` actualizado. Suite 363. Pendiente: verificación in-game +
bump/release/re-vendoreo por el owner.

---

## Problema

El trigger de una `Craft.Section` asumía **una sola línea** de título:

1. `LINE_H = 14` (`Section.lua:27`) y `HEADER_H = 34` **constante** — el header nunca crecía.
2. El `_title` era un FontString con **una sola ancla `LEFT`**, **sin** `SetWidth` ni
   `SetWordWrap` — un título largo se extendía en una sola línea sin límite de ancho.

Como el título es capa `OVERLAY` y el chevron `ARTWORK`, un título largo en una card angosta
(caso real del demo FAQ: *"How secure is my financial data with Ledger?"* en una card de ~340px)
se dibuja **por encima** del chevron y se sale del header.

Además, `LINE_H = 14` estaba **mal**: el devtools del owner sobre `.style-lyra
.cn-accordion-trigger`/`.cn-accordion-content` confirmó `line-height = var(--text-xs--line-height,
calc(1 / .75))` = **1.33333 unitless** → con `font-size: text-xs` (12px) = **16px**, no 14.

**Escenario:** cualquier accordion/section con títulos que no caben en una línea (FAQs, secciones de
formulario largas) en contenedores angostos → texto encimado + header de altura incorrecta.

## Solución implementada

- **`LINE_H` 14 → 16**; `HEADER_H` constante → `HEADER_MIN = PAD_V*2 + 16 = 36` (piso de 1 línea).
- **Header de altura dinámica**: el `_title` se ancla **`TOPLEFT`** (ancla única, bug #2), con
  `SetJustifyV("TOP")` + `SetWordWrap(true)` y ancho reservado `headerW − CHEVRON_SZ(16) − GAP(8)`.
  La altura del header se deriva del alto del título envuelto (`_remeasureHeader`), con piso
  `HEADER_MIN`, y se publica en un **signal reactivo `_headerH`**; el alto del frame
  (`_headerH() + prog·bodyH`) se re-deriva sin re-animar.
- **Chevron** re-anclado `TOPRIGHT` (shadcn `items-start`, top-aligned con la 1ª línea).
- **Re-medición**: en `OnSizeChanged` del header (el consumidor fija el ancho del frame **después**
  de `Create`) y en `_applyTheme` (cubre la carga tardía de la fuente Inter, CLAUDE.md bug #4).

### Por qué reactivo y no un simple `SetHeight`

El alto del frame ya lo maneja un `Weave.computed` (`HEADER_H + prog·bodyH`) para animar el
expand/collapse. Hacer `_headerH` un signal permite que ese computed se re-ejecute y **snapee** el
alto colapsado/expandido cuando el título cambia de nº de líneas (resize, cambio de fuente,
`SetTitle`) sin re-animar — sólo el toggle mueve `prog`.

## Alcance

- Sólo `Craft.Section` (el consumidor apila varias = accordion). Sin cambios de API pública.
- `GAP = 8px` de reserva entre título envuelto y chevron (cosmético; shadcn no fija gap explícito en
  `.cn-accordion-trigger` — el icono es `ml-auto`). Ajustable in-game.
- **No** se auto-dimensiona el *contenido* (respuesta) — eso es el frame que pasa el consumidor vía
  `SetContent`; sigue siendo responsabilidad del consumidor medir su propio alto.

## Verificación

- `luac -p`, `luacheck` (0 warnings), `lua tests/run.lua … tests/section_spec.lua` (6 casos nuevos:
  piso 36, word-wrap activo + ancla única, reserva de ancho del chevron, piso con título corto,
  re-medición en `SetTitle`, no-op sin ancho). Suite completa **363 passed**.
- Mock (`tests/mock_wow.lua`): `GetStringHeight` es 1 línea fija → el **crecimiento por wrap** es
  puramente visual y se verifica **in-game**; los tests fijan lo determinista (piso, reserva, wrap
  flag, anclas). Se añadió al mock: recorder de `SetWordWrap` y `Set/GetRotation` en texturas.

## Notas de fidelidad Lyra (propagadas)

- `text-xs line-height = 1.33333 unitless → 16px` propagado a `docs/lyra-tokens.md`.
- Confirmado por devtools (no cambia, ya correcto en Craft): `py-2.5`=10, `text-xs`=12,
  `font-weight-medium`=500, `text-align:left`, `size-4` chevron, **sin** fondo muted al expandir
  (eso está en luma/maia/mira/rhea, NO en `style-lyra`).

## Follow-ups (no en este FR)

- **FR-045** — `hover:underline` en el trigger (`.cn-accordion-trigger` lo tiene; Craft sólo tiene
  `OnClick`). Menor, bajo impacto.
- **disabled/aria-disabled** no modelado — fuera de alcance salvo demanda.

## Referencias

- Spec del componente: [`docs/components/section.md`](../components/section.md)
- Tokens Lyra: [`docs/lyra-tokens.md`](../lyra-tokens.md) (`text-xs` line-height)
- Origen: demo "FAQ card" en `Craft_Browser/pages/Panel.lua` (2026-07-19)
