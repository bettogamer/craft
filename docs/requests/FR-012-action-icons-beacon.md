# FR-012 — Icons: iconos de acción para Beacon (test-fire / selector)

**Reportado por:** Beacon (consumer addon — fork de WeakAuras para WoW 12.0.7)
**Componente:** `Craft/icons/Atlas.lua` + `media/lucide.tga` + `scripts/export-icons.py`
**Tipo:** Feature Request
**Prioridad:** Media-Alta — bloquea el pulido visual de 2 ventanas nuevas de Beacon (hay workaround)
**Estado:** Cerrado (CRAFT_BUILD 5) — `circle-play` / `circle-stop` / `rotate-ccw` añadidos al atlas;
`corner-down-left` excluido (ver abajo). Re-vendorear el build en Beacon.

---

## Problema

El atlas actual (`icons/Atlas.lua`, grid 8×8 = 64 slots, ~41 usados tras FR-004) no incluye los iconos
de **acción** que las 2 ventanas nuevas de Beacon necesitan: disparar / detener / re-disparar un evento
de prueba, y "usar/insertar" una selección. Hay sitio de sobra en el atlas (additivo).

## Caso de uso (Beacon — clúster de creación de auras v0.2)

Beacon captura eventos de boss-mods (DBM/BigWigs) en un historial y ofrece dos ventanas hechas con Craft:

- **Modo prueba** (`Craft.Window` flotante): lista el historial; **clic en una fila dispara** ese evento
  sintético en pantalla para ver reaccionar las auras → acción primaria = **play**. Además botones de
  **detener** y **re-disparar** el último.
- **Selector** (`Craft.Panel` acoplado): lista el historial para **rellenar un trigger**; la acción de
  fila es "usar/insertar en el trigger".

## Solución propuesta

Añadir estos nombres Lucide al `_atlas` (catálogo `ICONS` en `scripts/export-icons.py`) y regenerar
`lucide.tga`. Para la acción de fila del Selector se reutiliza `chevron-right` (ya en el atlas):

| Lucide | Uso en Beacon |
|---|---|
| `circle-play` | Disparar test-fire (acción de fila en Modo prueba); botón "Probar" de la toolbar |
| `circle-stop` | Botón "Detener" el test-fire |
| `rotate-ccw` | Botón "Re-disparar" el último evento |

(3 iconos; entran en el atlas 8×8 actual — quedan ~22 slots libres tras añadirlos.)

### Excluido: `corner-down-left`

Se **descarta** de este FR. Motivos:

- El propio FR lo marcaba como **opcional**: la acción "usar / insertar en el trigger" del Selector
  ya se cubre con **`chevron-right`**, que existe en el atlas y comunica adecuadamente "avanzar /
  aplicar la selección".
- Se prefiere mantener las adiciones al atlas **acotadas a lo estrictamente necesario** (los 3
  botones del Modo prueba que hoy no tienen glyph equivalente), evitando sumar un icono cuya
  distinción visual frente a `chevron-right` es marginal en este contexto.
- Si más adelante Beacon comprueba que `chevron-right` no transmite bien la semántica de
  "insertar", basta con un FR de seguimiento (o ampliar este) para añadir `corner-down-left` —
  el atlas tiene slots de sobra y el cambio es aditivo y barato.

## Workaround actual (Beacon)

Glyphs de texto (▶ / ■ / ↻) o iconos existentes aproximados en los botones de acción mientras tanto.
Funcional pero menos legible/consistente con el resto de la UI Craft.

## Impacto

Solo additivo (no cambia API de ningún componente). Mejora la legibilidad y consistencia de las dos
ventanas del clúster de creación de Beacon.
