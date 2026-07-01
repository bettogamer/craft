# FR-013 — Icons: lock / magnet para los toggles de edit-mode de Beacon

**Reportado por:** Beacon (consumer addon — fork de WeakAuras para WoW 12.0.7)
**Componente:** `Craft/icons/Atlas.lua` + `media/lucide.tga` + `scripts/export-icons.py`
**Tipo:** Feature Request
**Prioridad:** Media — pulido visual del header de opciones de Beacon (hay workaround)
**Estado:** Cerrado (build 6)

---

## Problema

El header de opciones de Beacon tiene dos toggles globales de "edit mode" (afectan a las auras en
pantalla): **Lock Positions** y **Magnetically Align**. Se están migrando a `Craft.Button` con estilo
Craft, pero el atlas actual (build 5) no incluye iconos para "candado" ni "imán", así que esos dos
botones no pueden usar iconos lucide todavía (la X del header ya usa `x`, que sí existe).

## Caso de uso (Beacon)

Header de la ventana de opciones (`OptionsFrame.lua`): botones de icono a la derecha del título —
**X** (cerrar, ya con lucide `x`), **magnet** (alinear magnéticamente, toggle) y **lock** (fijar
posiciones, toggle). El estado on/off se expresará con variantes/tinte del botón; solo falta el glyph.

## Solución propuesta

Añadir estos nombres Lucide al `_atlas` (catálogo `ICONS` en `scripts/export-icons.py`) y regenerar
`lucide.tga`:

| Lucide | Uso en Beacon |
|---|---|
| `lock` | Toggle "Lock Positions" (estado activo) |
| `lock-open` | Toggle "Lock Positions" (estado inactivo) — opcional, para icono de dos estados |
| `magnet` | Toggle "Magnetically Align" |

(2-3 iconos; entran de sobra en el atlas 8×8 — quedan ~19 slots libres tras build 5.)

## Workaround actual (Beacon)

Los toggles magnet/lock siguen como `BeaconToolbarButton` (AceGUI) con sus texturas propias
(`magnetic` / `lockPosition`) hasta que lleguen los iconos; funcionales, solo estéticamente fuera del
estilo Craft.

## Impacto

Solo additivo (no cambia API de ningún componente). Completa la migración del header de Beacon al
estilo Craft.

## Resolución (build 6)

Los 3 nombres Lucide (`lock`, `lock-open`, `magnet`) se añadieron al catálogo `ICONS` de
`scripts/export-icons.py` tras `rotate-ccw` (FR-012); el atlas se regeneró — coords `{5,5}`, `{6,5}`,
`{7,5}` (grid 8×8 sin cambios, quedan 16 slots libres). Se incluyó `lock-open` (opcional en el FR) para
soportar el toggle de dos estados. `Craft/media/lucide.tga` está gitignoreado (lo rebuildea deploy);
solo se commitean `Atlas.lua`, `icons.md`, `export-icons.py`. `CRAFT_BUILD` 5 → 6 para que la
registración versionada sirva el atlas nuevo a los consumers.
