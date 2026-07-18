# FR-037 — Input/Textarea: borde destructive en foco con error

**Reportado por:** Auditoría de fidelidad shadcn (interno, 2026-07-18)
**Componente:** `Craft/components/Input.lua` + `Craft/components/Textarea.lua` (shadcn: Input, Textarea)
**Tipo:** Bug fix (fidelidad)
**Prioridad:** Media
**Estado:** ✅ Implementado (pendiente verificación in-game)

---

## Problema

Con `error=true`, al ganar foco el borde se anima a `t.ring` (gris) y deja de mostrar `t.destructive`
(rojo), perdiendo la señal de error justo cuando el usuario interactúa. El endpoint de foco está
fijo e ignora el estado `error`: `Textarea.lua:235` (`self._borderFocus = t.ring`) y
`Input.lua:307-317` (`_borderFocus` = ring siempre; `_borderIdle` = destructive solo en idle).

shadcn/Lyra mantiene el borde destructive en un campo inválido aunque esté enfocado: en
`.cn-textarea`/`.cn-input` la clase `aria-invalid:border-destructive` aparece DESPUÉS de
`focus-visible:border-ring` (gana el destructive), más `aria-invalid:ring-destructive/20`
(el inválido siempre lleva anillo destructive).

**Escenario:** `Create(parent, { error=true })` → clic en el campo → el borde rojo se vuelve gris
mientras se escribe.

**Nota:** es un defecto COMPARTIDO por Input y Textarea (mismo patrón), no una regresión de uno solo.

## Solución propuesta

Cachear el endpoint de foco condicionado al estado de error:

```lua
self._borderFocus = error and t.destructive or t.ring
```

Re-evaluar si `SetError`/estado de error cambia en runtime. Aplicar en ambos componentes.

## Caso de uso

Campos de formulario con validación (Coffer, cualquier form con feedback de error).

## Impacto

Fix de fidelidad; riesgo bajo; aditivo al comportamiento visual existente.
