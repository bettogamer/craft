# FR-030 — Icono Lucide `pencil` en el atlas

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** `Craft/icons/Atlas.lua` (+ regeneración de `media/lucide.tga`)
**Tipo:** Feature Request
**Prioridad:** Baja — Coffer tiene fallback funcional; puro pulido de affordance
**Estado:** ✅ Implementado en `dev` (2026-07-16) — `pencil` añadido al atlas en `{ 7, 7 }` (slot 64/128), regeneración completa de `lucide.tga` + `Atlas.lua` vía `scripts/export-icons.py`. Aditivo, sin API nueva. Ver CHANGELOG [Unreleased].

---

## Problema

El atlas Lucide de Craft no incluye `pencil` (ni `pen`/`edit`/variantes). Es el icono
canónico de "renombrar/editar inline" en shadcn (p. ej. el ✎ de un item editable).

## Caso de uso (Coffer)

Editor de secciones WYSIWYG de M8 F4b (`SortedBags/docs/plan-m8-settings.md` §Secciones):
el diseño aprobado dibuja `✎` junto al nombre de cada sección para renombrarla. Sin el
icono, el affordance de rename queda invisible.

## Workaround actual (Coffer)

El nombre de la sección es un botón clicable (highlight al hover + tooltip "Clic para
renombrar") que abre el Input inline. Funciona, pero el affordance es menos descubrible
que el ✎ del diseño.

## Solución propuesta

Añadir `pencil` (Lucide) al atlas en la próxima regeneración. Aditivo, sin API nueva:
`Craft.Icons.Apply(tex, "pencil", size)` ya funcionaría al existir la entrada.

## Impacto

Una celda más en el atlas + una entrada en `Atlas.lua`. Riesgo nulo.
