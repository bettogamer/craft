# FR-027 — Combobox/Command: selector con búsqueda tipeada

**Reportado por:** Coffer (consumer addon — reemplazo de bolsas para WoW 12.0.7)
**Componente:** nuevo — `Craft/components/Combobox.lua` (shadcn: Combobox = Popover + Command)
**Tipo:** Feature Request
**Prioridad:** Media — Tema (fuentes LSM) y Categorías ("añadir regla") del M8 de Coffer; hay fallback
**Estado:** ✅ Implementado (2026-07-13, dev — pendiente de release): `Craft/components/Combobox.lua`
sobre `Craft.Popover` (FR-028), spec `docs/components/combobox.md`, 22 tests. Cubre options
planas/agrupadas + `keywords`, filtro en vivo, teclado ↑/↓/Enter/Esc, `value` two-way.
Notas: el icono `chevrons-up-down` del trigger shadcn NO está en el atlas → chevron-down/up
como Select (candidato a FR de iconos futuro); verificar in-game que `OnKeyDown` del EditBox
recibe UP/DOWN en 12.0.x.

---

## Problema

`Craft.Select` es un dropdown de lista corta y fija: no escala a listas **largas o
variables**, y no permite **buscar tipeando**. Coffer tiene dos casos donde eso es la
diferencia entre 1 segundo y un infierno de scroll:

1. **Selector de fuentes con LSM** (página Tema): `Theme.registerFont()` ya permite registrar
   fuentes en runtime; al integrar LibSharedMedia la lista pasa de 2 (Inter/Geist) a decenas.
2. **"Añadir regla" del editor de categorías**: el atributo Tipo son ~30 clases × subclases
   de ítem. Escribir "poc" → `Tipo ▸ Consumible ▸ Pociones`. Los demás atributos (Calidad,
   Binding, Expansión, Marker) son listas cortas dentro del mismo picker.

## Solución propuesta

- `Craft.Combobox:Create(parent, config)`:
  - `options` = lista plana o agrupada (`{ group = "Tipo", items = {...} }`) — los grupos
    cubren el caso "añadir regla" sin necesitar un Command genérico completo.
  - Trigger tipo Select; al abrir: `Input` de filtro arriba + lista scrolleable filtrada en
    vivo (match case-insensitive en label; opcional `keywords` por opción).
  - `value` signal two-way (ADR-0013), `onSelect(value)`, `placeholder`, `size`.
  - Teclado: ↑/↓ + Enter, Esc cierra (paridad Menu).
- Si FR-028 (Popover) se implementa, el panel flotante del Combobox debería construirse
  sobre él (misma pieza de anclaje/z-order/cierre-al-click-fuera que ya resuelve Menu).

## Caso de uso (Coffer)

Plan M8 rediseñado (`SortedBags/docs/plan-m8-settings.md`, páginas "Tema > Tipografía" y
"Categorías > ＋ Añadir regla").

## Workaround actual (Coffer)

Tema: `Select` simple mientras la lista sea corta (sin LSM, solo Inter/Geist). Categorías:
`Menu` anidado por atributo (navegable pero sin búsqueda) — utilizable, peor UX.

## Impacto

Componente nuevo, aditivo. Reusa piezas existentes (Input, Scroll, patrón de cierre de Menu).
