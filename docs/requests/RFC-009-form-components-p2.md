# RFC-009 — Componentes de formulario P2 (nice-to-have)

**Reportado por:** Sentry (consumer addon)
**Componentes:** nuevos / mejoras menores
**Tipo:** RFC (prioridad media-baja; hay workaround para todos)
**Estado:** 🟡 En progreso (2026-06-11) — revisado contra shadcn; implementando por orden

## Revisión shadcn (2026-06-11)

Verificado en `style-lyra.css`: **2 de 4 existen en shadcn** (RadioGroup, Accordion) →
se construyen fieles; **2 son Craft-originales** (NumberInput, DragList).

| Componente | shadcn | Esfuerzo | Orden |
|---|---|---|---|
| NumberInput / Stepper | ❌ no existe (Craft-original) | S | 1 |
| RadioGroup | ✅ `.cn-radio-group` (`grid gap-2`) + `.cn-radio-group-item` (`border-input`, `data-checked:bg-primary`, **`rounded-none`** = radio cuadrado) | S-M | 2 |
| Accordion | ✅ `.cn-accordion-item` (`not-last:border-b`), `-trigger`, `-content` | M (reutiliza el colapso del árbol de Sidebar) | 3 |
| SegmentedControl | ✅ **es el `ToggleGroup` de shadcn** (`.cn-toggle-group`, `rounded-none`) | S-M | 4 |
| DragList | ❌ no existe (Craft-original) | L | 5 (diferir) |

---

## Objetivo

Agrupar cuatro componentes que mejorarían los formularios de configuración de Sentry pero **no bloquean**
M7 (cada uno tiene workaround). Se listan juntos para priorizar/diseñar en bloque.

## Componentes

### 1. NumberInput / Stepper — ✅ Implementado (2026-06-11)
- **Uso:** campos numéricos (x/y, tamaño, duración, recuento).
- **API:** `Craft.NumberInput:Create(p, { value, min, max, step, width, disabled, onChange })`;
  flechas ▲▼ + rueda del mouse. `SetValue`/`GetValue`/`SetRange`/`SetEnabled`.
- **Estado:** Craft-original (shadcn no tiene spinner). Ver `docs/components/numberinput.md`.
- ~~Workaround: `Input` + `tonumber`, o `Slider` cuando hay rango.~~

### 2. RadioGroup / SegmentedControl
- **Uso:** elegir tipo de display (Barra/Icono/Texto), modo de trigger.
- **API:** `Craft.RadioGroup:Create(p, { options = {{value,label}}, value, onChange })`.
- **Workaround:** `Select` (dropdown).

### 3. Accordion / CollapsibleSection
- **Uso:** bloque "Avanzado (multi-trigger)", secciones largas de formulario.
- **API:** `Craft.Section:Create(p, { title, collapsed=true })` con `:SetContent(frame)` / `:Toggle()`.
- **Workaround:** `Separator` + mostrar/ocultar a mano.

### 4. List reorderable (DragList)
- **Uso:** listas de enrutado, condiciones y multi-triggers (reordenar por prioridad).
- **API:** `Craft.DragList:Create(p, { items, renderRow, onReorder })` con handle `grip-vertical`
  (ya existe en el atlas, parece anticipado).
- **Workaround:** filas + `grip-vertical` + botones ▲▼.

## Impacto

Todos additivos. Mejoran ergonomía/consistencia; se pueden adoptar incrementalmente sustituyendo los
workarounds en `Sentry/UI/` sin tocar la lógica de los editores.
