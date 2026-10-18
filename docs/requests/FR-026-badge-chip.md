# FR-026 — Badge/Chip: etiqueta compacta con ✕ opcional y drag entre contenedores

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** nuevo — `Craft/components/Badge.lua` (shadcn: Badge; variante interactiva "chip")
**Tipo:** Feature Request
**Prioridad:** Media — lo usan 3 páginas del rediseño de Settings de Coffer (M8, plan aprobado 2026-07-13); hay fallback
**Estado:** ✅ Implementado PARCIAL (2026-07-13, dev — pendiente de release): Badge estático +
chip removable/selectable en `Craft/components/Badge.lua` (spec `docs/components/badge.md`,
18 tests). Se tomó el split que propone este FR: **el drag entre contenedores queda para un
FR aparte** (registro de drop-zones con superficie de diseño propia). Notas de implementación:
sin `size` (`.cn-badge` de Lyra es single-size h-5); `selected` fill = `t.muted` (paridad
Toggle pressed); exclusividad de grupo la coordina el caller.

---

## Problema

Craft no tiene un componente de **etiqueta compacta** (shadcn Badge) ni su variante
interactiva (chip removible/arrastrable). Coffer lo necesita en tres lugares del rediseño de
Settings:

1. **Reglas de categoría como chips** (página Categorías, patrón filter-builder estilo
   Linear/GitHub): `(Tipo: Consumible▸Pociones ✕)` `(incluye "flask" ✕)` — texto + icono
   opcional + botón ✕.
2. **Editor de secciones WYSIWYG** (página Apariencia): las bolsas del personaje son chips
   `(◙ Mochila)` dentro de cajas-sección; el usuario las **arrastra entre cajas** para
   reorganizar las secciones del grid (fallback: clic abre Menu "Mover a ▸").
3. **Selector de acento** (página Tema): chips fijos `(●Emerald)(●Blue)…(＋Custom)` — aquí
   alcanza con el rol "toggle chip" (seleccionable, exclusivo).

## Solución propuesta

- `Craft.Badge:Create(parent, config)` con:
  - `text`, `icon?` (atlas lucide o texture), `variant` (`default|secondary|outline|destructive`
    como shadcn), `size`.
  - `removable?` → dibuja ✕; `onRemove(self)`.
  - `selectable?` + `selected` (signal two-way ADR-0013) para el rol toggle-chip.
- **Drag entre contenedores** (la parte nueva de verdad): `draggable?` +
  `onDrop(chip, targetZone)`; necesita un registro de drop-zones
  (`Craft.Badge.RegisterDropZone(frame, id)` o similar). Si se prefiere separar: Badge
  estático en este FR y el drag como FR aparte — Coffer puede vivir con el fallback de Menu.

## Caso de uso (Coffer)

Plan M8 rediseñado (`SortedBags/docs/plan-m8-settings.md`, secciones "Apariencia > Secciones"
y "Categorías"): default 2 secciones (Bolsas/Reagentes), mover `(◙ Reagentes)` a su propia
caja por drag; reglas de categoría se agregan por Command y se muestran como chips con ✕.

## Workaround actual (Coffer)

Chips ≈ `Button` size sm con icono (visual aceptable, sin ✕ integrado ni drag); mover
bolsas entre secciones = clic → `Menu` "Mover a ▸". Funcional pero pierde el WYSIWYG directo.

## Impacto

Componente nuevo, aditivo. El registro de drop-zones es la única pieza con superficie de
diseño nueva (¿generalizable a DragList?).
