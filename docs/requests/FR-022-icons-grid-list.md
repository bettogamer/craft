# FR-022 — Icons: `layout-grid` y `list` en el atlas (toggle de modo de vista)

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/icons` (atlas Lucide: `scripts/export-icons.py` + `icons/Atlas.lua`)
**Tipo:** Feature Request
**Prioridad:** Media — hay fallback semántico débil (`menu` / `grip-vertical`), funcional pero impreciso
**Estado:** Implementado en `dev` (2026-07-12) — el atlas estaba lleno (63/64 slots): creció a 512×1024 (8×16, 128 slots), ver CHANGELOG [Unreleased]

---

## Problema

El atlas no tiene ningún icono que represente "vista de grilla" ni "vista de lista". Los
disponibles más cercanos son `menu` (hamburguesa, pasa por "lista"), `grip-vertical` (6 puntos,
pasa por "grilla" con squint) y `panel-left`/`layers` (semántica distinta). Un toggle de modo de
vista grid/list —patrón de UI universal— no se puede iconografiar con precisión.

## Caso de uso (Coffer)

Decisión del owner (ADR-0004 de Coffer): cada window lleva en su header delgado **UN botón
toggle grid/list que alterna icono ▦/☰**. Lucide tiene exactamente ese par: `layout-grid` (▦)
y `list` (☰). Aplica a los 4 windows (MainFrame + 3 bancos).

## Solución propuesta

Añadir a la lista de exportación del atlas los Lucide:

- `layout-grid` — vista de grilla (▦)
- `list` — vista de lista (☰)

(Opcional, mismo tema si se quiere margen: `layout-list`, `grid-2x2`.)

## Workaround actual (Coffer)

Usar `menu` como "lista" y `grip-vertical` como "grilla" en el toggle del header. Funciona con
tooltip (FR-020) explicando el modo, pero el glifo de grilla es confuso. Al re-vendorear con los
iconos nuevos solo cambian dos strings de nombre.

## Impacto

Aditivo (dos glifos más en `lucide.tga` + entradas en `Atlas.lua`). Sin cambio de API.
