# FR-004 — Icons: añadir iconos Lucide para Sentry

**Reportado por:** Sentry (consumer addon)
**Componente:** `Craft/icons/Atlas.lua` + `media/lucide.tga`
**Tipo:** Feature Request
**Prioridad:** Alta — la UI de configuración de Sentry los usa en navegación, editores y acciones
**Estado:** 🔵 Propuesto

---

## Problema

El atlas actual (`icons/Atlas.lua`, grid 8×8 = 64 slots, ~25 usados) no incluye varios iconos que la UI
de Sentry necesita para el árbol de packs, las hojas (auras/paneles), los tipos de trigger y las acciones.
Hay sitio de sobra en el atlas.

## Caso de uso (Sentry)

UI de configuración (ver `Sentry/docs/UI-DESIGN.md`): Sidebar como árbol de Packs (carpetas) → Auras y
Paneles; editores con tipos de trigger (Timer/Aviso/Fase/Custom) y de panel (Barra/Icono/Texto); barra de
acciones (import/export/borrar/mover).

## Solución propuesta

Añadir estos nombres Lucide al `_atlas` y regenerar `lucide.tga` (`scripts/export-icons.py`):

| Lucide | Uso en Sentry |
|---|---|
| `folder`, `folder-open` | Pack (carpeta) cerrada/abierta |
| `star` | Aura (hoja) |
| `layers` | Subcarpeta "Paneles" |
| `trash-2` | Borrar aura/panel/pack |
| `download`, `upload` | Exportar / importar pack |
| `clipboard-copy` | Copiar string de export |
| `x` | Cerrar ventana / quitar destino |
| `move` | "Mover en pantalla" (mover/sizer) |
| `clock` | Trigger BossMod Timer |
| `megaphone` | Trigger BossMod Aviso (Announce) |
| `flag` | Trigger BossMod Fase (Stage) |
| `code` | Trigger Custom (código) |
| `palette` | Selector de color |
| `bar-chart-3` | Tipo de panel Barra |
| `image` | Tipo de panel Icono |
| `type` | Tipo de panel Texto |

(17 iconos; entran en el atlas 8×8 actual.)

## Workaround actual (Sentry)

Ninguno limpio: usar iconos existentes aproximados (p. ej. `panel-left` para todo) degrada la legibilidad.

## Impacto

Solo additivo (no cambia API). Mejora la legibilidad de toda la UI de configuración (M7).
