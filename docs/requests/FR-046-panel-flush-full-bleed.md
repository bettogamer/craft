# FR-046 — `Craft.Panel`: contenido *full-bleed* (`flush` / `paddingY=0`)

**Reportado por:** shadcn-mapper al portar el demo "Card + Sidebar — Financial dashboard nav"
(2026-07-19)
**Componente:** `Craft/components/Panel.lua` (shadcn: `card` — `.cn-card` sin `CardContent`)
**Tipo:** API pública nueva (flag de composición) — requiere aprobación del maintainer
**Prioridad:** Media (desbloquea toda una familia de ejemplos "Card envolviendo contenido
full-bleed": sidebars, imágenes, tablas, mapas)
**Estado:** ✅ Implementado (2026-07-19). Se implementaron **ambas** opciones que componen:
`config.paddingY` (Opción A — eje vertical, default `nil`=`lg`) como mecanismo base, y
`config.flush = true` (Opción B — azúcar que fuerza `padding=0` + `paddingY=0`) para el caso
"Card marco". Solo afecta la rama sin header y sin footer (los gaps `gap-4` de header/footer no se
tocan). El demo "Card + Sidebar" pasó del fallback `padding=0` a `flush=true`.

---

## Problema

El markup real de varios ejemplos de shadcn envuelve contenido **sin `CardContent`** y con `py-0`
en el propio `.cn-card` → el hijo cuelga *full-bleed* del Card (pegado al ring por los 4 lados,
solo el `overflow-hidden` recorta). Ejemplo que lo motiva (dashboard nav financiero):

```html
<div data-slot="card" class="cn-card ... overflow-hidden py-0">
  <div data-slot="sidebar-wrapper" ...>   <!-- Sidebar directo, sin card-content -->
```

En `Craft.Panel`, `config.padding` sólo controla el **padding horizontal** (LEFT/RIGHT,
[`Panel.lua:265-266`](../../Craft/components/Panel.lua#L265-L266)). El **vertical está hardcodeado**
a `t.spacingLg` (16px) en el borde superior e inferior del content
([`Panel.lua:273`](../../Craft/components/Panel.lua#L273) y
[`Panel.lua:281`](../../Craft/components/Panel.lua#L281)). No hay forma de pedir 0px verticales.

**Escenario:** cualquier ejemplo "Card como marco de contenido full-bleed". Con Craft el contenido
queda con ~16px de aire arriba/abajo que shadcn no tiene → el Sidebar/imagen/tabla no llega al
ring. Divergencia visible respecto a Lyra.

## Solución propuesta

Añadir un modo *flush* que zeroee el padding vertical del content (y componga con `padding=0`
para el horizontal, ya soportado). Dos formas posibles — elegir una en implementación:

- **Opción A (simétrica con `padding`):** `config.paddingY` (default `16`), análogo a como
  `config.padding` maneja el horizontal. `paddingY=0` → content pegado arriba/abajo.
- **Opción B (flag booleano):** `config.flush = true` → equivale a `padding=0` + `paddingY=0`
  (full-bleed completo en un solo flag). Más legible para el caso "Card marco".

En `_layoutFrames`, sustituir el `lg` hardcodeado de los anclajes TOP/BOTTOM del content por el
valor configurable (`paddingV`), **sólo en la rama sin header y sin footer** (con header/footer el
gap `gap-4` sigue viniendo del layout de esas piezas, no del padding del content — no tocar esa
semántica salvo que el ejemplo lo pida).

## Alcance mínimo (MVP)

- Un solo eje nuevo: padding vertical configurable del content (Opción A o B).
- Sólo afecta la rama "sin header / sin footer" (el caso full-bleed puro).
- Sin cambios en el header grid ni en el footer p-4.
- Retro-compatible: default 16px = comportamiento actual.

## Consideraciones de implementación

- **`padding` ya cubre el horizontal:** no duplicar; el nuevo eje es sólo vertical. Con Opción B,
  `flush` debe además forzar `padding=0` horizontal.
- **Header/footer:** con header visible el content se ancla a `header:BOTTOM - lg`
  ([`Panel.lua:270`](../../Craft/components/Panel.lua#L270)); con footer, a `footer:TOP + lg`
  ([`Panel.lua:278`](../../Craft/components/Panel.lua#L278)). El flush full-bleed aplica al caso
  típico (Card marco = sin header ni footer). Decidir si `paddingY` también overridea esos gaps o
  se limita a la rama pelada (recomendado: limitarlo, para no romper los Cards con header/footer
  existentes).
- **Tests:** añadir a `tests/panel_spec.lua` — con `paddingY=0`/`flush`, el content se ancla a
  `frame:TOP` con offset 0 (no `-lg`); default sigue en 16px.
- **Spec:** actualizar `docs/components/panel.md` (fila `padding` → documentar el nuevo eje/flag).

## Referencias

- Spec del componente: [`docs/components/panel.md`](../components/panel.md)
- Demo que lo motiva: "Card + Sidebar — Financial dashboard nav" en
  `Craft_Browser/pages/Panel.lua` (construido con el fallback `padding=0`)
- FR hermano de padding: [`FR-035`](FR-035-panel-header-anclas-footer-padding.md)
