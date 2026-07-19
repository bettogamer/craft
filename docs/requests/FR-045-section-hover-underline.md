# FR-045 — `Craft.Section`: `hover:underline` en el trigger del accordion

**Reportado por:** Auditoría de `Craft.Section` (shadcn-auditor) al portar el demo "FAQ card"
(2026-07-19) — mismo origen que [FR-044](FR-044-section-title-wrap.md)
**Componente:** `Craft/components/Section.lua` (shadcn: `accordion` — `.cn-accordion-trigger`)
**Tipo:** Fidelidad (estado hover ausente en un componente existente)
**Prioridad:** Baja (cosmético; bajo impacto — no bloquea ningún port)
**Estado:** 🅿️ Propuesto (2026-07-19). No implementado. Fallback: hoy el trigger no da
feedback de hover; el click funciona igual.

---

## Problema

`.cn-accordion-trigger` (Lyra) incluye `hover:underline` — al pasar el mouse por la cabecera, el
título se **subraya**. `Craft.Section` sólo cablea `OnClick` en el `_header` (`Section.lua`), sin
`OnEnter`/`OnLeave`, así que no hay ningún feedback de hover: el título se ve idéntico en reposo y
bajo el cursor.

**Escenario:** cualquier accordion/section en Craft — el usuario no percibe que la cabecera es
interactiva hasta que hace click. shadcn lo señaliza con el subrayado en hover.

## Solución propuesta

WoW **no** tiene decoración de texto (`text-decoration`/underline nativo en FontString), así que el
subrayado se dibuja con una **textura de 1px** bajo el título, visible sólo en hover:

- Crear `self._titleUnderline` (Texture, `BORDER`/`OVERLAY`) pintada con `t.foreground` (mismo
  color que el texto), alto 1px pixel-perfect vía `Craft.Theme.SetPixelHeight(_, 1)` (ADR-0011).
- Anclarla **bajo la línea base del título**: `TOPLEFT`/`TOPRIGHT` al `BOTTOMLEFT`/`BOTTOMRIGHT`
  del `_title`, o su ancho = `_title:GetStringWidth()` (acotado al ancho reservado del título,
  FR-044). Ocultarla por defecto.
- `self._header:SetScript("OnEnter", …)` → mostrar; `OnLeave` → ocultar. **Componer con el
  `OnClick` ya existente** (no pisarlo).
- Re-aplicar color/grosor en `_applyTheme` (depende de tema + escala, como el resto de líneas).

### Consideración: título envuelto (multi-línea, FR-044)

`hover:underline` en CSS subraya **todas** las líneas del texto envuelto. Una única textura sólo
cubre una línea. Para el MVP basta subrayar el **caso de 1 línea** (el normal en estos triggers);
para títulos que envuelven a 2+ líneas queda como degradación aceptable (subrayar sólo la última
línea, o el ancho reservado completo). Replicar el subrayado por-línea exacto queda **fuera de
alcance** salvo demanda.

## Alcance mínimo (MVP)

- Sólo `Craft.Section` (hover en el trigger). Sin cambios de API pública.
- Una textura de subrayado 1px `t.foreground`, show/hide en `OnEnter`/`OnLeave`.
- Título de 1 línea = fidelidad total; multi-línea = degradación documentada.

## Consideraciones de implementación

- **No pisar `OnClick`:** el `_header` ya tiene `OnClick` (`Section:Toggle`). Añadir `OnEnter`/
  `OnLeave` sin tocarlo.
- **Ancho del subrayado:** usar `_title:GetStringWidth()` (acotado al ancho reservado) para que el
  subrayado siga al texto, no al header completo. Re-medir donde se re-mide el header
  (`_remeasureHeader`/`_applyTheme`) por si cambia el título o la fuente (bug #4).
- **Tests:** añadir a `tests/section_spec.lua` — `OnEnter` muestra el subrayado y `OnLeave` lo
  oculta; el color es `t.foreground`; `OnClick` sigue togglando (no se pisó).
- **Spec:** actualizar `docs/components/section.md` (fila hover en dimensiones/estados).

## Referencias

- Spec del componente: [`docs/components/section.md`](../components/section.md)
- Origen y FR hermano: [`FR-044`](FR-044-section-title-wrap.md) (misma auditoría, demo "FAQ card")
- CSS Lyra: `.cn-accordion-trigger { @apply … hover:underline … }` (ver spec §"CSS de referencia")
