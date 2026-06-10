# RFC-009 — Componentes de formulario P2 (nice-to-have)

**Reportado por:** Sentry (consumer addon)
**Componentes:** nuevos / mejoras menores
**Tipo:** RFC (prioridad media-baja; hay workaround para todos)
**Estado:** 🔵 Propuesto

---

## Objetivo

Agrupar cuatro componentes que mejorarían los formularios de configuración de Sentry pero **no bloquean**
M7 (cada uno tiene workaround). Se listan juntos para priorizar/diseñar en bloque.

## Componentes

### 1. NumberInput / Stepper
- **Uso:** campos numéricos (x/y, tamaño, duración, recuento).
- **API:** `Craft.NumberInput:Create(p, { value, min, max, step, onChange })` con flechas ▲▼ opcionales.
- **Workaround:** `Input` + validación `tonumber`, o `Slider` cuando hay rango.

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
