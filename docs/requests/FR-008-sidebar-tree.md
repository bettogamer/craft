# FR-008 — Sidebar: items anidados colapsables (árbol)

**Reportado por:** Sentry (consumer addon)
**Componente:** `Craft/components/Sidebar.lua`
**Tipo:** Feature Request
**Prioridad:** Alta — la navegación de Sentry es un árbol
**Estado:** 🔵 Propuesto

---

## Problema

`Sidebar` soporta **grupos planos** (group label + items) pero no **árbol**: no hay items anidados ni
colapsar/expandir. Sentry navega por Packs (carpetas) que contienen Auras y una subcarpeta Paneles.

## Caso de uso (Sentry)

```
▼ Manaforge Omega        (pack, colapsable)
   ⭐ Shadow Crash         (aura, hoja)
   ⭐ Interrumpir
   🗂 Paneles              (subgrupo colapsable)
      ▭ Barras boss
      ▭ Avisos
▶ Mythic+ general         (pack colapsado)
```

## Solución propuesta

### API
```lua
Craft.Sidebar:Create(parent, {
  items = {
    { id="pack1", label="Manaforge Omega", icon="folder", collapsible=true, defaultOpen=true,
      children = {
        { id="aura1", label="Shadow Crash", icon="star" },
        { id="panels", label="Paneles", icon="layers", collapsible=true, children = { ... } },
      } },
  },
  onSelect = function(id) end,
})
```
### Comportamiento
- `collapsible` + chevron (usa `chevron-down`/`chevron-right`); click en la fila-grupo colapsa/expande.
- `children` anidados con indent por nivel. Selección por `id` (`onSelect`).
- Idealmente `:SetItems(tree)` para refrescar y `:Select(id)`.

## Workaround actual (Sentry)

Construir filas de árbol a medida dentro del `Sidebar` (chevron + indent + click). Viable pero reimplementa
lo que el componente debería ofrecer.

## Impacto

Mejora del `Sidebar` (compatibilidad hacia atrás manteniendo `groups` planos). Base de la navegación de M7.1.
